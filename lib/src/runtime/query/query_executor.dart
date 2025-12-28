/// Query Executor for Prisma queries.
///
/// This is the runtime component that:
/// 1. Takes JSON protocol queries
/// 2. Compiles them to SQL using SqlCompiler
/// 3. Executes SQL via database adapters
/// 4. Deserializes results back to Dart objects (including nested relations)
library;

import 'dart:async';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/errors/prisma_exceptions.dart';
import 'package:prisma_flutter_connector/src/runtime/logging/query_logger.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/relation_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

/// Abstract base class for query execution.
///
/// This interface is implemented by both [QueryExecutor] (for normal operations)
/// and [TransactionExecutor] (for transaction operations), allowing delegates
/// to work with either one.
abstract class BaseExecutor {
  /// The database adapter.
  SqlDriverAdapter get adapter;

  /// Execute a query and deserialize results to maps.
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query);

  /// Execute a query expecting a single result.
  Future<Map<String, dynamic>?> executeQueryAsSingleMap(JsonQuery query);

  /// Execute a mutation (CREATE, UPDATE, DELETE) and return affected rows.
  Future<int> executeMutation(JsonQuery query);

  /// Execute a count query.
  Future<int> executeCount(JsonQuery query);
}

/// Executes Prisma queries against a database adapter.
class QueryExecutor implements BaseExecutor {
  @override
  final SqlDriverAdapter adapter;
  final SqlCompiler compiler;

  /// Optional schema registry for relation information.
  /// When provided, enables includes with automatic JOINs.
  final SchemaRegistry? schema;

  /// Optional query logger for debugging and monitoring.
  final QueryLogger? logger;

  QueryExecutor({
    required this.adapter,
    SqlCompiler? compiler,
    this.schema,
    this.logger,
  }) : compiler = compiler ??
            SqlCompiler(
              provider: adapter.provider,
              schemaName: adapter.getConnectionInfo()?.schemaName,
              schema: schema,
            );

  /// Execute a query and return raw results.
  Future<SqlResultSet> executeQuery(JsonQuery query) async {
    // Compile JSON query to SQL
    final sqlQuery = compiler.compile(query);

    return _executeWithLogging(
      sql: sqlQuery.sql,
      parameters: sqlQuery.args,
      model: query.modelName,
      operation: query.action,
      execute: () => adapter.queryRaw(sqlQuery),
    );
  }

  /// Execute raw SQL and return results.
  ///
  /// This is an escape hatch for complex queries not supported by the
  /// query builder. Use parameterized queries to prevent SQL injection.
  ///
  /// Example:
  /// ```dart
  /// final results = await executor.executeRaw(
  ///   'SELECT * FROM users WHERE created_at > NOW() - INTERVAL \$1 DAY',
  ///   [7],
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> executeRaw(
    String sql,
    List<dynamic> parameters,
  ) async {
    final argTypes = parameters.map((p) => _inferArgType(p)).toList();
    final sqlQuery = SqlQuery(sql: sql, args: parameters, argTypes: argTypes);

    final result = await _executeWithLogging(
      sql: sql,
      parameters: parameters,
      operation: 'raw',
      execute: () => adapter.queryRaw(sqlQuery),
    );

    return _resultSetToMaps(result);
  }

  /// Execute raw SQL mutation (INSERT/UPDATE/DELETE) and return affected rows.
  ///
  /// Example:
  /// ```dart
  /// final affected = await executor.executeMutationRaw(
  ///   'DELETE FROM sessions WHERE expires_at < NOW()',
  ///   [],
  /// );
  /// ```
  Future<int> executeMutationRaw(
    String sql,
    List<dynamic> parameters,
  ) async {
    final argTypes = parameters.map((p) => _inferArgType(p)).toList();
    final sqlQuery = SqlQuery(sql: sql, args: parameters, argTypes: argTypes);

    final startTime = DateTime.now();
    logger?.onQueryStart(QueryStartEvent(
      sql: sql,
      parameters: parameters,
      operation: 'rawMutation',
      startTime: startTime,
    ));

    try {
      final result = await adapter.executeRaw(sqlQuery);
      final duration = DateTime.now().difference(startTime);

      logger?.onQueryEnd(QueryEndEvent(
        sql: sql,
        parameters: parameters,
        operation: 'rawMutation',
        duration: duration,
        rowCount: result,
      ));

      return result;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      logger?.onQueryError(QueryErrorEvent(
        sql: sql,
        parameters: parameters,
        operation: 'rawMutation',
        duration: duration,
        error: e,
        stackTrace: stackTrace,
      ));
      throw _mapError(e);
    }
  }

