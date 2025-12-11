/// Core types for database adapters, based on Prisma's adapter architecture.
///
/// This defines the interface between the Prisma client and database drivers,
/// allowing the connector to work with multiple databases (PostgreSQL, MySQL,
/// SQLite, Supabase) through a unified interface.
library;

import 'dart:async';

/// Represents a SQL query with parameterized values and type information.
class SqlQuery {
  /// The SQL statement with placeholders (e.g., "SELECT * FROM users WHERE id = $1")
  final String sql;

  /// The values to substitute for placeholders
  final List<dynamic> args;

  /// Type information for each argument (for proper type conversion)
  final List<ArgType> argTypes;

  const SqlQuery({
    required this.sql,
    required this.args,
    required this.argTypes,
  });

  @override
  String toString() => 'SqlQuery(sql: $sql, args: $args)';
}

/// Result set from a SQL query execution.
class SqlResultSet {
  /// Names of columns in the result
  final List<String> columnNames;

  /// Types of columns in the result
  final List<ColumnType> columnTypes;

  /// The actual data rows (each row is a list of values)
  final List<List<dynamic>> rows;

  /// Last inserted ID for AUTO_INCREMENT/SERIAL columns (if applicable)
  final String? lastInsertId;

  const SqlResultSet({
    required this.columnNames,
    required this.columnTypes,
    required this.rows,
    this.lastInsertId,
  });

  /// Check if result set is empty
  bool get isEmpty => rows.isEmpty;

  /// Number of rows in result
  int get length => rows.length;

  @override
  String toString() =>
      'SqlResultSet(rows: ${rows.length}, columns: ${columnNames.length})';
}

/// Type information for query arguments.
enum ArgType {
  int32,
  int64,
  float,
  double,
  decimal,
  boolean,
  string,
  dateTime,
  json,
  bytes,
  uuid,
  bigInt,
  unknown,
}

/// Column type information for result set columns.
enum ColumnType {
  int32,
  int64,
  float,
  double,
  decimal,
  boolean,
  string,
  dateTime,
  date,
  time,
  json,
  bytes,
  uuid,
  enum_,
  array,
  unknown,
}

/// Transaction isolation levels.
enum IsolationLevel {
  readUncommitted('READ UNCOMMITTED'),
  readCommitted('READ COMMITTED'),
  repeatableRead('REPEATABLE READ'),
  serializable('SERIALIZABLE');

  final String sql;
  const IsolationLevel(this.sql);
}

/// Connection information for a database.
class ConnectionInfo {
  /// Schema name (PostgreSQL/MySQL schema, SQLite database name)
  final String? schemaName;

  /// Maximum number of bind values supported in a single query
  /// (used for chunking large IN clauses)
  final int? maxBindValues;

  /// Whether the database supports relation joins
  /// (if false, relations are fetched separately and joined in-memory)
  final bool supportsRelationJoins;

  const ConnectionInfo({
    this.schemaName,
    this.maxBindValues,
    this.supportsRelationJoins = true,
  });
}

/// Abstract interface for database transactions.
abstract class Transaction {
  /// Execute a query within the transaction
  Future<SqlResultSet> queryRaw(SqlQuery query);

  /// Execute a command within the transaction (returns affected rows)
  Future<int> executeRaw(SqlQuery query);

  /// Commit the transaction
  Future<void> commit();

  /// Rollback the transaction
  Future<void> rollback();

  /// Whether the transaction is still active
  bool get isActive;
}

/// Interface for executing SQL queries (implemented by adapters and transactions).
abstract class SqlQueryable {
  /// Execute a query and return results
  Future<SqlResultSet> queryRaw(SqlQuery query);

  /// Execute a command and return affected row count
  Future<int> executeRaw(SqlQuery query);
}

/// Main database adapter interface.
///
/// All database adapters (PostgreSQL, MySQL, SQLite, etc.) must implement
/// this interface to work with the Prisma client.
abstract class SqlDriverAdapter implements SqlQueryable {
  /// Database provider name (e.g., 'postgresql', 'mysql', 'sqlite')
  String get provider;

  /// Adapter package name (e.g., '@prisma/adapter-pg')
  String get adapterName;

  /// Execute a raw SQL query and return results
  @override
  Future<SqlResultSet> queryRaw(SqlQuery query);

  /// Execute a raw SQL command and return affected row count
  @override
  Future<int> executeRaw(SqlQuery query);

  /// Execute a SQL script (multiple statements)
  Future<void> executeScript(String script);

  /// Start a new database transaction
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]);

  /// Get connection information (schema, capabilities, etc.)
  ConnectionInfo? getConnectionInfo();

  /// Close the connection and clean up resources
  Future<void> dispose();
}

/// Error thrown by database adapters.
class AdapterError implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const AdapterError(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'AdapterError [$code]: $message';
    }
    return 'AdapterError: $message';
  }
}
