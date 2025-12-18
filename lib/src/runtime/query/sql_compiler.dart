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
  RelationCompiler get relationCompiler =>
      _relationCompiler ??= RelationCompiler(
        schema: schema ?? schemaRegistry,
        provider: provider,
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

    // Check for include directive (relations)
    final include = _extractInclude(query.args.selection);
    final hasRelations = include != null && include.isNotEmpty;

    // Build SELECT clause and JOIN clauses if relations are included
    String selectClause;
    String joinClauses = '';
    CompiledRelations? compiledRelations;

    if (hasRelations &&
        (schema != null || schemaRegistry.hasModel(query.modelName))) {
      // Use relation compiler for JOINs
      const baseAlias = 't0';
      compiledRelations = relationCompiler.compile(
        baseModel: query.modelName,
        baseAlias: baseAlias,
        include: include,
      );

      if (compiledRelations.isNotEmpty) {
        selectClause = relationCompiler.generateSelectColumns(
          compiledRelations.columnAliases,
        );
        joinClauses = compiledRelations.joinClauses;
      } else {
        // Fall back to simple select
        final selectFields = _buildSelectFields(query.args.selection);
        selectClause = selectFields.isEmpty ? '*' : selectFields.join(', ');
      }
    } else {
      // Simple select without relations
      final selectFields = _buildSelectFields(query.args.selection);
      selectClause = selectFields.isEmpty ? '*' : selectFields.join(', ');
    }

    // Build WHERE clause
    final where = args['where'] as Map<String, dynamic>?;
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

    // Build ORDER BY clause
    final orderBy = args['orderBy'] as Map<String, dynamic>?;
    final orderByClause = _buildOrderByClause(orderBy);

    // Build LIMIT/OFFSET
    final take = args['take'] as int?;
    final skip = args['skip'] as int?;

    // Construct SQL with optional table alias
    final sql = StringBuffer();
    if (hasRelations &&
        compiledRelations != null &&
        compiledRelations.isNotEmpty) {
      sql.write(
          'SELECT $selectClause FROM ${_quoteIdentifier(tableName)} "t0"');
      sql.write(' $joinClauses');
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

    return SqlQuery(
      sql: sql.toString(),
      args: whereArgs,
      argTypes: whereTypes,
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
    final dataList = args['data'] as List<dynamic>?;

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
    final (whereClause, whereArgs, whereTypes) =
        _buildWhereClause(where, startIndex: paramIndex);
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
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

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
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

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
  /// Supports: _count, _avg, _sum, _min, _max
  /// Example:
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
  SqlQuery _compileAggregateQuery(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final where = args['where'] as Map<String, dynamic>?;
    final agg = args['_aggregate'] as Map<String, dynamic>? ?? {};

    final tableName = query.modelName;
    final functions = <String>[];

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

    // _avg
    if (agg['_avg'] is Map) {
      final avgFields = agg['_avg'] as Map<String, dynamic>;
      for (final field in avgFields.keys) {
        if (avgFields[field] == true) {
          functions.add('AVG(${_quoteIdentifier(field)}) AS "_avg_$field"');
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

    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

    final sql =
        'SELECT ${functions.join(', ')} FROM ${_quoteIdentifier(tableName)}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    return SqlQuery(
      sql: sql,
      args: whereArgs,
      argTypes: whereTypes,
    );
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

    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

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

  /// Build WHERE clause from conditions.
  (String, List<dynamic>, List<ArgType>) _buildWhereClause(
    Map<String, dynamic>? where, {
    int startIndex = 1,
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
        );
        conditions.add('NOT ($clause)');
        values.addAll(vals);
        types.addAll(typs);
        paramIndex += vals.length;
        continue;
      }

      // Handle field conditions
      // Use field name as-is (don't convert to snake_case)
      final columnName = _quoteIdentifier(field);

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
              conditions.add('$columnName LIKE ${_placeholder(paramIndex++)}');
              values.add('%${op.value}%');
              types.add(ArgType.string);
              break;
            case 'startsWith':
              conditions.add('$columnName LIKE ${_placeholder(paramIndex++)}');
              values.add('${op.value}%');
              types.add(ArgType.string);
              break;
            case 'endsWith':
              conditions.add('$columnName LIKE ${_placeholder(paramIndex++)}');
              values.add('%${op.value}');
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

  /// Build ORDER BY clause.
  String _buildOrderByClause(Map<String, dynamic>? orderBy) {
    if (orderBy == null || orderBy.isEmpty) return '';

    final clauses = <String>[];

    for (final entry in orderBy.entries) {
      // Use field name as-is (don't convert to snake_case)
      final field = _quoteIdentifier(entry.key);
      final direction = entry.value == 'desc' ? 'DESC' : 'ASC';
      clauses.add('$field $direction');
    }

    return clauses.join(', ');
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