  /// Helper to execute SQL with logging and error mapping.
  Future<SqlResultSet> _executeWithLogging({
    required String sql,
    required List<dynamic> parameters,
    String? model,
    String? operation,
    required Future<SqlResultSet> Function() execute,
  }) async {
    final startTime = DateTime.now();

    logger?.onQueryStart(QueryStartEvent(
      sql: sql,
      parameters: parameters,
      model: model,
      operation: operation,
      startTime: startTime,
    ));

    try {
      final result = await execute();
      final duration = DateTime.now().difference(startTime);

      logger?.onQueryEnd(QueryEndEvent(
        sql: sql,
        parameters: parameters,
        model: model,
        operation: operation,
        duration: duration,
        rowCount: result.rows.length,
      ));

      return result;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      logger?.onQueryError(QueryErrorEvent(
        sql: sql,
        parameters: parameters,
        model: model,
        operation: operation,
        duration: duration,
        error: e,
        stackTrace: stackTrace,
      ));
      throw _mapError(e);
    }
  }

  /// Map adapter errors to typed Prisma exceptions.
  PrismaException _mapError(Object error) {
    if (error is PrismaException) return error;

    if (error is AdapterError) {
      // Map based on database provider
      switch (adapter.provider) {
        case 'postgresql':
        case 'supabase':
          return PrismaErrorMapper.fromPostgresError(
            error.message,
            sqlState: error.code,
            originalError: error.originalError,
          );
        case 'mysql':
          final errorCode =
              error.code != null ? int.tryParse(error.code!) : null;
          return PrismaErrorMapper.fromMySqlError(
            error.message,
            errorCode: errorCode,
            originalError: error.originalError,
          );
        case 'sqlite':
          final errorCode =
              error.code != null ? int.tryParse(error.code!) : null;
          return PrismaErrorMapper.fromSqliteError(
            error.message,
            errorCode: errorCode,
            originalError: error.originalError,
          );
        default:
          // Fallback for any other provider
          return InternalException(
            error.message,
            originalError: error,
            context: {'code': error.code},
          );
      }
    }

    return InternalException(
      error.toString(),
      originalError: error,
    );
  }

  /// Infer ArgType from a Dart value.
  ArgType _inferArgType(dynamic value) {
    if (value == null) return ArgType.unknown;
    if (value is int) return ArgType.int64;
    if (value is double) return ArgType.double;
    if (value is bool) return ArgType.boolean;
    if (value is String) return ArgType.string;
    if (value is DateTime) return ArgType.dateTime;
    if (value is List<int>) return ArgType.bytes;
    if (value is Map) return ArgType.json;
    return ArgType.unknown;
  }

  /// Execute a mutation (CREATE, UPDATE, DELETE) and return affected rows.
  @override
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

  /// Execute a mutation with potential relation operations (connect/disconnect).
  ///
  /// This method handles CREATE and UPDATE queries that include `connect` or
  /// `disconnect` operations for many-to-many relations. It executes the main
  /// mutation first, then executes all relation mutations in sequence.
  ///
  /// If the main mutation succeeds but a relation mutation fails, the main
  /// record will already be created/updated. Consider using
  /// `executeMutationWithRelationsAtomic` for atomic operations.
  ///
  /// Example:
  /// ```dart
  /// final result = await executor.executeMutationWithRelations(
  ///   JsonQueryBuilder()
  ///       .model('SlotOfAppointment')
  ///       .action(QueryAction.create)
  ///       .data({
  ///         'id': 'slot-123',
  ///         'startsAt': DateTime.now(),
  ///         'users': {
  ///           'connect': [{'id': 'user-1'}],
  ///         },
  ///       })
  ///       .build(),
  /// );
  /// ```
  Future<Map<String, dynamic>?> executeMutationWithRelations(
    JsonQuery query,
  ) async {
    // Compile with relation support
    final compiled = compiler.compileWithRelations(query);

    // Execute main mutation
    final result = await adapter.queryRaw(compiled.mainQuery);

    // Execute relation mutations if any
    if (compiled.hasRelationMutations) {
      for (final relationQuery in compiled.relationMutations) {
        try {
          await adapter.executeRaw(relationQuery);
        } catch (e, s) {
          // Log the error but continue with other relation mutations
          // This is the non-atomic version - errors are logged but don't stop execution
          // Use executeMutationWithRelationsAtomic() if you need all-or-nothing behavior
          logger?.onQueryError(QueryErrorEvent(
            sql: relationQuery.sql,
            parameters: relationQuery.args,
            model: query.modelName,
            operation: 'relationMutation',
            duration: Duration.zero,
            error: e,
            stackTrace: s,
          ));
          // Don't rethrow - continue with other mutations (non-atomic behavior)
        }
      }
    }

    // Return the created/updated record
    if (result.rows.isNotEmpty) {
      return _resultSetToMaps(result).first;
    }
    return null;
  }

