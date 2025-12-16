/// PostgreSQL database adapter implementation.
///
/// This adapter uses the `postgres` package to connect to PostgreSQL databases.
/// It implements the SqlDriverAdapter interface to provide type-safe database
/// access for the Prisma client.
library;

import 'dart:async';
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// PostgreSQL database adapter.
///
/// Example usage:
/// ```dart
/// final connection = await pg.Connection.open(
///   pg.Endpoint(
///     host: 'localhost',
///     database: 'mydb',
///     username: 'user',
///     password: 'password',
///   ),
/// );
///
/// final adapter = PostgresAdapter(connection);
/// final prisma = PrismaClient(adapter: adapter);
/// ```
class PostgresAdapter implements SqlDriverAdapter {
  final pg.Connection _connection;
  final ConnectionInfo? _connectionInfo;

  PostgresAdapter(
    this._connection, {
    ConnectionInfo? connectionInfo,
  }) : _connectionInfo = connectionInfo;

  @override
  String get provider => 'postgresql';

  @override
  String get adapterName => 'prisma_flutter_connector:postgres';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    try {
      // Convert args to PostgreSQL-compatible format
      final convertedArgs = _convertArgs(query.args, query.argTypes);

      // Execute query - don't use pg.Sql.indexed since we already have placeholders
      final result = await _connection.execute(
        query.sql,
        parameters: convertedArgs.isEmpty ? null : convertedArgs,
      );

      // Convert result to SqlResultSet
      return _convertResult(result);
    } catch (e) {
      throw AdapterError(
        'Failed to execute query: ${e.toString()}',
        code: _extractErrorCode(e),
        originalError: e,
      );
    }
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    try {
      final convertedArgs = _convertArgs(query.args, query.argTypes);

      final result = await _connection.execute(
        query.sql,
        parameters: convertedArgs.isEmpty ? null : convertedArgs,
      );

      return result.affectedRows;
    } catch (e) {
      throw AdapterError(
        'Failed to execute command: ${e.toString()}',
        code: _extractErrorCode(e),
        originalError: e,
      );
    }
  }

  @override
  Future<void> executeScript(String script) async {
    try {
      // Split script into individual statements and execute
      final statements = script.split(';').where((s) => s.trim().isNotEmpty);

      for (final statement in statements) {
        await _connection.execute(statement.trim());
      }
    } catch (e) {
      throw AdapterError(
        'Failed to execute script: ${e.toString()}',
        code: _extractErrorCode(e),
        originalError: e,
      );
    }
  }

  @override
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]) async {
    return PostgresTransaction._start(_connection, isolationLevel);
  }

  @override
  ConnectionInfo? getConnectionInfo() {
    return _connectionInfo ??
        const ConnectionInfo(
          maxBindValues: 32767, // PostgreSQL limit
          supportsRelationJoins: true,
        );
  }

  @override
  Future<void> dispose() async {
    await _connection.close();
  }

  /// Convert Dart values to PostgreSQL-compatible format.
  List<dynamic> _convertArgs(List<dynamic> args, List<ArgType> argTypes) {
    final converted = <dynamic>[];

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final type = i < argTypes.length ? argTypes[i] : ArgType.unknown;

      if (arg == null) {
        converted.add(null);
        continue;
      }

      switch (type) {
        case ArgType.dateTime:
          if (arg is DateTime) {
            converted.add(arg);
          } else if (arg is String) {
            converted.add(DateTime.parse(arg));
          } else {
            converted.add(arg);
          }
          break;

        case ArgType.json:
          // PostgreSQL expects JSON as string
          if (arg is String) {
            converted.add(arg);
          } else {
            converted.add(arg.toString());
          }
          break;

        case ArgType.bytes:
          // Convert to PostgreSQL bytea
          if (arg is List<int>) {
            converted.add(arg);
          } else {
            converted.add(arg);
          }
          break;

        case ArgType.uuid:
          // UUIDs are passed as strings
          converted.add(arg);
          break;

        case ArgType.bigInt:
          if (arg is BigInt) {
            converted.add(arg.toInt());
          } else if (arg is String) {
            converted.add(BigInt.parse(arg).toInt());
          } else {
            converted.add(arg);
          }
          break;

        default:
          converted.add(arg);
      }
    }

    return converted;
  }

  /// Convert PostgreSQL result to SqlResultSet.
  SqlResultSet _convertResult(pg.Result result) {
    if (result.isEmpty) {
      return const SqlResultSet(
        columnNames: [],
        columnTypes: [],
        rows: [],
      );
    }

    // Get column names from the first row's map keys
    final firstRowMap = result.first.toColumnMap();
    final columnNames = firstRowMap.keys.toList();

    // Infer column types from values
    final columnTypes = columnNames.map((name) {
      final value = _convertValue(firstRowMap[name]);
      return _inferColumnType(value);
    }).toList();

    // Convert all rows to list format
    final rows = <List<dynamic>>[];
    for (final row in result) {
      final rowMap = row.toColumnMap();
      final rowData = columnNames
          .map((name) => _convertValue(rowMap[name]))
          .toList();
      rows.add(rowData);
    }

    return SqlResultSet(
      columnNames: columnNames,
      columnTypes: columnTypes,
      rows: rows,
    );
  }

  /// Convert PostgreSQL values to Dart types.
  /// Handles special types like UndecodedBytes (enums, custom types).
  dynamic _convertValue(dynamic value) {
    if (value == null) return null;

    // Handle UndecodedBytes (PostgreSQL enums and custom types)
    if (value is pg.UndecodedBytes) {
      // UndecodedBytes contains raw bytes - decode as UTF-8 string
      return String.fromCharCodes(value.bytes);
    }

    return value;
  }

  /// Infer column type from value.
  ColumnType _inferColumnType(dynamic value) {
    if (value == null) return ColumnType.unknown;
    if (value is int) return ColumnType.int64;
    if (value is double) return ColumnType.double;
    if (value is bool) return ColumnType.boolean;
    if (value is String) return ColumnType.string;
    if (value is DateTime) return ColumnType.dateTime;
    if (value is List<int>) return ColumnType.bytes;
    if (value is Map) return ColumnType.json;
    if (value is List) return ColumnType.array;
    return ColumnType.unknown;
  }

  /// Extract error code from PostgreSQL exception.
  String? _extractErrorCode(Object error) {
    if (error is pg.PgException) {
      // postgres package 3.x uses 'severity' enum
      return error.severity.toString();
    }
    return null;
  }
}

