/// MySQL database adapter implementation.
///
/// This adapter uses the `mysql_client` package to connect to MySQL databases.
/// It implements the SqlDriverAdapter interface to provide type-safe database
/// access for the Prisma client.
library;

import 'dart:async';
import 'dart:convert';
import 'package:mysql_client/mysql_client.dart' as mysql;
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// MySQL database adapter.
///
/// Example usage:
/// ```dart
/// final connection = await MySQLConnection.createConnection(
///   host: 'localhost',
///   port: 3306,
///   userName: 'user',
///   password: 'password',
///   databaseName: 'mydb',
/// );
/// await connection.connect();
///
/// final adapter = MySQLAdapter(connection);
/// final prisma = PrismaClient(adapter: adapter);
/// ```
class MySQLAdapter implements SqlDriverAdapter {
  final mysql.MySQLConnection _connection;
  final ConnectionInfo? _connectionInfo;

  MySQLAdapter(
    this._connection, {
    ConnectionInfo? connectionInfo,
  }) : _connectionInfo = connectionInfo;

  /// Factory constructor to create adapter from connection parameters.
  static Future<MySQLAdapter> connect({
    required String host,
    required int port,
    required String userName,
    required String password,
    String? databaseName,
    bool secure = false,
    ConnectionInfo? connectionInfo,
  }) async {
    final connection = await mysql.MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: userName,
      password: password,
      databaseName: databaseName,
      secure: secure,
    );
    await connection.connect();
    return MySQLAdapter(connection, connectionInfo: connectionInfo);
  }

  /// Factory constructor to create adapter from a connection string.
  ///
  /// Connection string format: mysql://user:password@host:port/database
  static Future<MySQLAdapter> fromConnectionString(
    String connectionString, {
    ConnectionInfo? connectionInfo,
  }) async {
    final uri = Uri.parse(connectionString);
    final userInfo = uri.userInfo.split(':');

    return connect(
      host: uri.host,
      port: uri.port != 0 ? uri.port : 3306,
      userName: userInfo.isNotEmpty ? userInfo[0] : '',
      password: userInfo.length > 1 ? userInfo[1] : '',
      databaseName: uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null,
      secure: uri.queryParameters['ssl'] == 'true',
      connectionInfo: connectionInfo,
    );
  }

  @override
  String get provider => 'mysql';

  @override
  String get adapterName => 'prisma_flutter_connector:mysql';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    try {
      // Convert PostgreSQL-style placeholders ($1, $2) to named params (:p0, :p1)
      final mysqlQuery = _convertPlaceholders(query.sql);

      // Convert args to MySQL-compatible format as a Map
      final convertedArgs = _convertArgsToMap(query.args, query.argTypes);

      // Execute query
      final mysql.IResultSet result;
      if (convertedArgs.isEmpty) {
        result = await _connection.execute(mysqlQuery);
      } else {
        result = await _connection.execute(mysqlQuery, convertedArgs);
      }

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
      final mysqlQuery = _convertPlaceholders(query.sql);
      final convertedArgs = _convertArgsToMap(query.args, query.argTypes);

      final mysql.IResultSet result;
      if (convertedArgs.isEmpty) {
        result = await _connection.execute(mysqlQuery);
      } else {
        result = await _connection.execute(mysqlQuery, convertedArgs);
      }

      return result.affectedRows.toInt();
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
      // Split script into individual statements
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
    return MySQLTransaction._start(_connection, isolationLevel);
  }

  @override
  ConnectionInfo? getConnectionInfo() {
    return _connectionInfo ??
        const ConnectionInfo(
          maxBindValues: 65535, // MySQL prepared statement limit
          supportsRelationJoins: true,
        );
  }

  @override
  Future<void> dispose() async {
    await _connection.close();
  }

  /// Convert PostgreSQL-style placeholders ($1, $2) or positional (?) to
  /// MySQL named parameters (:p0, :p1).
  String _convertPlaceholders(String sql) {
    var paramIndex = 0;

    // First convert $N style to :pN
    var result = sql.replaceAllMapped(
      RegExp(r'\$(\d+)'),
      (match) {
        final index = int.parse(match.group(1)!) - 1; // $1 -> :p0
        return ':p$index';
      },
    );

    // Then convert ? style to :pN
    result = result.replaceAllMapped(
      RegExp(r'\?'),
      (match) => ':p${paramIndex++}',
    );

    return result;
  }

  /// Convert Dart values to MySQL-compatible format as a Map.
  Map<String, dynamic> _convertArgsToMap(
      List<dynamic> args, List<ArgType> argTypes) {
    final converted = <String, dynamic>{};

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final type = i < argTypes.length ? argTypes[i] : ArgType.unknown;
      final paramName = 'p$i';

      if (arg == null) {
        converted[paramName] = null;
        continue;
      }

      switch (type) {
        case ArgType.dateTime:
          if (arg is DateTime) {
            // MySQL expects DATETIME format: 'YYYY-MM-DD HH:MM:SS'
            converted[paramName] = _formatDateTime(arg);
          } else if (arg is String) {
            converted[paramName] = arg;
          } else {
            converted[paramName] = arg;
          }
          break;

        case ArgType.json:
          // MySQL JSON columns accept strings
          if (arg is String) {
            converted[paramName] = arg;
          } else if (arg is Map || arg is List) {
            converted[paramName] = jsonEncode(arg);
          } else {
            converted[paramName] = arg.toString();
          }
          break;

        case ArgType.bytes:
          // BLOB/VARBINARY data
          converted[paramName] = arg;
          break;

        case ArgType.boolean:
          // MySQL stores booleans as TINYINT(1)
          if (arg is bool) {
            converted[paramName] = arg ? 1 : 0;
          } else {
            converted[paramName] = arg;
          }
          break;

        case ArgType.decimal:
          // Decimal values passed as strings for precision
          if (arg is double || arg is int) {
            converted[paramName] = arg.toString();
          } else {
            converted[paramName] = arg;
          }
          break;

        case ArgType.bigInt:
          if (arg is BigInt) {
            converted[paramName] = arg.toString();
          } else {
            converted[paramName] = arg;
          }
          break;

        default:
          converted[paramName] = arg;
      }
    }

    return converted;
  }

  /// Format DateTime for MySQL.
  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  /// Convert MySQL result to SqlResultSet.
  SqlResultSet _convertResult(mysql.IResultSet result) {
    final rows = <List<dynamic>>[];
    final columnNames = <String>[];
    var columnTypes = <ColumnType>[];

    // Get column names
    for (final col in result.cols) {
      columnNames.add(col.name);
    }

    // Convert rows and infer types from first row
    var firstRow = true;
    for (final row in result.rows) {
      final rowData = <dynamic>[];
      for (var i = 0; i < columnNames.length; i++) {
        final value = row.colAt(i);
        if (firstRow) {
          columnTypes.add(_inferColumnTypeFromValue(value));
        }
        rowData.add(_convertResultValue(value, columnTypes[i]));
      }
      rows.add(rowData);
      firstRow = false;
    }

    // If no rows, create empty column types
    if (columnTypes.isEmpty) {
      columnTypes = List.filled(columnNames.length, ColumnType.unknown);
    }

    return SqlResultSet(
      columnNames: columnNames,
      columnTypes: columnTypes,
      rows: rows,
      lastInsertId: result.lastInsertID.toString(),
    );
  }

  /// Convert MySQL result value to Dart type.
  dynamic _convertResultValue(dynamic value, ColumnType type) {
    if (value == null) return null;

    switch (type) {
      case ColumnType.dateTime:
      case ColumnType.date:
        if (value is String) {
          try {
            return DateTime.parse(value);
          } catch (_) {
            return value;
          }
        }
        return value;

      case ColumnType.boolean:
        if (value is int) {
          return value != 0;
        }
        if (value is String) {
          return value == '1' || value.toLowerCase() == 'true';
        }
        return value;

      case ColumnType.json:
        if (value is String) {
          try {
            return jsonDecode(value);
          } catch (_) {
            return value;
          }
        }
        return value;

      case ColumnType.int32:
      case ColumnType.int64:
        if (value is String) {
          return int.tryParse(value) ?? value;
        }
        return value;

      case ColumnType.float:
      case ColumnType.double:
        if (value is String) {
          return double.tryParse(value) ?? value;
        }
        return value;

      default:
        return value;
    }
  }

  /// Infer column type from value.
  ColumnType _inferColumnTypeFromValue(dynamic value) {
    if (value == null) return ColumnType.unknown;
    if (value is int) return ColumnType.int64;
    if (value is double) return ColumnType.double;
    if (value is bool) return ColumnType.boolean;
    if (value is String) {
      // Try to detect DateTime strings
      if (_isDateTimeString(value)) return ColumnType.dateTime;
      // Try to detect JSON
      if (_isJsonString(value)) return ColumnType.json;
      return ColumnType.string;
    }
    if (value is List<int>) return ColumnType.bytes;
    if (value is Map) return ColumnType.json;
    if (value is List) return ColumnType.array;
    return ColumnType.unknown;
  }

  /// Check if a string looks like a DateTime.
  bool _isDateTimeString(String value) {
    // Check for common DateTime patterns
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value)) {
      try {
        DateTime.parse(value);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// Check if a string looks like JSON.
  bool _isJsonString(String value) {
    final trimmed = value.trim();
    return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'));
  }

  /// Extract error code from MySQL exception.
  String? _extractErrorCode(Object error) {
    // mysql_client package exceptions
    final errorString = error.toString();
    // Try to extract MySQL error code from the message
    final match = RegExp(r'Error (\d+)').firstMatch(errorString);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }
}

/// MySQL transaction implementation.
class MySQLTransaction implements Transaction {
  final mysql.MySQLConnection _connection;
  bool _isActive = true;
  bool _isCommitted = false;
  bool _isRolledBack = false;

  MySQLTransaction._(this._connection);

  static Future<MySQLTransaction> _start(
    mysql.MySQLConnection connection,
    IsolationLevel? isolationLevel,
  ) async {
    // Set isolation level if specified
    if (isolationLevel != null) {
      await connection.execute(
        'SET TRANSACTION ISOLATION LEVEL ${isolationLevel.sql}',
      );
    }

    // Start transaction
    await connection.execute('START TRANSACTION');

    return MySQLTransaction._(connection);
  }

  @override
  bool get isActive => _isActive;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    _checkActive();

    try {
      // Reuse adapter logic for query execution
      final adapter = MySQLAdapter(_connection);
      return await adapter.queryRaw(query);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    _checkActive();

    try {
      final adapter = MySQLAdapter(_connection);
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