  /// Execute a mutation with relation operations inside a transaction.
  ///
  /// This ensures atomicity - if any relation mutation fails, the entire
  /// operation is rolled back.
  ///
  /// Example:
  /// ```dart
  /// final result = await executor.executeMutationWithRelationsAtomic(
  ///   JsonQueryBuilder()
  ///       .model('SlotOfAppointment')
  ///       .action(QueryAction.update)
  ///       .where({'id': 'slot-123'})
  ///       .data({
  ///         'users': {
  ///           'connect': [{'id': 'user-1'}],
  ///           'disconnect': [{'id': 'user-2'}],
  ///         },
  ///       })
  ///       .build(),
  /// );
  /// ```
  Future<Map<String, dynamic>?> executeMutationWithRelationsAtomic(
    JsonQuery query, {
    IsolationLevel? isolationLevel,
  }) async {
    return executeInTransaction<Map<String, dynamic>?>((txExecutor) async {
      // Compile with relation support
      final compiled = compiler.compileWithRelations(query);

      // Execute main mutation
      final result = await txExecutor.transaction.queryRaw(compiled.mainQuery);

      // Execute relation mutations
      for (final relationQuery in compiled.relationMutations) {
        await txExecutor.transaction.executeRaw(relationQuery);
      }

      // Return the created/updated record
      if (result.rows.isNotEmpty) {
        return _resultSetToMaps(result).first;
      }
      return null;
    }, isolationLevel: isolationLevel);
  }

