/// Query Executor for Prisma queries.
///
/// This is the runtime component that:
/// 1. Takes JSON protocol queries
/// 2. Compiles them to SQL using SqlCompiler
/// 3. Executes SQL via database adapters
/// 4. Deserializes results back to Dart objects
library;

import 'dart:async';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';

/// Executes Prisma queries against a database adapter.
class QueryExecutor {
  final SqlDriverAdapter adapter;
  final SqlCompiler compiler;

  QueryExecutor({
    required this.adapter,
    SqlCompiler? compiler,
  }) : compiler = compiler ??
            SqlCompiler(
              provider: adapter.provider,
              schemaName: adapter.getConnectionInfo()?.schemaName,
            );

  /// Execute a query and return raw results.
  Future<SqlResultSet> executeQuery(JsonQuery query) async {
    // Compile JSON query to SQL
    final sqlQuery = compiler.compile(query);

    // Execute via adapter
    final result = await adapter.queryRaw(sqlQuery);

    return result;
  }

  /// Execute a mutation (CREATE, UPDATE, DELETE) and return affected rows.
  Future<int> executeMutation(JsonQuery query) async {
    final sqlQuery = compiler.compile(query);

    // For CREATE queries, we want to return the created row
    if (query.action == 'create') {
      final result = await adapter.queryRaw(sqlQuery);
      return result.rows.isNotEmpty ? 1 : 0;
    }

    // For other mutations, return affected row count
    final affectedRows = await adapter.executeRaw(sqlQuery);
    return affectedRows;
  }

  /// Execute a query and deserialize results to maps.
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query) async {
    final result = await executeQuery(query);

    return _resultSetToMaps(result);
  }

  /// Execute a query expecting a single result.
  Future<Map<String, dynamic>?> executeQueryAsSingleMap(JsonQuery query) async {
    final results = await executeQueryAsMaps(query);
    return results.isEmpty ? null : results.first;
  }

  /// Execute a count query.
  Future<int> executeCount(JsonQuery query) async {
    final result = await executeQuery(query);

    if (result.rows.isEmpty) return 0;

    final count = result.rows.first.first;
    if (count is int) return count;
    if (count is String) return int.parse(count);

    return 0;
  }

  /// Execute within a transaction.
  Future<T> executeInTransaction<T>(
    Future<T> Function(TransactionExecutor) callback, {
    IsolationLevel? isolationLevel,
  }) async {
    final transaction = await adapter.startTransaction(isolationLevel);

    try {
      final txExecutor = TransactionExecutor(
        transaction: transaction,
        compiler: compiler,
      );

      final result = await callback(txExecutor);

      await transaction.commit();

      return result;
    } catch (e) {
      if (transaction.isActive) {
        await transaction.rollback();
      }
      rethrow;
    }
  }

  /// Convert SqlResultSet to list of maps.
  List<Map<String, dynamic>> _resultSetToMaps(SqlResultSet result) {
    if (result.rows.isEmpty) return [];

    final maps = <Map<String, dynamic>>[];

    for (final row in result.rows) {
      final map = <String, dynamic>{};

      for (var i = 0; i < result.columnNames.length; i++) {
        final columnName = result.columnNames[i];
        final value = i < row.length ? row[i] : null;

        // Convert snake_case column names to camelCase
        final camelCaseName = _toCamelCase(columnName);

        map[camelCaseName] = _deserializeValue(value, result.columnTypes[i]);
      }

      maps.add(map);
    }

    return maps;
  }

  /// Deserialize a database value to Dart type.
  dynamic _deserializeValue(dynamic value, ColumnType type) {
    if (value == null) return null;

    switch (type) {
      case ColumnType.dateTime:
        if (value is String) {
          return DateTime.parse(value);
        }
        if (value is DateTime) {
          return value;
        }
        return value;

      case ColumnType.date:
        if (value is String) {
          return DateTime.parse(value);
        }
        return value;

      case ColumnType.json:
        // JSON values are typically returned as strings that need parsing
        // or as already-parsed objects depending on the driver
        return value;

      case ColumnType.boolean:
        if (value is int) {
          return value != 0;
        }
        return value;

      default:
        return value;
    }
  }

  /// Convert snake_case to camelCase.
  String _toCamelCase(String input) {
    if (!input.contains('_')) return input;

    final parts = input.split('_');
    if (parts.isEmpty) return input;

    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
  }

  /// Close the adapter connection.
  Future<void> dispose() async {
    await adapter.dispose();
  }
}

/// Query executor for use within transactions.
class TransactionExecutor {
  final Transaction transaction;
  final SqlCompiler compiler;

  TransactionExecutor({
    required this.transaction,
    required this.compiler,
  });

  /// Execute a query within the transaction.
  Future<SqlResultSet> executeQuery(JsonQuery query) async {
    final sqlQuery = compiler.compile(query);
    return await transaction.queryRaw(sqlQuery);
  }

  /// Execute a mutation within the transaction.
  Future<int> executeMutation(JsonQuery query) async {
    final sqlQuery = compiler.compile(query);

    if (query.action == 'create') {
      final result = await transaction.queryRaw(sqlQuery);
      return result.rows.isNotEmpty ? 1 : 0;
    }

    return await transaction.executeRaw(sqlQuery);
  }

  /// Execute a query and deserialize results to maps.
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query) async {
    final result = await executeQuery(query);
    return _resultSetToMaps(result);
  }

  /// Execute a query expecting a single result.
  Future<Map<String, dynamic>?> executeQueryAsSingleMap(JsonQuery query) async {
    final results = await executeQueryAsMaps(query);
    return results.isEmpty ? null : results.first;
  }

  /// Convert SqlResultSet to list of maps.
  List<Map<String, dynamic>> _resultSetToMaps(SqlResultSet result) {
    if (result.rows.isEmpty) return [];

    final maps = <Map<String, dynamic>>[];

    for (final row in result.rows) {
      final map = <String, dynamic>{};

      for (var i = 0; i < result.columnNames.length; i++) {
        final columnName = result.columnNames[i];
        final value = i < row.length ? row[i] : null;
        final camelCaseName = _toCamelCase(columnName);

        map[camelCaseName] = value;
      }

      maps.add(map);
    }

    return maps;
  }

  String _toCamelCase(String input) {
    if (!input.contains('_')) return input;

    final parts = input.split('_');
    if (parts.isEmpty) return input;

    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
  }
}
