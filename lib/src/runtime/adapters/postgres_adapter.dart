/// PostgreSQL database adapter implementation.
///
/// This adapter uses the `postgres` package to connect to PostgreSQL databases.
/// It implements the SqlDriverAdapter interface to provide type-safe database
/// access for the Prisma client.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  pg.Connection _connection;
  final ConnectionInfo? _connectionInfo;
  final Future<pg.Connection> Function()? _connectionFactory;

  PostgresAdapter(
    this._connection, {
    ConnectionInfo? connectionInfo,
    Future<pg.Connection> Function()? connectionFactory,
  })  : _connectionInfo = connectionInfo,
        _connectionFactory = connectionFactory;

  /// Check if connection is alive, reconnect if factory provided.
  Future<void> _ensureConnected() async {
    if (_connectionFactory == null) return;
    try {
      await _connection.execute('SELECT 1').timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {
      // Connection dead — attempt reconnect
      try {
        await _connection.close();
      } catch (_) {
        // Already closed, ignore
      }
      _connection = await _connectionFactory!();
    }
  }

  @override
  String get provider => 'postgresql';

  @override
  String get adapterName => 'prisma_flutter_connector:postgres';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    try {
      await _ensureConnected();
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
      await _ensureConnected();
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
      final rowData =
          columnNames.map((name) => _convertValue(rowMap[name])).toList();
      rows.add(rowData);
    }

    return SqlResultSet(
      columnNames: columnNames,
      columnTypes: columnTypes,
      rows: rows,
    );
  }

  /// Convert PostgreSQL values to Dart types.
  /// Handles special types like UndecodedBytes (enums, enum arrays, and
  /// other custom types the driver has no codec for).
  dynamic _convertValue(dynamic value) {
    if (value == null) return null;

    // Handle UndecodedBytes (PostgreSQL enums and custom types)
    if (value is pg.UndecodedBytes) {
      final bytes = value.bytes;
      if (value.isBinary) {
        // Custom ARRAY types (e.g. enum[]) arrive in the binary array wire
        // format; scalar enums arrive as plain label bytes.
        final parsed = parsePgBinaryArray(bytes);
        if (parsed != null) return parsed;
        return utf8.decode(bytes, allowMalformed: true);
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      // Text-format array literal for an unknown element type: {A,B}
      if (text.length >= 2 && text.startsWith('{') && text.endsWith('}')) {
        return parsePgTextArray(text);
      }
      return text;
    }

    return value;
  }

  /// Parse the PostgreSQL binary ARRAY wire format (one-dimensional) into a
  /// List of UTF-8 element strings (enum labels, text, …).
  ///
  /// Layout: int32 ndim, int32 hasNull, int32 elemOid, then per dimension
  /// {int32 size, int32 lowerBound}, then per element {int32 byteLength
  /// (-1 = NULL), payload bytes}. Returns null when the bytes do not parse
  /// cleanly as such an array (callers fall back to plain UTF-8 decode).
  static List<String?>? parsePgBinaryArray(List<int> bytes) {
    if (bytes.length < 12) return null;
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final ndim = data.getInt32(0);
    final hasNull = data.getInt32(4);
    if (hasNull != 0 && hasNull != 1) return null;
    if (ndim == 0) return bytes.length == 12 ? <String?>[] : null;
    if (ndim != 1 || bytes.length < 20) return null;

    final size = data.getInt32(12);
    if (size < 0 || size > 100000) return null;

    final elements = <String?>[];
    var offset = 20;
    for (var i = 0; i < size; i++) {
      if (offset + 4 > bytes.length) return null;
      final len = data.getInt32(offset);
      offset += 4;
      if (len == -1) {
        elements.add(null);
        continue;
      }
      if (len < 0 || offset + len > bytes.length) return null;
      elements.add(utf8.decode(bytes.sublist(offset, offset + len),
          allowMalformed: true));
      offset += len;
    }
    return offset == bytes.length ? elements : null;
  }

  /// Parse a PostgreSQL text-format array literal ({A,B,"c d",NULL}) into a
  /// List of element strings.
  static List<String?> parsePgTextArray(String text) {
    final inner = text.substring(1, text.length - 1);
    if (inner.isEmpty) return <String?>[];

    final elements = <String?>[];
    final current = StringBuffer();
    var inQuotes = false;
    var wasQuoted = false;
    for (var i = 0; i < inner.length; i++) {
      final ch = inner[i];
      if (inQuotes) {
        if (ch == r'\') {
          i++;
          if (i < inner.length) current.write(inner[i]);
        } else if (ch == '"') {
          inQuotes = false;
        } else {
          current.write(ch);
        }
      } else if (ch == '"') {
        inQuotes = true;
        wasQuoted = true;
      } else if (ch == ',') {
        final raw = current.toString();
        elements.add(!wasQuoted && raw == 'NULL' ? null : raw);
        current.clear();
        wasQuoted = false;
      } else {
        current.write(ch);
      }
    }
    final raw = current.toString();
    elements.add(!wasQuoted && raw == 'NULL' ? null : raw);
    return elements;
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