  /// Execute a query and deserialize results to maps.
  ///
  /// If the query includes relations via `include`, results are automatically
  /// deserialized into nested structures using the [RelationDeserializer].
  @override
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query) async {
    // Compile to get relation metadata
    final sqlQuery = compiler.compile(query);

    // Execute the query
    final result = await _executeWithLogging(
      sql: sqlQuery.sql,
      parameters: sqlQuery.args,
      model: query.modelName,
      operation: query.action,
      execute: () => adapter.queryRaw(sqlQuery),
    );

    // Check if we need to deserialize relations
    final hasRelations =
        sqlQuery.hasRelations && sqlQuery.relationMetadata is CompiledRelations;

    // Convert to maps - preserve aliases when relations are present so
    // the RelationDeserializer can match column aliases like "user__name"
    final flatMaps = _resultSetToMaps(result, preserveAliases: hasRelations);

    if (hasRelations) {
      final compiledRelations = sqlQuery.relationMetadata as CompiledRelations;

      // Use relation deserializer to nest flat JOIN results
      final deserializer = RelationDeserializer(
        schema: compiler.schema ?? schemaRegistry,
      );

      final deserialized = deserializer.deserialize(
        rows: flatMaps,
        baseModel: query.modelName,
        columnAliases: compiledRelations.columnAliases,
        includedRelations: compiledRelations.includedRelations,
      );

      // Preserve computed fields that were lost during relation deserialization.
      // Computed fields are added to the SELECT clause but not registered in
      // columnAliases, so they get dropped by _extractBaseColumns().
      // We need to copy them back from the flat maps.
      //
      // Note: This relies on primary keys to match rows. Models without primary
      // keys (extremely rare in Prisma) won't have computed fields preserved.
      // This is consistent with RelationDeserializer which has the same limitation.
      if (sqlQuery.computedFieldNames.isNotEmpty && flatMaps.isNotEmpty) {
        // Group flat maps by primary key to match with deserialized results
        // Since deserialization groups by PK, we need the first row for each group
        final model = (compiler.schema ?? schemaRegistry).getModel(query.modelName);
        if (model != null && model.primaryKeys.isNotEmpty) {
          // Support composite primary keys (@@id([field1, field2]))
          final pkColumns =
              model.primaryKeys.map((pk) => pk.columnName).toList();
          final flatMapByPk = <String, Map<String, dynamic>>{};
          for (final row in flatMaps) {
            final pkValue =
                pkColumns.map((c) => row[c]?.toString() ?? '').join('::');
            // Keep only the first occurrence for each PK (same as deserializer)
            flatMapByPk.putIfAbsent(pkValue, () => row);
          }

          for (final resultRow in deserialized) {
            final pkValue =
                pkColumns.map((c) => resultRow[c]?.toString() ?? '').join('::');
            final flatRow = flatMapByPk[pkValue];
            if (flatRow != null) {
              for (final fieldName in sqlQuery.computedFieldNames) {
                if (flatRow.containsKey(fieldName)) {
                  resultRow[fieldName] = flatRow[fieldName];
                }
              }
            }
          }
        }
      }

      return deserialized;
    }

    return flatMaps;
  }

  /// Execute a query expecting a single result.
  @override
  Future<Map<String, dynamic>?> executeQueryAsSingleMap(JsonQuery query) async {
    final results = await executeQueryAsMaps(query);
    return results.isEmpty ? null : results.first;
  }

  /// Execute a count query.
  @override
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
        adapter: adapter,
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
  ///
  /// [preserveAliases] - If true, preserves column aliases as-is without
  /// camelCase conversion. Used when relations are present and the
  /// RelationDeserializer needs to match aliases.
  List<Map<String, dynamic>> _resultSetToMaps(
    SqlResultSet result, {
    bool preserveAliases = false,
  }) {
    if (result.rows.isEmpty) return [];

    final maps = <Map<String, dynamic>>[];

    for (final row in result.rows) {
      final map = <String, dynamic>{};

      for (var i = 0; i < result.columnNames.length; i++) {
        final columnName = result.columnNames[i];
        final value = i < row.length ? row[i] : null;

        // Convert snake_case column names to camelCase (unless preserving aliases)
        final key = preserveAliases ? columnName : _toCamelCase(columnName);

        map[key] = _deserializeValue(value, result.columnTypes[i]);
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
        parts
            .skip(1)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
            .join();
  }

  /// Close the adapter connection.
  Future<void> dispose() async {
    await adapter.dispose();
  }
}

/// Query executor for use within transactions.
class TransactionExecutor implements BaseExecutor {
  final Transaction transaction;
  final SqlCompiler compiler;
  final SqlDriverAdapter _adapter;

  TransactionExecutor({
    required this.transaction,
    required this.compiler,
    required SqlDriverAdapter adapter,
  }) : _adapter = adapter;

  @override
  SqlDriverAdapter get adapter => _adapter;

  /// Execute a query within the transaction.
  Future<SqlResultSet> executeQuery(JsonQuery query) async {
    final sqlQuery = compiler.compile(query);
    return transaction.queryRaw(sqlQuery);
  }

  /// Execute a mutation within the transaction.
  @override
  Future<int> executeMutation(JsonQuery query) async {
    final sqlQuery = compiler.compile(query);

    if (query.action == 'create') {
      final result = await transaction.queryRaw(sqlQuery);
      return result.rows.isNotEmpty ? 1 : 0;
    }

    return transaction.executeRaw(sqlQuery);
  }

  /// Execute a query and deserialize results to maps.
  @override
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query) async {
    final result = await executeQuery(query);
    return _resultSetToMaps(result);
  }

  /// Execute a query expecting a single result.
  @override
  Future<Map<String, dynamic>?> executeQueryAsSingleMap(JsonQuery query) async {
    final results = await executeQueryAsMaps(query);
    return results.isEmpty ? null : results.first;
  }

  /// Execute a count query.
  @override
  Future<int> executeCount(JsonQuery query) async {
    final result = await executeQuery(query);

    if (result.rows.isEmpty) return 0;

    final count = result.rows.first.first;
    if (count is int) return count;
    if (count is String) return int.parse(count);

    return 0;
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
        parts
            .skip(1)
            .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
            .join();
  }
}
