/// SQL Compiler for Prisma queries.
///
/// This compiles Prisma's JSON protocol queries into SQL statements.
/// This is a simplified Dart-native implementation of Prisma's query compiler.
///
/// For production use, this could be replaced with Prisma's WASM compiler
/// via FFI, but this pure Dart version is easier to debug and works everywhere.
library;

import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/relation_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

/// Compiles JSON queries to SQL.
class SqlCompiler {
  final String provider;
  final String? schemaName;
  final SchemaRegistry? schema;

  /// Lazily created relation compiler.
  RelationCompiler? _relationCompiler;

  SqlCompiler({
    required this.provider,
    this.schemaName,
    this.schema,
  });

  /// Get or create relation compiler.
  /// Uses startingCounter: 1 since t0 is reserved for the base table.
  RelationCompiler get relationCompiler =>
      _relationCompiler ??= RelationCompiler(
        schema: schema ?? schemaRegistry,
        provider: provider,
        startingCounter: 1,
      );

  /// Compile a JSON query to SQL.
  SqlQuery compile(JsonQuery query) {
    switch (query.action) {
      case 'findUnique':
      case 'findUniqueOrThrow':
      case 'findFirst':
      case 'findFirstOrThrow':
        return _compileFindQuery(query, single: true);

      case 'findMany':
        return _compileFindQuery(query, single: false);

      case 'create':
        return _compileCreateQuery(query);

      case 'createMany':
        return _compileCreateManyQuery(query);

      case 'update':
        return _compileUpdateQuery(query);

      case 'updateMany':
        return _compileUpdateManyQuery(query);

      case 'delete':
        return _compileDeleteQuery(query);

      case 'deleteMany':
        return _compileDeleteManyQuery(query);

      case 'count':
        return _compileCountQuery(query);

      case 'aggregate':
        return _compileAggregateQuery(query);

      case 'groupBy':
        return _compileGroupByQuery(query);

      case 'upsert':
        return _compileUpsertQuery(query);

      default:
        throw UnsupportedError('Action ${query.action} not yet implemented');
    }
  }

  /// Compile a SELECT query (findUnique, findFirst, findMany).
  SqlQuery _compileFindQuery(JsonQuery query, {required bool single}) {
    final args = query.args.arguments ?? {};
    // Use model name as-is (don't convert to snake_case)
    // Prisma schemas can have PascalCase or snake_case table names
    final tableName = query.modelName;

    // Check for selectFields (v0.2.5+)
    final selectFieldsList = args['selectFields'] as List<dynamic>?;
    final hasSelectFields =
        selectFieldsList != null && selectFieldsList.isNotEmpty;

    // Check for computed fields (v0.2.6+)
    final computedFields = args['_computed'] as Map<String, dynamic>?;
    final hasComputedFields = computedFields != null && computedFields.isNotEmpty;

    // Check for include directive (relations)
    final include = _extractInclude(query.args.selection);
    final hasRelations = include != null && include.isNotEmpty;

    // Determine if we need a table alias (for computed fields or relations)
    final needsAlias = hasComputedFields || hasRelations;
    const baseAlias = 't0';

    // Build SELECT clause and JOIN clauses if relations are included
    String selectClause;
    String joinClauses = '';
    CompiledRelations? compiledRelations;

    if (hasRelations &&
        (schema != null || schemaRegistry.hasModel(query.modelName))) {
      // Use relation compiler for JOINs
      compiledRelations = relationCompiler.compile(
        baseModel: query.modelName,
        baseAlias: baseAlias,
        include: include,
      );

      if (compiledRelations.isNotEmpty) {
        if (hasSelectFields) {
          // Use selectFields with relation support
          selectClause = _buildSelectFieldsWithRelations(
            selectFieldsList.cast<String>(),
            baseAlias,
            compiledRelations,
          );
        } else {
          selectClause = relationCompiler.generateSelectColumns(
            compiledRelations.columnAliases,
          );
        }
        joinClauses = compiledRelations.joinClauses;
      } else {
        // Fall back to simple select
        if (hasSelectFields) {
          selectClause = _buildSelectFieldsFromList(selectFieldsList.cast<String>());
        } else {
          final selectFields = _buildSelectFields(query.args.selection);
          selectClause = selectFields.isEmpty ? '*' : selectFields.join(', ');
        }
      }
    } else {
      // Simple select without relations
      if (hasSelectFields) {
        if (needsAlias) {
          selectClause = _buildSelectFieldsWithAlias(
            selectFieldsList.cast<String>(),
            baseAlias,
          );
        } else {
          selectClause = _buildSelectFieldsFromList(selectFieldsList.cast<String>());
        }
      } else {
        if (needsAlias) {
          selectClause = '"$baseAlias".*';
        } else {
          final selectFields = _buildSelectFields(query.args.selection);
          selectClause = selectFields.isEmpty ? '*' : selectFields.join(', ');
        }
      }
    }

    // Append computed fields to SELECT clause and collect their parameters
    var computedArgs = <dynamic>[];
    var computedTypes = <ArgType>[];
    if (hasComputedFields) {
      final (computedClauses, cArgs, cTypes) = _buildComputedFieldsClauses(
        computedFields,
        baseAlias,
      );
      computedArgs = cArgs;
      computedTypes = cTypes;
      if (computedClauses.isNotEmpty) {
        selectClause = '$selectClause, $computedClauses';
      }
    }

    // Build WHERE clause
    // Pass baseAlias when JOINs are present to disambiguate column names
    // Start param index after computed field params
    final where = args['where'] as Map<String, dynamic>?;
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      modelName: query.modelName,
      baseAlias: needsAlias ? baseAlias : null,
      startIndex: computedArgs.length + 1,
    );

    // Build ORDER BY clause
    // Pass baseAlias when JOINs are present to disambiguate column names
    final orderBy = args['orderBy'] as Map<String, dynamic>?;
    final orderByClause = _buildOrderByClause(
      orderBy,
      baseAlias: needsAlias ? baseAlias : null,
    );

    // Build LIMIT/OFFSET
    final take = args['take'] as int?;
    final skip = args['skip'] as int?;

    // Construct SQL with optional table alias
    final sql = StringBuffer();
    if (needsAlias) {
      sql.write(
          'SELECT $selectClause FROM ${_quoteIdentifier(tableName)} "$baseAlias"');
      if (joinClauses.isNotEmpty) {
        sql.write(' $joinClauses');
      }
    } else {
      sql.write('SELECT $selectClause FROM ${_quoteIdentifier(tableName)}');
    }

    if (whereClause.isNotEmpty) {
      sql.write(' WHERE $whereClause');
    }

    if (orderByClause.isNotEmpty) {
      sql.write(' ORDER BY $orderByClause');
    }

    if (single) {
      sql.write(' LIMIT 1');
    } else if (take != null) {
      sql.write(' LIMIT $take');
    }

