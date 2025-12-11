/// SQLite database adapter implementation.
///
/// This adapter uses the `sqflite` package for mobile SQLite databases.
/// Perfect for offline-first Flutter apps with local data storage.
library;

import 'dart:async';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// SQLite database adapter for mobile apps.
///
/// Example usage:
/// ```dart
/// final database = await sqflite.openDatabase(
///   'app.db',
///   version: 1,
///   onCreate: (db, version) async {
///     // Run migrations
///     await db.execute('CREATE TABLE users (...)');
///   },
/// );
///
/// final adapter = SQLiteAdapter(database);
/// final prisma = PrismaClient(adapter: adapter);
/// ```
class SQLiteAdapter implements SqlDriverAdapter {
  final sqflite.Database _database;
  final ConnectionInfo? _connectionInfo;

  SQLiteAdapter(
    this._database, {
    ConnectionInfo? connectionInfo,
  }) : _connectionInfo = connectionInfo;

  @override
  String get provider => 'sqlite';

  @override
  String get adapterName => 'prisma_flutter_connector:sqlite';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    try {
      // Convert PostgreSQL-style placeholders ($1, $2) to SQLite-style (?, ?)
      final sqliteQuery = _convertPlaceholders(query.sql);

      // Execute query
      final List<Map<String, dynamic>> result = await _database.rawQuery(
        sqliteQuery,
        query.args,
      );

      if (result.isEmpty) {
        return const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        );
      }

      // Extract column names and infer types
      final columnNames = result.first.keys.toList();
      final columnTypes = _inferColumnTypes(result.first, query.argTypes);

      // Convert to row format
      final rows = result.map((row) {
        return columnNames.map((col) => _convertValue(row[col])).toList();
      }).toList();

      return SqlResultSet(
        columnNames: columnNames,
        columnTypes: columnTypes,
        rows: rows,
      );
    } catch (e) {
      throw AdapterError(
        'Failed to execute query: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    try {
      final sqliteQuery = _convertPlaceholders(query.sql);

      final result = await _database.rawInsert(
        sqliteQuery,
        query.args,
      );

      return result;
    } catch (e) {
      throw AdapterError(
        'Failed to execute command: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> executeScript(String script) async {
    try {
      // Split script into statements
      final statements = script.split(';').where((s) => s.trim().isNotEmpty);

      await _database.transaction((txn) async {
        for (final statement in statements) {
          await txn.execute(statement.trim());
        }
      });
    } catch (e) {
      throw AdapterError(
        'Failed to execute script: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]) async {
    // SQLite doesn't support different isolation levels in the same way
    // It uses a single serializable mode
    return SQLiteTransaction._start(_database);
  }

  @override
  ConnectionInfo? getConnectionInfo() {
    return _connectionInfo ??
        const ConnectionInfo(
          maxBindValues: 999, // SQLite default limit
          supportsRelationJoins: true,
        );
  }

  @override
  Future<void> dispose() async {
    await _database.close();
  }

  /// Convert PostgreSQL-style placeholders ($1, $2) to SQLite-style (?, ?).
  String _convertPlaceholders(String sql) {
    // Replace $1, $2, etc. with ?
    return sql.replaceAllMapped(
      RegExp(r'\$\d+'),
      (match) => '?',
    );
  }

  /// Infer column types from first row data.
  List<ColumnType> _inferColumnTypes(
    Map<String, dynamic> firstRow,
    List<ArgType> argTypes,
  ) {
    return firstRow.values.map((value) {
      if (value == null) return ColumnType.unknown;
      if (value is int) return ColumnType.int64;
      if (value is double) return ColumnType.double;
      if (value is String) {
        // Try to detect DateTime strings
        if (_isDateTimeString(value)) return ColumnType.dateTime;
        return ColumnType.string;
      }
      if (value is List<int>) return ColumnType.bytes;
      return ColumnType.unknown;
    }).toList();
  }

  /// Check if a string looks like a DateTime.
  bool _isDateTimeString(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Convert SQLite values to Prisma types.
  dynamic _convertValue(dynamic value) {
    if (value == null) return null;

    // SQLite stores everything as int, real, text, or blob
    // We need to convert appropriately
    if (value is int) {
      return value;
    } else if (value is double) {
      return value;
    } else if (value is String) {
      // Keep strings as-is
      return value;
    } else if (value is List<int>) {
      // Blob data
      return value;
    }

    return value;
  }
}

/// SQLite transaction implementation.
class SQLiteTransaction implements Transaction {
  final sqflite.Database _database;
  sqflite.Transaction? _transaction;
  bool _isActive = true;
  bool _isCommitted = false;
  bool _isRolledBack = false;

  SQLiteTransaction._(this._database);

  static Future<SQLiteTransaction> _start(sqflite.Database database) async {
    final txn = SQLiteTransaction._(database);

    // SQLite transactions are managed through the transaction() method
    // We'll store the transaction context when it's used
    return txn;
  }

  @override
  bool get isActive => _isActive;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    _checkActive();

    if (_transaction == null) {
      // Start implicit transaction
      late SqlResultSet result;
      await _database.transaction((txn) async {
        _transaction = txn;
        final adapter = SQLiteAdapter(_database);
        result = await adapter.queryRaw(query);
      });
      return result;
    } else {
      final adapter = SQLiteAdapter(_database);
      return adapter.queryRaw(query);
    }
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    _checkActive();

    if (_transaction == null) {
      late int result;
      await _database.transaction((txn) async {
        _transaction = txn;
        final adapter = SQLiteAdapter(_database);
        result = await adapter.executeRaw(query);
      });
      return result;
    } else {
      final adapter = SQLiteAdapter(_database);
      return adapter.executeRaw(query);
    }
  }

  @override
  Future<void> commit() async {
    _checkActive();

    // SQLite transactions are auto-committed when the transaction block ends
    _isCommitted = true;
    _isActive = false;
  }

  @override
  Future<void> rollback() async {
    _checkActive();

    // SQLite transactions rollback if an exception is thrown
    // We'll mark it as rolled back
    _isRolledBack = true;
    _isActive = false;

    throw const AdapterError('Transaction rolled back');
  }

  void _checkActive() {
    if (!_isActive) {
      if (_isCommitted) {
        throw const AdapterError('Transaction already committed');
      } else if (_isRolledBack) {
        throw const AdapterError('Transaction already rolled back');
      } else {
        throw const AdapterError('Transaction is no longer active');
      }
    }
  }
}
