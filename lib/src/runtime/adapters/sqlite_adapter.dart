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
///
/// Note: sqflite uses a callback-based transaction model where transactions
/// auto-commit when the callback completes normally and auto-rollback on
/// exceptions. This implementation queues operations and executes them all
/// within a single transaction callback on commit().
class SQLiteTransaction implements Transaction {
  final sqflite.Database _database;
  final List<_QueuedOperation> _pendingOperations = [];
  bool _isActive = true;
  bool _isCommitted = false;
  bool _isRolledBack = false;

  SQLiteTransaction._(this._database);

  static Future<SQLiteTransaction> _start(sqflite.Database database) async {
    return SQLiteTransaction._(database);
  }

  @override
  bool get isActive => _isActive;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    _checkActive();

    // Queue the query operation - it will be executed on commit
    final completer = Completer<SqlResultSet>();
    _pendingOperations.add(_QueuedQuery(query, completer));
    return completer.future;
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    _checkActive();

    // Queue the execute operation - it will be executed on commit
    final completer = Completer<int>();
    _pendingOperations.add(_QueuedExecute(query, completer));
    return completer.future;
  }

  @override
  Future<void> commit() async {
    _checkActive();

    try {
      await _database.transaction((txn) async {
        for (final operation in _pendingOperations) {
          await operation.execute(txn);
        }
      });
      _isCommitted = true;
    } catch (e) {
      // If transaction fails, fail all pending operations
      for (final operation in _pendingOperations) {
        if (!operation.isCompleted) {
          operation.fail(AdapterError(
            'Transaction failed: ${e.toString()}',
            originalError: e,
          ));
        }
      }
      rethrow;
    } finally {
      _isActive = false;
    }
  }

  @override
  Future<void> rollback() async {
    _checkActive();

    _isRolledBack = true;
    _isActive = false;

    // Fail all pending operations
    const error = AdapterError('Transaction rolled back');
    for (final operation in _pendingOperations) {
      if (!operation.isCompleted) {
        operation.fail(error);
      }
    }
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

/// Base class for queued transaction operations.
abstract class _QueuedOperation {
  bool get isCompleted;
  Future<void> execute(sqflite.Transaction txn);
  void fail(AdapterError error);
}

/// A queued query operation.
class _QueuedQuery extends _QueuedOperation {
  final SqlQuery query;
  final Completer<SqlResultSet> completer;

  _QueuedQuery(this.query, this.completer);

  @override
  bool get isCompleted => completer.isCompleted;

  @override
  Future<void> execute(sqflite.Transaction txn) async {
    try {
      final sqliteQuery = _convertPlaceholders(query.sql);
      final List<Map<String, dynamic>> result = await txn.rawQuery(
        sqliteQuery,
        query.args,
      );

      if (result.isEmpty) {
        completer.complete(const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        ));
        return;
      }

      final columnNames = result.first.keys.toList();
      final columnTypes = _inferColumnTypes(result.first);
      final rows = result.map((row) {
        return columnNames.map((col) => row[col]).toList();
      }).toList();

      completer.complete(SqlResultSet(
        columnNames: columnNames,
        columnTypes: columnTypes,
        rows: rows,
      ));
    } catch (e) {
      completer.completeError(AdapterError(
        'Failed to execute query: ${e.toString()}',
        originalError: e,
      ));
      rethrow;
    }
  }

  @override
  void fail(AdapterError error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }

  static String _convertPlaceholders(String sql) {
    return sql.replaceAllMapped(RegExp(r'\$\d+'), (match) => '?');
  }

  static List<ColumnType> _inferColumnTypes(Map<String, dynamic> firstRow) {
    return firstRow.values.map((value) {
      if (value == null) return ColumnType.unknown;
      if (value is int) return ColumnType.int64;
      if (value is double) return ColumnType.double;
      if (value is String) return ColumnType.string;
      if (value is List<int>) return ColumnType.bytes;
      return ColumnType.unknown;
    }).toList();
  }
}

/// A queued execute operation.
class _QueuedExecute extends _QueuedOperation {
  final SqlQuery query;
  final Completer<int> completer;

  _QueuedExecute(this.query, this.completer);

  @override
  bool get isCompleted => completer.isCompleted;

  @override
  Future<void> execute(sqflite.Transaction txn) async {
    try {
      final sqliteQuery = _QueuedQuery._convertPlaceholders(query.sql);
      final result = await txn.rawInsert(sqliteQuery, query.args);
      completer.complete(result);
    } catch (e) {
      completer.completeError(AdapterError(
        'Failed to execute command: ${e.toString()}',
        originalError: e,
      ));
      rethrow;
    }
  }

  @override
  void fail(AdapterError error) {
    if (!completer.isCompleted) {
      completer.completeError(error);
    }
  }
}