    if (skip != null) {
      sql.write(' OFFSET $skip');
    }

    // Combine computed field args (first) with WHERE args (second)
    final allArgs = [...computedArgs, ...whereArgs];
    final allTypes = [...computedTypes, ...whereTypes];

    return SqlQuery(
      sql: sql.toString(),
      args: allArgs,
      argTypes: allTypes,
      relationMetadata: compiledRelations,
    );
  }

  /// Extract include from selection.
  Map<String, dynamic>? _extractInclude(JsonSelection? selection) {
    if (selection == null || selection.fields == null) return null;

    final include = <String, dynamic>{};

    for (final entry in selection.fields!.entries) {
      final fieldSelection = entry.value;
      // A field is an include if it has nested selection (means it's a relation)
      if (fieldSelection.selection != null) {
        include[entry.key] = {
          if (fieldSelection.arguments != null) ...fieldSelection.arguments!,
          if (fieldSelection.selection!.fields != null)
            'include': _extractInclude(fieldSelection.selection),
        };
        if (include[entry.key] is Map && (include[entry.key] as Map).isEmpty) {
          include[entry.key] = true;
        }
      }
    }

    return include.isEmpty ? null : include;
  }

  /// Compile a CREATE query.
  SqlQuery _compileCreateQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final data = args['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw ArgumentError('CREATE requires data');
    }

    final tableName = query.modelName;
    final columns = <String>[];
    final placeholders = <String>[];
    final values = <dynamic>[];
    final types = <ArgType>[];

    var paramIndex = 1;
    for (final entry in data.entries) {
      // Use field name as-is (don't convert to snake_case)
      columns.add(_quoteIdentifier(entry.key));
      placeholders.add(_placeholder(paramIndex++));
      values.add(entry.value);
      types.add(_inferArgType(entry.value));
    }

    final sql = 'INSERT INTO ${_quoteIdentifier(tableName)} '
        '(${columns.join(', ')}) '
        'VALUES (${placeholders.join(', ')})';

    // Add RETURNING clause for PostgreSQL/Supabase
    final sqlWithReturning =
        (provider == 'postgresql' || provider == 'supabase')
            ? '$sql RETURNING *'
            : sql;

    return SqlQuery(
      sql: sqlWithReturning,
      args: values,
      argTypes: types,
    );
  }

  /// Compile a CREATE MANY query.
  SqlQuery _compileCreateManyQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};

    // Handle both direct list and wrapped {'data': [...]} format
    // The delegate_generator wraps data in {'data': ...}, but sql_compiler
    // expects a direct list
    var dataArg = args['data'];
    if (dataArg is Map && dataArg.containsKey('data')) {
      dataArg = dataArg['data'];
    }
    final dataList = dataArg as List<dynamic>?;

    if (dataList == null || dataList.isEmpty) {
      throw ArgumentError('CREATE MANY requires data array');
    }

    final tableName = query.modelName;
    final firstRow = dataList.first as Map<String, dynamic>;
    // Use field names as-is (don't convert to snake_case)
    final columns = firstRow.keys.map((k) => _quoteIdentifier(k)).toList();

    final valueSets = <String>[];
    final values = <dynamic>[];
    final types = <ArgType>[];

    var paramIndex = 1;
    for (final row in dataList) {
      final rowData = row as Map<String, dynamic>;
      final placeholders = <String>[];

      for (final value in rowData.values) {
        placeholders.add(_placeholder(paramIndex++));
        values.add(value);
        types.add(_inferArgType(value));
      }

      valueSets.add('(${placeholders.join(', ')})');
    }

    final sql = 'INSERT INTO ${_quoteIdentifier(tableName)} '
        '(${columns.join(', ')}) '
        'VALUES ${valueSets.join(', ')}';

    return SqlQuery(
      sql: sql,
      args: values,
      argTypes: types,
    );
  }

  /// Compile an UPDATE query.
  SqlQuery _compileUpdateQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;
    final data = args['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw ArgumentError('UPDATE requires data');
    }

    final tableName = query.modelName;

    // Build SET clause
    final setClauses = <String>[];
    final values = <dynamic>[];
    final types = <ArgType>[];
    var paramIndex = 1;

    for (final entry in data.entries) {
      // Use field name as-is (don't convert to snake_case)
      setClauses.add(
          '${_quoteIdentifier(entry.key)} = ${_placeholder(paramIndex++)}');
      values.add(entry.value);
      types.add(_inferArgType(entry.value));
    }

    // Build WHERE clause
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      startIndex: paramIndex,
      modelName: query.modelName,
    );
    values.addAll(whereArgs);
    types.addAll(whereTypes);

    final sql = 'UPDATE ${_quoteIdentifier(tableName)} '
        'SET ${setClauses.join(', ')}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    // Add RETURNING clause for PostgreSQL/Supabase to get updated row
    final sqlWithReturning =
        (provider == 'postgresql' || provider == 'supabase')
            ? '$sql RETURNING *'
            : sql;

    return SqlQuery(
      sql: sqlWithReturning,
      args: values,
      argTypes: types,
    );
  }

  /// Compile an UPDATE MANY query.
  SqlQuery _compileUpdateManyQuery(JsonQuery query) {
    // Same as UPDATE but without LIMIT
    return _compileUpdateQuery(query);
  }

  /// Compile a DELETE query.
  SqlQuery _compileDeleteQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;

    final tableName = query.modelName;
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      modelName: query.modelName,
    );

    final sql = 'DELETE FROM ${_quoteIdentifier(tableName)}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    return SqlQuery(
      sql: sql,
      args: whereArgs,
      argTypes: whereTypes,
    );
  }

  /// Compile a DELETE MANY query.
  SqlQuery _compileDeleteManyQuery(JsonQuery query) {
    return _compileDeleteQuery(query);
  }

  /// Compile a COUNT query.
  SqlQuery _compileCountQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;

    final tableName = query.modelName;
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      modelName: query.modelName,
    );

    final sql = 'SELECT COUNT(*) FROM ${_quoteIdentifier(tableName)}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    return SqlQuery(
      sql: sql,
      args: whereArgs,
      argTypes: whereTypes,
    );
  }

  /// Compile an AGGREGATE query.
  ///
  /// Supports: _count, _avg, _sum, _min, _max with optional FILTER clause.
  ///
  /// Example (basic):
  /// ```dart
  /// JsonQueryBuilder()
  ///   .model('Product')
  ///   .action(QueryAction.aggregate)
  ///   .aggregation({
  ///     '_count': true,
  ///     '_avg': {'price': true},
  ///     '_sum': {'quantity': true},
  ///     '_min': {'price': true},
  ///     '_max': {'price': true},
  ///   })
  ///   .build();
  /// ```
  ///
  /// Example (with FILTER clause for conditional aggregations):
  /// ```dart
  /// JsonQueryBuilder()
  ///   .model('ConsultantReview')
  ///   .action(QueryAction.aggregate)
  ///   .aggregation({
  ///     '_count': true,  // Total count
  ///     '_avg': {'rating': true},
  ///     '_countFiltered': [
  ///       {'alias': 'fiveStar', 'filter': {'rating': 5}},
  ///       {'alias': 'fourStar', 'filter': {'rating': 4}},
  ///       {'alias': 'threeStar', 'filter': {'rating': 3}},
  ///     ],
  ///   })
  ///   .build();
  /// // Generates: SELECT COUNT(*), AVG("rating"),
  /// //   COUNT(*) FILTER (WHERE "rating" = $1) AS "fiveStar",
  /// //   COUNT(*) FILTER (WHERE "rating" = $2) AS "fourStar", ...
  /// ```
  SqlQuery _compileAggregateQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;
    final agg = args['_aggregate'] as Map<String, dynamic>? ?? {};

    final tableName = query.modelName;
    final functions = <String>[];
    final filterValues = <dynamic>[];
    final filterTypes = <ArgType>[];

    // Build WHERE clause first to determine parameter offset for FILTER clauses
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      modelName: query.modelName,
    );

    // FILTER parameters start after WHERE parameters
    var filterParamIndex = whereArgs.length + 1;

    // _count
    if (agg['_count'] == true) {
      functions.add('COUNT(*) AS "_count"');
    } else if (agg['_count'] is Map) {
      // Count specific fields
      final countFields = agg['_count'] as Map<String, dynamic>;
      for (final field in countFields.keys) {
        if (countFields[field] == true) {
          functions.add(
            'COUNT(${_quoteIdentifier(field)}) AS "_count_$field"',
          );
        }
      }
    }

    // _countFiltered - COUNT with FILTER clause (PostgreSQL only)
    if (agg['_countFiltered'] is List && _supportsFilterClause()) {
      final countFilters = agg['_countFiltered'] as List<dynamic>;
      for (final filterSpec in countFilters) {
        if (filterSpec is Map<String, dynamic>) {
          final alias = filterSpec['alias'] as String?;
          final filter = filterSpec['filter'] as Map<String, dynamic>?;
          if (alias != null && filter != null) {
            final filterClause = _buildSimpleFilterCondition(
              filter,
              filterParamIndex,
              filterValues,
              filterTypes,
            );
            filterParamIndex += filter.length;
            functions.add(
              'COUNT(*) FILTER (WHERE $filterClause) AS ${_quoteIdentifier(alias)}',
            );
          }
        }
      }
    }

    // _avg
    if (agg['_avg'] is Map) {
      final avgFields = agg['_avg'] as Map<String, dynamic>;
      for (final field in avgFields.keys) {
        if (avgFields[field] == true) {
          functions.add('AVG(${_quoteIdentifier(field)}) AS "_avg_$field"');
        }
      }
    }

    // _avgFiltered - AVG with FILTER clause (PostgreSQL only)
    if (agg['_avgFiltered'] is List && _supportsFilterClause()) {
      final avgFilters = agg['_avgFiltered'] as List<dynamic>;
      for (final filterSpec in avgFilters) {
        if (filterSpec is Map<String, dynamic>) {
          final alias = filterSpec['alias'] as String?;
          final field = filterSpec['field'] as String?;
          final filter = filterSpec['filter'] as Map<String, dynamic>?;
          if (alias != null && field != null && filter != null) {
            final filterClause = _buildSimpleFilterCondition(
              filter,
              filterParamIndex,
              filterValues,
              filterTypes,
            );
            filterParamIndex += filter.length;
            functions.add(
              'AVG(${_quoteIdentifier(field)}) FILTER (WHERE $filterClause) AS ${_quoteIdentifier(alias)}',
            );
          }
        }
      }
    }

    // _sum
    if (agg['_sum'] is Map) {
      final sumFields = agg['_sum'] as Map<String, dynamic>;
      for (final field in sumFields.keys) {
        if (sumFields[field] == true) {
          functions.add('SUM(${_quoteIdentifier(field)}) AS "_sum_$field"');
        }
      }
    }

    // _min
    if (agg['_min'] is Map) {
      final minFields = agg['_min'] as Map<String, dynamic>;
      for (final field in minFields.keys) {
        if (minFields[field] == true) {
          functions.add('MIN(${_quoteIdentifier(field)}) AS "_min_$field"');
        }
      }
    }

    // _max
    if (agg['_max'] is Map) {
      final maxFields = agg['_max'] as Map<String, dynamic>;
      for (final field in maxFields.keys) {
        if (maxFields[field] == true) {
          functions.add('MAX(${_quoteIdentifier(field)}) AS "_max_$field"');
        }
      }
    }

    // Default to COUNT(*) if no aggregations specified
    if (functions.isEmpty) {
      functions.add('COUNT(*) AS "_count"');
    }

    // Combine filter values with where values
    final allArgs = [...whereArgs, ...filterValues];
    final allTypes = [...whereTypes, ...filterTypes];

    final sql =
        'SELECT ${functions.join(', ')} FROM ${_quoteIdentifier(tableName)}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    return SqlQuery(
      sql: sql,
      args: allArgs,
      argTypes: allTypes,
    );
  }

  /// Build a simple filter condition for FILTER clause.
  ///
  /// Returns the condition string and adds values/types to the provided lists.
  String _buildSimpleFilterCondition(
    Map<String, dynamic> filter,
    int startParamIndex,
    List<dynamic> values,
    List<ArgType> types,
  ) {
    final conditions = <String>[];
    var paramIndex = startParamIndex;

    for (final entry in filter.entries) {
      final field = entry.key;
      final value = entry.value;
      conditions.add('${_quoteIdentifier(field)} = ${_placeholder(paramIndex++)}');
      values.add(value);
      types.add(_inferArgType(value));
    }

    return conditions.join(' AND ');
  }

  /// Check if the database provider supports FILTER clause.
  bool _supportsFilterClause() {
    return provider == 'postgresql' || provider == 'supabase';
  }

  /// Compile a GROUP BY query.
  ///
  /// Example:
  /// ```dart
  /// JsonQueryBuilder()
  ///   .model('Order')
  ///   .action(QueryAction.groupBy)
  ///   .groupBy(['status', 'category'])
  ///   .aggregation({
  ///     '_count': true,
  ///     '_sum': {'amount': true},
  ///   })
  ///   .build();
  /// ```
  SqlQuery _compileGroupByQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;
    final groupByFields = args['by'] as List<dynamic>? ?? [];
    final agg = args['_aggregate'] as Map<String, dynamic>? ?? {};
    // TODO: Add HAVING support in future
    // final having = args['having'] as Map<String, dynamic>?;
    final orderBy = args['orderBy'] as Map<String, dynamic>?;

    final tableName = query.modelName;

    // Build SELECT clause with group by fields and aggregations
    final selectParts = <String>[];

    // Add group by fields to SELECT
    for (final field in groupByFields) {
      selectParts.add(_quoteIdentifier(field.toString()));
    }

    // Add aggregation functions
    if (agg['_count'] == true) {
      selectParts.add('COUNT(*) AS "_count"');
    }
    if (agg['_avg'] is Map) {
      for (final field in (agg['_avg'] as Map).keys) {
        selectParts
            .add('AVG(${_quoteIdentifier(field.toString())}) AS "_avg_$field"');
      }
    }
    if (agg['_sum'] is Map) {
      for (final field in (agg['_sum'] as Map).keys) {
        selectParts
            .add('SUM(${_quoteIdentifier(field.toString())}) AS "_sum_$field"');
      }
    }
    if (agg['_min'] is Map) {
      for (final field in (agg['_min'] as Map).keys) {
        selectParts
            .add('MIN(${_quoteIdentifier(field.toString())}) AS "_min_$field"');
      }
    }
    if (agg['_max'] is Map) {
      for (final field in (agg['_max'] as Map).keys) {
        selectParts
            .add('MAX(${_quoteIdentifier(field.toString())}) AS "_max_$field"');
      }
    }

    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(
      where,
      modelName: query.modelName,
    );

    final sql = StringBuffer(
        'SELECT ${selectParts.join(', ')} FROM ${_quoteIdentifier(tableName)}');

    if (whereClause.isNotEmpty) {
      sql.write(' WHERE $whereClause');
    }

    if (groupByFields.isNotEmpty) {
      sql.write(
          ' GROUP BY ${groupByFields.map((f) => _quoteIdentifier(f.toString())).join(', ')}');
    }

    if (orderBy != null) {
      sql.write(' ORDER BY ${_buildOrderByClause(orderBy)}');
    }

    return SqlQuery(
      sql: sql.toString(),
      args: whereArgs,
      argTypes: whereTypes,
    );
  }

  /// Compile an UPSERT query.
  ///
  /// Generates INSERT ... ON CONFLICT DO UPDATE for PostgreSQL/Supabase.
  /// Example:
  /// ```dart
  /// JsonQueryBuilder()
  ///   .model('User')
  ///   .action(QueryAction.upsert)
  ///   .where({'email': 'user@example.com'})
  ///   .data({
  ///     'create': {'email': 'user@example.com', 'name': 'New User'},
  ///     'update': {'name': 'Updated User'},
  ///   })
  ///   .build();
  /// ```
  SqlQuery _compileUpsertQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>? ?? {};
    final data = args['data'] as Map<String, dynamic>? ?? {};
    final createData = data['create'] as Map<String, dynamic>? ?? {};
    final updateData = data['update'] as Map<String, dynamic>? ?? {};

    final tableName = query.modelName;

    // Get the conflict key(s) from the where clause
    final conflictKeys = where.keys.toList();
    if (conflictKeys.isEmpty) {
      throw ArgumentError(
          'Upsert requires at least one unique field in where clause');
    }

    // Build INSERT columns and values
    final columns = <String>[];
    final valuePlaceholders = <String>[];
    final values = <dynamic>[];
    final types = <ArgType>[];
    var paramIndex = 1;

    for (final entry in createData.entries) {
      columns.add(_quoteIdentifier(entry.key));
      valuePlaceholders.add(_placeholder(paramIndex++));
      values.add(entry.value);
      types.add(_inferArgType(entry.value));
    }

    // Build UPDATE SET clause
    final updateSetClauses = <String>[];
    for (final entry in updateData.entries) {
      updateSetClauses.add(
        '${_quoteIdentifier(entry.key)} = ${_placeholder(paramIndex++)}',
      );
      values.add(entry.value);
      types.add(_inferArgType(entry.value));
    }

    // Generate SQL based on provider
    String sql;
    if (provider == 'postgresql' || provider == 'supabase') {
      // PostgreSQL: INSERT ... ON CONFLICT DO UPDATE
      sql = '''
INSERT INTO ${_quoteIdentifier(tableName)} (${columns.join(', ')})
VALUES (${valuePlaceholders.join(', ')})
ON CONFLICT (${conflictKeys.map(_quoteIdentifier).join(', ')})
DO UPDATE SET ${updateSetClauses.join(', ')}
RETURNING *
'''
          .trim();
    } else if (provider == 'mysql') {
      // MySQL: INSERT ... ON DUPLICATE KEY UPDATE
      sql = '''
INSERT INTO ${_quoteIdentifier(tableName)} (${columns.join(', ')})
VALUES (${valuePlaceholders.join(', ')})
ON DUPLICATE KEY UPDATE ${updateSetClauses.join(', ')}
'''
          .trim();
    } else if (provider == 'sqlite') {
      // SQLite: INSERT ... ON CONFLICT DO UPDATE (since SQLite 3.24.0)
      // RETURNING * requires SQLite 3.35.0+ (2021-03-12)
      sql = '''
INSERT INTO ${_quoteIdentifier(tableName)} (${columns.join(', ')})
VALUES (${valuePlaceholders.join(', ')})
ON CONFLICT (${conflictKeys.map(_quoteIdentifier).join(', ')})
DO UPDATE SET ${updateSetClauses.join(', ')}
RETURNING *
'''
          .trim();
    } else {
      throw UnsupportedError('Upsert not supported for provider: $provider');
    }

    return SqlQuery(
      sql: sql,
      args: values,
      argTypes: types,
    );
  }

  /// Build SELECT fields from selection.
  List<String> _buildSelectFields(JsonSelection? selection) {
    if (selection == null ||
        selection.scalars == true && selection.fields == null) {
      return []; // SELECT *
    }

    final fields = <String>[];

    if (selection.fields != null) {
      for (final fieldName in selection.fields!.keys) {
        // Use field name as-is (don't convert to snake_case)
        fields.add(_quoteIdentifier(fieldName));
      }
    }

    return fields;
  }

  /// Build SELECT clause from a list of field names (v0.2.5+).
  ///
  /// This handles the new selectFields(['id', 'name']) syntax.
  String _buildSelectFieldsFromList(List<String> fields) {
    if (fields.isEmpty) return '*';

    final columns = <String>[];
    for (final field in fields) {
      // Check for dot notation (relation.field)
      if (field.contains('.')) {
        // For simple queries without include, dot notation is not supported
        // The field would just be quoted as-is which would likely fail
        // This is handled properly by _buildSelectFieldsWithRelations
        columns.add(_quoteIdentifier(field.replaceAll('.', '_')));
      } else {
        columns.add(_quoteIdentifier(field));
      }
    }

    return columns.join(', ');
  }

  /// Build SELECT clause from selectFields with relation support (v0.2.5+).
  ///
  /// Handles dot notation for related fields:
  /// - 'id' -> "t0"."id"
  /// - 'category.name' -> "t1"."name" AS "category_name"
  ///
  /// Also appends all relation columns from the include() directive.
  String _buildSelectFieldsWithRelations(
    List<String> fields,
    String baseAlias,
    CompiledRelations relations,
  ) {
    if (fields.isEmpty) return '*';

    final columns = <String>[];

    for (final field in fields) {
      if (field.contains('.')) {
        // Relation field: category.name -> "t1"."name" AS "category_name"
        final parts = field.split('.');
        if (parts.length == 2) {
          final relationName = parts[0];
          final relationField = parts[1];

          // Find the alias for this relation from columnAliases
          String? relationAlias;
          for (final entry in relations.columnAliases.entries) {
            final columnAlias = entry.value;
            // Check if this column belongs to the requested relation
            if (columnAlias.relationPath == relationName) {
              relationAlias = columnAlias.tableAlias;
              break;
            }
          }

          if (relationAlias != null) {
            final aliasName = '${relationName}_$relationField';
            columns.add(
                '"$relationAlias".${_quoteIdentifier(relationField)} AS ${_quoteIdentifier(aliasName)}');
          } else {
            // Relation not found in include, use placeholder
            columns.add(
                'NULL AS ${_quoteIdentifier('${relationName}_$relationField')}');
          }
        } else {
          // Nested relation (e.g., user.profile.bio) - not yet supported
          columns.add('NULL AS ${_quoteIdentifier(field.replaceAll('.', '_'))}');
        }
      } else {
        // Base model field: id -> "t0"."id"
        columns.add('"$baseAlias".${_quoteIdentifier(field)}');
      }
    }

    // Collect which relation columns are explicitly requested via dot notation
    final explicitRelationColumns = <String>{};
    for (final field in fields) {
      if (field.contains('.')) {
        final parts = field.split('.');
        if (parts.length == 2) {
          // e.g., 'user.name' -> 'user_name' (the alias format)
          explicitRelationColumns.add('${parts[0]}_${parts[1]}');
        }
      }
    }
    final hasExplicitRelationFields = explicitRelationColumns.isNotEmpty;

    // Append relation columns from include() directive
    // If selectFields has dot notation, only add explicitly requested columns
    // Otherwise, add all relation columns (original behavior)
    for (final entry in relations.columnAliases.entries) {
      final aliasKey = entry.key;
      final info = entry.value;

      // Only add columns that belong to relations (have a relationPath)
      if (info.relationPath != null) {
        if (hasExplicitRelationFields) {
          // Only add columns that were explicitly requested
          if (explicitRelationColumns.contains(aliasKey)) {
            columns.add(
              '"${info.tableAlias}".${_quoteIdentifier(info.columnName)} AS ${_quoteIdentifier(aliasKey)}',
            );
          }
        } else {
          // No dot notation in selectFields -> add all relation columns
          columns.add(
            '"${info.tableAlias}".${_quoteIdentifier(info.columnName)} AS ${_quoteIdentifier(aliasKey)}',
          );
        }
      }
    }

    return columns.join(', ');
  }

  /// Build SELECT clause with table alias prefix (v0.2.6+).
  ///
  /// Simple version for when we need an alias but don't have relations.
  /// Used primarily with computed fields.
  ///
  /// Example:
  /// - 'id', 'name' -> "t0"."id", "t0"."name"
  String _buildSelectFieldsWithAlias(
    List<String> fields,
    String alias,
  ) {
    if (fields.isEmpty) return '"$alias".*';

    return fields.map((field) => '"$alias".${_quoteIdentifier(field)}').join(', ');
  }

  /// Build computed fields clauses for correlated subqueries (v0.2.6+).
  ///
  /// Generates SQL like:
  /// ```sql
  /// (SELECT MIN("price") FROM "ConsultationPlan" WHERE "consultantProfileId" = "t0"."id") AS "minPrice"
  /// ```
  ///
  /// [computedFields] is a map from alias name to computed field definition.
  /// [baseAlias] is the alias of the parent table (e.g., "t0").
  ///
  /// Returns a tuple of (sql, args, argTypes) where args contains any parameterized values.
  (String, List<dynamic>, List<ArgType>) _buildComputedFieldsClauses(
    Map<String, dynamic> computedFields,
    String baseAlias,
  ) {
    final clauses = <String>[];
    final allArgs = <dynamic>[];
    final allTypes = <ArgType>[];

    for (final entry in computedFields.entries) {
      final aliasName = entry.key;
      final fieldDef = entry.value as Map<String, dynamic>;

      final result = _buildSingleComputedFieldClause(
        fieldDef,
        baseAlias,
        aliasName,
        allArgs.length + 1, // Starting param index (1-based)
        allArgs,
        allTypes,
      );
      if (result != null) {
        clauses.add(result);
      }
    }

    return (clauses.join(', '), allArgs, allTypes);
  }

  /// Build a single computed field subquery clause.
  ///
  /// Returns null if the field definition is invalid.
  /// Adds any parameterized values to [args] and [argTypes].
  String? _buildSingleComputedFieldClause(
    Map<String, dynamic> fieldDef,
    String baseAlias,
    String aliasName,
    int startParamIndex,
    List<dynamic> args,
    List<ArgType> argTypes,
  ) {
    final type = fieldDef['_type'];
    if (type != 'computedField') return null;

    final field = fieldDef['field'] as String?;
    final operation = fieldDef['operation'] as String?;
    final from = fieldDef['from'] as String?;
    final where = fieldDef['where'] as Map<String, dynamic>?;
    final orderBy = fieldDef['orderBy'] as Map<String, dynamic>?;

    if (field == null || operation == null || from == null) return null;

    // Build the SELECT expression based on operation
    final selectExpr = switch (operation) {
      'min' => 'MIN(${_quoteIdentifier(field)})',
      'max' => 'MAX(${_quoteIdentifier(field)})',
      'avg' => 'AVG(${_quoteIdentifier(field)})',
      'sum' => 'SUM(${_quoteIdentifier(field)})',
      'count' => field == '*' ? 'COUNT(*)' : 'COUNT(${_quoteIdentifier(field)})',
      'first' => _quoteIdentifier(field),
      _ => null,
    };

    if (selectExpr == null) return null;

    // Build the subquery
    final sql = StringBuffer();
    sql.write('(SELECT $selectExpr FROM ${_quoteIdentifier(from)}');

    // Build WHERE clause with field references (parameterized)
    if (where != null && where.isNotEmpty) {
      final whereConditions = _buildComputedFieldWhere(
        where,
        baseAlias,
        startParamIndex,
        args,
        argTypes,
      );
      if (whereConditions.isNotEmpty) {
        sql.write(' WHERE $whereConditions');
      }
    }

    // Add ORDER BY for 'first' operation
    if (operation == 'first' && orderBy != null && orderBy.isNotEmpty) {
      final orderClauses = orderBy.entries
          .map((e) => '${_quoteIdentifier(e.key)} ${e.value.toUpperCase()}')
          .join(', ');
      sql.write(' ORDER BY $orderClauses LIMIT 1');
    }

    sql.write(') AS ${_quoteIdentifier(aliasName)}');

    return sql.toString();
  }

  /// Build WHERE clause for computed field subquery, resolving field references.
  ///
  /// Handles FieldRef objects that reference parent table columns.
  /// Uses parameterized queries for safety - values are added to [args] and [argTypes].
  String _buildComputedFieldWhere(
    Map<String, dynamic> where,
    String baseAlias,
    int startParamIndex,
    List<dynamic> args,
    List<ArgType> argTypes,
  ) {
    final conditions = <String>[];

    for (final entry in where.entries) {
      final field = entry.key;
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        // Check if this is a FieldRef
        if (value['_type'] == 'fieldRef') {
          final refField = value['field'] as String;
          conditions.add(
            '${_quoteIdentifier(field)} = "$baseAlias".${_quoteIdentifier(refField)}',
          );
        } else if (value.containsKey('equals')) {
          // Handle equals operator with parameterized values
          final eqValue = value['equals'];
          if (eqValue == null) {
            conditions.add('${_quoteIdentifier(field)} IS NULL');
          } else {
            args.add(eqValue);
            argTypes.add(_inferArgType(eqValue));
            final paramIndex = startParamIndex + args.length - 1;
            conditions.add('${_quoteIdentifier(field)} = \$$paramIndex');
          }
        }
        // For other operators in computed field WHERE, skip for now
        // (computed fields typically just need FK equality)
      } else {
        // Simple equality with parameterized values
        if (value == null) {
          conditions.add('${_quoteIdentifier(field)} IS NULL');
        } else {
          args.add(value);
          argTypes.add(_inferArgType(value));
          final paramIndex = startParamIndex + args.length - 1;
          conditions.add('${_quoteIdentifier(field)} = \$$paramIndex');
        }
      }
    }

    return conditions.join(' AND ');
  }

  /// Detect if a value contains a relation filter operator.
  ///
  /// Returns 'some', 'every', or 'none' if found, null otherwise.
  String? _detectRelationOperator(Map<String, dynamic> value) {
    if (value.containsKey('some')) return 'some';
    if (value.containsKey('every')) return 'every';
    if (value.containsKey('none')) return 'none';
    return null;
  }

  /// Build WHERE clause from conditions.
  ///
  /// [modelName] is optional but required for relation filtering.
  /// [parentAlias] is the table alias for the parent in EXISTS subqueries.
  /// [baseAlias] is the table alias for the base table (e.g., 't0') to
  ///   disambiguate column names when JOINs are present.
  (String, List<dynamic>, List<ArgType>) _buildWhereClause(
    Map<String, dynamic>? where, {
    int startIndex = 1,
    String? modelName,
    String parentAlias = '',
    String? baseAlias,
  }) {
    if (where == null || where.isEmpty) {
      return ('', [], []);
    }

    final conditions = <String>[];
    final values = <dynamic>[];
    final types = <ArgType>[];
    var paramIndex = startIndex;

    for (final entry in where.entries) {
      final field = entry.key;
      final value = entry.value;

      // Handle logical operators
      if (field == 'AND') {
        final subConditions = <String>[];
        for (final condition in value as List) {
          final (clause, vals, typs) = _buildWhereClause(
            condition as Map<String, dynamic>,
            startIndex: paramIndex,
            modelName: modelName,
            parentAlias: parentAlias,
            baseAlias: baseAlias,
          );
          subConditions.add('($clause)');
          values.addAll(vals);
          types.addAll(typs);
          paramIndex += vals.length;
        }
        conditions.add('(${subConditions.join(' AND ')})');
        continue;
      }

      if (field == 'OR') {
        final subConditions = <String>[];
        for (final condition in value as List) {
          final (clause, vals, typs) = _buildWhereClause(
            condition as Map<String, dynamic>,
            startIndex: paramIndex,
            modelName: modelName,
            parentAlias: parentAlias,
            baseAlias: baseAlias,
          );
          subConditions.add('($clause)');
          values.addAll(vals);
          types.addAll(typs);
          paramIndex += vals.length;
        }
        conditions.add('(${subConditions.join(' OR ')})');
        continue;
      }

      if (field == 'NOT') {
        final (clause, vals, typs) = _buildWhereClause(
          value as Map<String, dynamic>,
          startIndex: paramIndex,
          modelName: modelName,
          parentAlias: parentAlias,
          baseAlias: baseAlias,
        );
        conditions.add('NOT ($clause)');
        values.addAll(vals);
        types.addAll(typs);
        paramIndex += vals.length;
        continue;
      }

      // Check if field is a relation with a filter operator (some/every/none)
      if (modelName != null && value is Map<String, dynamic>) {
        final effectiveSchema = schema ?? schemaRegistry;
        final relation = effectiveSchema.getRelation(modelName, field);
        final relOperator = _detectRelationOperator(value);

        if (relation != null && relOperator != null) {
          final whereCondition = value[relOperator];
          final (clause, vals, typs) = _buildRelationFilterClause(
            parentModel: modelName,
            parentAlias: parentAlias,
            relationName: field,
            relation: relation,
            operator: relOperator,
            whereCondition:
                whereCondition is Map<String, dynamic> ? whereCondition : {},
            startIndex: paramIndex,
          );
          conditions.add(clause);
          values.addAll(vals);
          types.addAll(typs);
          paramIndex += vals.length;
          continue;
        }
      }

      // Handle field conditions
      // Use field name as-is (don't convert to snake_case)
      // Prefix with table alias if baseAlias is provided (for disambiguating JOINs)
      final columnName = baseAlias != null
          ? '"$baseAlias".${_quoteIdentifier(field)}'
          : _quoteIdentifier(field);

      if (value is Map<String, dynamic>) {
        // Filter operators
        for (final op in value.entries) {
          switch (op.key) {
            case 'equals':
              conditions.add('$columnName = ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'not':
              conditions.add('$columnName != ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'in':
              final list = op.value as List;
              final placeholders =
                  List.generate(list.length, (_) => _placeholder(paramIndex++));
              conditions.add('$columnName IN (${placeholders.join(', ')})');
              values.addAll(list);
              types.addAll(list.map(_inferArgType));
              break;
            case 'notIn':
              final list = op.value as List;
              final placeholders =
                  List.generate(list.length, (_) => _placeholder(paramIndex++));
              conditions.add('$columnName NOT IN (${placeholders.join(', ')})');
              values.addAll(list);
              types.addAll(list.map(_inferArgType));
              break;
            case 'lt':
              conditions.add('$columnName < ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'lte':
              conditions.add('$columnName <= ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'gt':
              conditions.add('$columnName > ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'gte':
              conditions.add('$columnName >= ${_placeholder(paramIndex++)}');
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            case 'contains':
              // Support mode: 'insensitive' for case-insensitive search
              final containsInsensitive =
                  op.value is Map && op.value['mode'] == 'insensitive';
              final containsValue =
                  op.value is Map ? op.value['value'] : op.value;
              final containsOp = containsInsensitive &&
                      (provider == 'postgresql' || provider == 'supabase')
                  ? 'ILIKE'
                  : 'LIKE';
              conditions
                  .add('$columnName $containsOp ${_placeholder(paramIndex++)}');
              values.add('%$containsValue%');
              types.add(ArgType.string);
              break;
            case 'startsWith':
              // Support mode: 'insensitive' for case-insensitive search
              final startsWithInsensitive =
                  op.value is Map && op.value['mode'] == 'insensitive';
              final startsWithValue =
                  op.value is Map ? op.value['value'] : op.value;
              final startsWithOp = startsWithInsensitive &&
                      (provider == 'postgresql' || provider == 'supabase')
                  ? 'ILIKE'
                  : 'LIKE';
              conditions.add(
                  '$columnName $startsWithOp ${_placeholder(paramIndex++)}');
              values.add('$startsWithValue%');
              types.add(ArgType.string);
              break;
            case 'endsWith':
              // Support mode: 'insensitive' for case-insensitive search
              final endsWithInsensitive =
                  op.value is Map && op.value['mode'] == 'insensitive';
              final endsWithValue =
                  op.value is Map ? op.value['value'] : op.value;
              final endsWithOp = endsWithInsensitive &&
                      (provider == 'postgresql' || provider == 'supabase')
                  ? 'ILIKE'
                  : 'LIKE';
              conditions
                  .add('$columnName $endsWithOp ${_placeholder(paramIndex++)}');
              values.add('%$endsWithValue');
              types.add(ArgType.string);
              break;
          }
        }
      } else {
        // Direct equality
        conditions.add('$columnName = ${_placeholder(paramIndex++)}');
        values.add(value);
        types.add(_inferArgType(value));
      }
    }

    return (conditions.join(' AND '), values, types);
  }

  /// Build relation filter clause (EXISTS subquery).
  ///
  /// Generates EXISTS/NOT EXISTS subqueries for relation filter operators
  /// (some, every, none).
  (String, List<dynamic>, List<ArgType>) _buildRelationFilterClause({
    required String parentModel,
    required String parentAlias,
    required String relationName,
    required RelationInfo relation,
    required String operator,
    required Map<String, dynamic> whereCondition,
    required int startIndex,
  }) {
    final values = <dynamic>[];
    final types = <ArgType>[];
    var paramIndex = startIndex;

    // Get target model info
    final effectiveSchema = schema ?? schemaRegistry;
    final targetModelSchema = effectiveSchema.getModel(relation.targetModel);
    final targetTable = _quoteIdentifier(
      targetModelSchema?.tableName ?? relation.targetModel,
    );

    // Determine parent table reference
    final parentModelSchema = effectiveSchema.getModel(parentModel);
    final parentTable = _quoteIdentifier(
      parentModelSchema?.tableName ?? parentModel,
    );
    final parentRef = parentAlias.isNotEmpty ? parentAlias : parentTable;

    // Build subquery WHERE clause for the target model
    final (subWhere, subVals, subTypes) = _buildWhereClause(
      whereCondition,
      startIndex: paramIndex,
      modelName: relation.targetModel,
      parentAlias: 'sub_$relationName',
    );
    values.addAll(subVals);
    types.addAll(subTypes);
    paramIndex += subVals.length;

    // Build the EXISTS clause based on relation type
    String existsClause;

    switch (relation.type) {
      case RelationType.oneToMany:
        // Parent has many targets. FK is on target table.
        // EXISTS (SELECT 1 FROM Target WHERE Target.fk = Parent.id AND ...)
        existsClause = _buildOneToManyExistsClause(
          operator: operator,
          targetTable: targetTable,
          targetFk: relation.foreignKey,
          parentRef: parentRef,
          parentPk: relation.references.first,
          subWhere: subWhere,
        );

      case RelationType.manyToOne:
        // Parent belongs to target. FK is on parent table.
        // EXISTS (SELECT 1 FROM Target WHERE Target.id = Parent.fk AND ...)
        existsClause = _buildManyToOneExistsClause(
          operator: operator,
          targetTable: targetTable,
          targetPk: relation.references.first,
          parentRef: parentRef,
          parentFk: relation.foreignKey,
          subWhere: subWhere,
        );

      case RelationType.oneToOne:
        // Similar to manyToOne depending on which side owns the FK
        if (relation.isOwner) {
          // This side owns FK -> same as manyToOne
          existsClause = _buildManyToOneExistsClause(
            operator: operator,
            targetTable: targetTable,
            targetPk: relation.references.first,
            parentRef: parentRef,
            parentFk: relation.foreignKey,
            subWhere: subWhere,
          );
        } else {
          // Other side owns FK -> same as oneToMany
          existsClause = _buildOneToManyExistsClause(
            operator: operator,
            targetTable: targetTable,
            targetFk: relation.foreignKey,
            parentRef: parentRef,
            parentPk: relation.references.first,
            subWhere: subWhere,
          );
        }

      case RelationType.manyToMany:
        // Uses a join table.
        // EXISTS (SELECT 1 FROM JoinTable JOIN Target ON ... WHERE ...)
        existsClause = _buildManyToManyExistsClause(
          operator: operator,
          targetTable: targetTable,
          joinTable: _quoteIdentifier(relation.joinTable ?? ''),
          joinColumn: _quoteIdentifier(relation.joinColumn ?? 'A'),
          inverseJoinColumn: _quoteIdentifier(relation.inverseJoinColumn ?? 'B'),
          parentRef: parentRef,
          parentPk: relation.references.first,
          subWhere: subWhere,
        );
    }

    return (existsClause, values, types);
  }

  /// Build EXISTS clause for one-to-many relations.
  String _buildOneToManyExistsClause({
    required String operator,
    required String targetTable,
    required String targetFk,
    required String parentRef,
    required String parentPk,
    required String subWhere,
  }) {
    final fkCol = _quoteIdentifier(targetFk);
    final pkCol = _quoteIdentifier(parentPk);

    final joinCondition = '$targetTable.$fkCol = $parentRef.$pkCol';
    final fullCondition =
        subWhere.isNotEmpty ? '$joinCondition AND $subWhere' : joinCondition;

    return switch (operator) {
      'some' => 'EXISTS (SELECT 1 FROM $targetTable WHERE $fullCondition)',
      'every' => subWhere.isNotEmpty
          ? 'NOT EXISTS (SELECT 1 FROM $targetTable WHERE $joinCondition AND NOT ($subWhere))'
          : 'TRUE', // every with no condition is always true
      'none' => 'NOT EXISTS (SELECT 1 FROM $targetTable WHERE $fullCondition)',
      _ => throw ArgumentError('Unknown relation operator: $operator'),
    };
  }

  /// Build EXISTS clause for many-to-one relations.
  String _buildManyToOneExistsClause({
    required String operator,
    required String targetTable,
    required String targetPk,
    required String parentRef,
    required String parentFk,
    required String subWhere,
  }) {
    final pkCol = _quoteIdentifier(targetPk);
    final fkCol = _quoteIdentifier(parentFk);

    final joinCondition = '$targetTable.$pkCol = $parentRef.$fkCol';
    final fullCondition =
        subWhere.isNotEmpty ? '$joinCondition AND $subWhere' : joinCondition;

    return switch (operator) {
      'some' => 'EXISTS (SELECT 1 FROM $targetTable WHERE $fullCondition)',
      'every' => subWhere.isNotEmpty
          ? 'NOT EXISTS (SELECT 1 FROM $targetTable WHERE $joinCondition AND NOT ($subWhere))'
          : 'TRUE',
      'none' => 'NOT EXISTS (SELECT 1 FROM $targetTable WHERE $fullCondition)',
      _ => throw ArgumentError('Unknown relation operator: $operator'),
    };
  }

  /// Build EXISTS clause for many-to-many relations (via junction table).
  String _buildManyToManyExistsClause({
    required String operator,
    required String targetTable,
    required String joinTable,
    required String joinColumn,
    required String inverseJoinColumn,
    required String parentRef,
    required String parentPk,
    required String subWhere,
  }) {
    final pkCol = _quoteIdentifier(parentPk);

    // Subquery joins through junction table to target table
    final joinClause = '''
SELECT 1 FROM $joinTable
INNER JOIN $targetTable ON $targetTable."id" = $joinTable.$inverseJoinColumn
WHERE $joinTable.$joinColumn = $parentRef.$pkCol''';

    final fullCondition =
        subWhere.isNotEmpty ? '$joinClause AND $subWhere' : joinClause;

    return switch (operator) {
      'some' => 'EXISTS ($fullCondition)',
      'every' => subWhere.isNotEmpty
          ? 'NOT EXISTS ($joinClause AND NOT ($subWhere))'
          : 'TRUE',
      'none' => 'NOT EXISTS ($fullCondition)',
      _ => throw ArgumentError('Unknown relation operator: $operator'),
    };
  }

  /// Build ORDER BY clause.
  ///
  /// Supports both simple and extended syntax:
  /// - Simple: `{'field': 'desc'}` or `{'field': 'asc'}`
  /// - Extended: `{'field': {'sort': 'desc', 'nulls': 'last'}}`
  ///
  /// The `nulls` option is only supported on PostgreSQL/Supabase.
  /// On other databases, it is silently ignored.
  ///
  /// [baseAlias] - If provided, column names are prefixed with this alias
  ///   to disambiguate when JOINs are present.
  String _buildOrderByClause(Map<String, dynamic>? orderBy, {String? baseAlias}) {
    if (orderBy == null || orderBy.isEmpty) return '';

    final clauses = <String>[];

    for (final entry in orderBy.entries) {
      // Use field name as-is (don't convert to snake_case)
      // Prefix with table alias if baseAlias is provided
      final field = baseAlias != null
          ? '"$baseAlias".${_quoteIdentifier(entry.key)}'
          : _quoteIdentifier(entry.key);

      String direction;
      String? nullsPosition;

      if (entry.value is Map) {
        // Extended syntax: {sort: 'desc', nulls: 'last'}
        final options = entry.value as Map<String, dynamic>;
        direction = options['sort'] == 'desc' ? 'DESC' : 'ASC';
        nullsPosition = options['nulls'] as String?; // 'first' or 'last'
      } else {
        // Simple syntax: 'desc' or 'asc'
        direction = entry.value == 'desc' ? 'DESC' : 'ASC';
      }

      var clause = '$field $direction';

      // Add NULLS positioning if specified and supported
      if (nullsPosition != null && _supportsNullsOrdering()) {
        clause += ' NULLS ${nullsPosition.toUpperCase()}';
      }

      clauses.add(clause);
    }

    return clauses.join(', ');
  }

  /// Check if the database provider supports NULLS FIRST/LAST ordering.
  bool _supportsNullsOrdering() {
    return provider == 'postgresql' || provider == 'supabase';
  }

  /// Get placeholder syntax for the database provider.
  String _placeholder(int index) {
    switch (provider) {
      case 'postgresql':
      case 'supabase':
        return '\$$index';
      case 'sqlite':
      case 'mysql':
        return '?';
      default:
        return '?';
    }
  }

  /// Quote identifier (table/column name).
  String _quoteIdentifier(String name) {
    switch (provider) {
      case 'postgresql':
      case 'supabase':
        return '"$name"';
      case 'mysql':
        return '`$name`';
      case 'sqlite':
        return '"$name"';
      default:
        return '"$name"';
    }
  }

  /// Infer argument type from value.
  ArgType _inferArgType(dynamic value) {
    if (value == null) return ArgType.unknown;
    if (value is int) return ArgType.int64;
    if (value is double) return ArgType.double;
    if (value is bool) return ArgType.boolean;
    if (value is String) {
      // Try to detect special types
      if (_isIso8601DateTime(value)) return ArgType.dateTime;
      return ArgType.string;
    }
    if (value is DateTime) return ArgType.dateTime;
    if (value is List<int>) return ArgType.bytes;
    return ArgType.unknown;
  }

  /// Check if string is ISO 8601 DateTime.
  ///
  /// Uses a strict pattern check before attempting to parse, since
  /// Dart's DateTime.parse is too lenient and accepts plain numbers.
  bool _isIso8601DateTime(String value) {
    // ISO 8601 patterns: YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS, etc.
    // Must contain dashes or "T" to be a date/datetime, not just a number.
    // Valid examples: "2025-01-15", "2025-01-15T10:30:00", "2025-01-15T10:30:00.000Z"
    // Invalid examples: "1234567890" (phone), "987654321" (number)

    // Quick check: must contain a dash to be a date
    if (!value.contains('-')) return false;

    // Must start with 4 digits (year) followed by a dash
    final yearPattern = RegExp(r'^\d{4}-');
    if (!yearPattern.hasMatch(value)) return false;

    try {
      final parsed = DateTime.parse(value);
      // Sanity check: year should be reasonable (1000-9999)
      if (parsed.year < 1000 || parsed.year > 9999) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}