/// PostgreSQL transaction implementation.
class PostgresTransaction implements Transaction {
  final pg.Connection _connection;
  bool _isActive = true;
  bool _isCommitted = false;
  bool _isRolledBack = false;

  PostgresTransaction._(this._connection);

  static Future<PostgresTransaction> _start(
    pg.Connection connection,
    IsolationLevel? isolationLevel,
  ) async {
    // Start transaction
    await connection.execute('BEGIN');

    // Set isolation level if specified
    if (isolationLevel != null) {
      await connection.execute(
        'SET TRANSACTION ISOLATION LEVEL ${isolationLevel.sql}',
      );
    }

    return PostgresTransaction._(connection);
  }

  @override
  bool get isActive => _isActive;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    _checkActive();

    try {
      final adapter = PostgresAdapter(_connection);
      return await adapter.queryRaw(query);
    } catch (e) {
      // Transaction is still active, but query failed
      rethrow;
    }
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    _checkActive();

    try {
      final adapter = PostgresAdapter(_connection);
      return await adapter.executeRaw(query);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> commit() async {
    _checkActive();

    try {
      await _connection.execute('COMMIT');
      _isCommitted = true;
      _isActive = false;
    } catch (e) {
      throw AdapterError(
        'Failed to commit transaction: ${e.toString()}',
        originalError: e,
      );
    }
  }

  @override
  Future<void> rollback() async {
    _checkActive();

    try {
      await _connection.execute('ROLLBACK');
      _isRolledBack = true;
      _isActive = false;
    } catch (e) {
      throw AdapterError(
        'Failed to rollback transaction: ${e.toString()}',
        originalError: e,
      );
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
