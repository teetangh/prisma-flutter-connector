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

/// Cached regex pattern for ISO 8601 year validation.
final _yearPattern = RegExp(r'^\d{4}-');

/// Compiles JSON queries to SQL.
class SqlCompiler {
  final String provider;
  final String? schemaName;
  final SchemaRegistry? schema;

  /// Enable strict model name validation.
  ///
  /// When enabled, the compiler will throw an [ArgumentError] if a PascalCase
  /// model name (e.g., 'User') is used but not registered in the SchemaRegistry.
  /// This helps catch common mistakes when using JsonQueryBuilder manually
  /// without Prisma code generation.
  ///
  /// Defaults to `false` for backwards compatibility. Set to `true` to enable
  /// helpful error messages for model name mismatches.
  ///
  /// Example:
  /// ```dart
  /// SqlCompiler.strictModelValidation = true; // Enable globally
  ///
  /// // Or per-instance:
  /// final compiler = SqlCompiler(
  ///   provider: 'postgresql',
  ///   strictModelValidation: true,
  /// );
  /// ```
  static bool strictModelValidation = false;

  /// Instance-level override for strict model validation.
  final bool? _strictModelValidation;

  /// Lazily created relation compiler.
  RelationCompiler? _relationCompiler;

  SqlCompiler({
    required this.provider,
    this.schemaName,
    this.schema,
    bool? strictModelValidation,
  }) : _strictModelValidation = strictModelValidation;

  /// Get or create relation compiler.
  /// Uses startingCounter: 1 since t0 is reserved for the base table.
  RelationCompiler get relationCompiler =>
      _relationCompiler ??= RelationCompiler(
        schema: schema ?? schemaRegistry,
        provider: provider,
        startingCounter: 1,
      );

  /// Resolve a model name to its actual database table name.
  ///
  /// Uses SchemaRegistry if available, otherwise returns the model name as-is.
  /// This handles @@map directives transparently.
  ///
  /// Throws [ArgumentError] with a helpful message if the model appears to be
  /// a PascalCase name but isn't registered in the schema (common mistake when
  /// using JsonQueryBuilder manually without code generation).
  String _resolveTableName(String modelName) {
    final effectiveSchema = schema ?? schemaRegistry;
    final tableName = effectiveSchema.getTableName(modelName);

    if (tableName != null) {
      return tableName;
    }

    // Check if this looks like a PascalCase model name that should be registered
    _validateModelName(modelName, effectiveSchema);

    return modelName;
  }

  /// Check if strict model validation is enabled (instance or global).
  bool get _isStrictValidationEnabled =>
      _strictModelValidation ?? strictModelValidation;

  /// Validates that a model name is properly registered or is a valid table name.
  ///
  /// When using JsonQueryBuilder without code generation, users often mistakenly
  /// use PascalCase model names (e.g., 'User') instead of the actual PostgreSQL
  /// table names (e.g., 'users'). This method detects this pattern and provides
  /// a helpful error message.
  ///
  /// This validation only runs when [strictModelValidation] is enabled.
  void _validateModelName(String modelName, SchemaRegistry effectiveSchema) {
    // Skip validation if not in strict mode
    if (!_isStrictValidationEnabled) return;

    // If the schema has any registered models, we expect all models to be registered
    final hasRegisteredModels = effectiveSchema.modelNames.isNotEmpty;

    // Check if this looks like a PascalCase Prisma model name
    final isPascalCase = _isPascalCase(modelName);

    if (isPascalCase) {
      final suggestedTableName = _toSnakeCase(modelName);

      if (hasRegisteredModels) {
        // Schema is populated but this model isn't registered
        throw ArgumentError(
          'Model "$modelName" is not registered in SchemaRegistry.\n'
          'Available models: ${effectiveSchema.modelNames.join(", ")}.\n\n'
          'Did you mean to use one of the registered models, or did you forget '
          'to register "$modelName"?',
        );
      } else {
        // Schema is empty - likely using JsonQueryBuilder without code generation
        throw ArgumentError(
          'Model "$modelName" not found in SchemaRegistry (registry is empty).\n\n'
          'When using JsonQueryBuilder without Prisma code generation, you must use '
          'the actual PostgreSQL table name instead of the Prisma model name.\n\n'
          'Try: .model(\'$suggestedTableName\') instead of .model(\'$modelName\')\n\n'
          'Alternatively, run "dart run prisma_flutter_connector:generate" to '
          'populate the SchemaRegistry with model-to-table mappings.',
        );
      }
    }
  }

  /// Check if a string is PascalCase (starts with uppercase, contains lowercase).
  bool _isPascalCase(String s) {
    if (s.isEmpty) return false;
    // Starts with uppercase and contains at least one lowercase letter
    return s[0] == s[0].toUpperCase() &&
        s[0] != s[0].toLowerCase() &&
        s.contains(RegExp(r'[a-z]'));
  }

  /// Convert PascalCase to snake_case.
  ///
  /// Handles acronyms correctly:
  /// - "User" -> "user"
  /// - "URLShortener" -> "url_shortener"
  /// - "HTTPSConnection" -> "https_connection"
  String _toSnakeCase(String input) {
    return input
        // Handle acronyms followed by a word: "URLShortener" -> "URL_Shortener"
        .replaceAllMapped(
            RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]}_${m[2]}')
        // Handle lowercase followed by uppercase: "myURL" -> "my_URL"
        .replaceAllMapped(RegExp(r'([a-z\d])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
  }

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
    final tableName = _resolveTableName(query.modelName);

    // Check for selectFields (v0.2.5+)
    final selectFieldsList = args['selectFields'] as List<dynamic>?;
    final hasSelectFields =
        selectFieldsList != null && selectFieldsList.isNotEmpty;

    // Check for computed fields (v0.2.6+)
    final computedFields = args['_computed'] as Map<String, dynamic>?;
    final hasComputedFields =
        computedFields != null && computedFields.isNotEmpty;

    // Check for DISTINCT (v0.2.9+)
    final distinctArg = args['distinct'] as bool? ?? false;
    final distinctFields = args['distinctFields'] as List<dynamic>?;

    // Check for include directive (relations)
    final include = _extractInclude(query.args.selection);
    final hasRelations = include != null && include.isNotEmpty;

    // Check if WHERE clause contains relationPath filters (v0.2.9+)
    final where = args['where'] as Map<String, dynamic>?;
    final hasRelationPath = _containsRelationPath(where);

    // Determine if we need a table alias (for computed fields, relations,
    // or relationPath filters which generate JOINs requiring base alias)
    final needsAlias = hasComputedFields || hasRelations || hasRelationPath;
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
          selectClause =
              _buildSelectFieldsFromList(selectFieldsList.cast<String>());
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
          selectClause =
              _buildSelectFieldsFromList(selectFieldsList.cast<String>());
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
    // Note: 'where' already extracted above for hasRelationPath check
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
    // Build DISTINCT clause (v0.2.9+)
    String distinctClause = '';
    if (distinctArg) {
      if (distinctFields != null && distinctFields.isNotEmpty) {
        // PostgreSQL-specific: DISTINCT ON (field1, field2, ...)
        if (provider == 'postgresql' || provider == 'supabase') {
          final quotedFields = distinctFields
              .map((f) => _quoteIdentifier(f.toString()))
              .join(', ');
          distinctClause = 'DISTINCT ON ($quotedFields) ';
        } else {
          // MySQL/SQLite: Just use DISTINCT (ignore specific fields)
          distinctClause = 'DISTINCT ';
        }
      } else {
        distinctClause = 'DISTINCT ';
      }
    }

    final sql = StringBuffer();
    if (needsAlias) {
      sql.write(
          'SELECT $distinctClause$selectClause FROM ${_quoteIdentifier(tableName)} "$baseAlias"');
      if (joinClauses.isNotEmpty) {
        sql.write(' $joinClauses');
      }
    } else {
      sql.write(
          'SELECT $distinctClause$selectClause FROM ${_quoteIdentifier(tableName)}');
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

    // Collect computed field names for preservation during relation deserialization
    final computedFieldNamesList =
        hasComputedFields ? computedFields.keys.toList() : <String>[];

    return SqlQuery(
      sql: sql.toString(),
      args: allArgs,
      argTypes: allTypes,
      relationMetadata: compiledRelations,
      computedFieldNames: computedFieldNamesList,
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

    final tableName = _resolveTableName(query.modelName);
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

    final tableName = _resolveTableName(query.modelName);
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

    final tableName = _resolveTableName(query.modelName);

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

    final tableName = _resolveTableName(query.modelName);
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

    final tableName = _resolveTableName(query.modelName);
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

    final tableName = _resolveTableName(query.modelName);
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
      conditions
          .add('${_quoteIdentifier(field)} = ${_placeholder(paramIndex++)}');
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

    final tableName = _resolveTableName(query.modelName);

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

    final tableName = _resolveTableName(query.modelName);

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

  /// Compile a mutation query with potential relation operations.
  ///
  /// This is used when CREATE or UPDATE queries include `connect` or
  /// `disconnect` operations for many-to-many relations.
  ///
  /// Example:
  /// ```dart
  /// final query = JsonQueryBuilder()
  ///     .model('SlotOfAppointment')
  ///     .action(QueryAction.create)
  ///     .data({
  ///       'id': 'slot-123',
  ///       'startsAt': DateTime.now(),
  ///       'users': {
  ///         'connect': [{'id': 'user-1'}, {'id': 'user-2'}],
  ///       },
  ///     })
  ///     .build();
  /// ```
  CompiledMutation compileWithRelations(JsonQuery query) {
    final args = query.args.arguments ?? {};
    final data = args['data'] as Map<String, dynamic>? ?? {};

    // Extract relation operations from data
    final relationMutations = <SqlQuery>[];
    final cleanData = <String, dynamic>{};
    final effectiveSchema = schema ?? schemaRegistry;

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic> &&
          (value.containsKey('connect') || value.containsKey('disconnect'))) {
        // This is a relation operation - look up the relation info
        final relation =
            effectiveSchema.getRelation(query.modelName, entry.key);
        if (relation != null && relation.type == RelationType.manyToMany) {
          // Get primary key field name from schema (fallback to 'id' for compatibility)
          final parentModel = effectiveSchema.getModel(query.modelName);
          final parentPkFieldName = parentModel?.primaryKeys.isNotEmpty == true
              ? parentModel!.primaryKeys.first.name
              : 'id';

          // Get the primary key value for the parent record
          // For create, it's in the data; for update, it's in the where clause
          String? parentId;
          if (query.action == 'create') {
            parentId = data[parentPkFieldName]?.toString();
          } else if (query.action == 'update') {
            final where = args['where'] as Map<String, dynamic>?;
            parentId = where?[parentPkFieldName]?.toString();
          }

          if (parentId != null) {
            // Compile connect operations
            if (value.containsKey('connect')) {
              final connectItems =
                  _normalizeConnectDisconnect(value['connect']);
              relationMutations.addAll(_compileConnectOperations(
                parentId: parentId,
                relation: relation,
                connectItems: connectItems,
                effectiveSchema: effectiveSchema,
              ));
            }

            // Compile disconnect operations
            if (value.containsKey('disconnect')) {
              final disconnectItems =
                  _normalizeConnectDisconnect(value['disconnect']);
              relationMutations.addAll(_compileDisconnectOperations(
                parentId: parentId,
                relation: relation,
                disconnectItems: disconnectItems,
                effectiveSchema: effectiveSchema,
              ));
            }
          }
        } else if (relation != null) {
          // Non-M2M relation with connect/disconnect - not supported
          throw UnsupportedError(
            'connect/disconnect operations are only supported for many-to-many '
            'relations. Field "${entry.key}" is a ${relation.type.name} relation.',
          );
        }
        // If relation is null, the field will be passed through and likely fail
        // downstream with a more specific error about the unknown field
      } else {
        // Regular field - keep in clean data
        cleanData[entry.key] = value;
      }
    }

    // Create modified query with clean data (no relation operations)
    final cleanArgs = Map<String, dynamic>.from(args);
    cleanArgs['data'] = cleanData;
    final cleanQuery = JsonQuery(
      modelName: query.modelName,
      action: query.action,
      args: JsonQueryArgs(arguments: cleanArgs),
    );

    // Compile the main query
    final mainQuery = compile(cleanQuery);

    return CompiledMutation(
      mainQuery: mainQuery,
      relationMutations: relationMutations,
    );
  }

  /// Normalize connect/disconnect input to a list of maps.
  ///
  /// Handles both single item and array formats:
  /// - `{'id': 'user-1'}` -> `[{'id': 'user-1'}]`
  /// - `[{'id': 'user-1'}, {'id': 'user-2'}]` -> as-is
  List<Map<String, dynamic>> _normalizeConnectDisconnect(dynamic input) {
    if (input is List) {
      // Use List.from() for type safety - validates all elements immediately
      // instead of cast<>() which is a lazy view that fails at access time
      return List<Map<String, dynamic>>.from(input);
    } else if (input is Map<String, dynamic>) {
      return [input];
    }
    return [];
  }

  /// Compile M2M connect operations into INSERT statements for junction table.
  ///
  /// For each item to connect, generates:
  /// ```sql
  /// INSERT INTO "_JunctionTable" ("A", "B") VALUES ($1, $2) ON CONFLICT DO NOTHING
  /// ```
  List<SqlQuery> _compileConnectOperations({
    required String parentId,
    required RelationInfo relation,
    required List<Map<String, dynamic>> connectItems,
    required SchemaRegistry effectiveSchema,
  }) {
    final queries = <SqlQuery>[];

    if (relation.joinTable == null ||
        relation.joinColumn == null ||
        relation.inverseJoinColumn == null) {
      return queries; // Invalid M2M relation configuration
    }

    final junctionTable = _quoteIdentifier(relation.joinTable!);
    final joinCol = _quoteIdentifier(relation.joinColumn!);
    final inverseCol = _quoteIdentifier(relation.inverseJoinColumn!);

    // Get target model's primary key field name (fallback to 'id' for compatibility)
    final targetModel = effectiveSchema.getModel(relation.targetModel);
    final targetPkFieldName = targetModel?.primaryKeys.isNotEmpty == true
        ? targetModel!.primaryKeys.first.name
        : 'id';

    for (final item in connectItems) {
      final targetId = item[targetPkFieldName]?.toString();
      if (targetId == null) continue;

      // Generate INSERT with ON CONFLICT DO NOTHING to handle duplicates
      // Use _placeholder() for correct database-specific placeholders
      final valuesClause = 'VALUES (${_placeholder(1)}, ${_placeholder(2)})';

      String sql;
      if (provider == 'postgresql' || provider == 'supabase') {
        sql = 'INSERT INTO $junctionTable ($joinCol, $inverseCol) '
            '$valuesClause ON CONFLICT DO NOTHING';
      } else if (provider == 'mysql') {
        sql = 'INSERT IGNORE INTO $junctionTable ($joinCol, $inverseCol) '
            '$valuesClause';
      } else if (provider == 'sqlite') {
        sql = 'INSERT OR IGNORE INTO $junctionTable ($joinCol, $inverseCol) '
            '$valuesClause';
      } else {
        sql = 'INSERT INTO $junctionTable ($joinCol, $inverseCol) '
            '$valuesClause';
      }

      queries.add(SqlQuery(
        sql: sql,
        args: [parentId, targetId],
        argTypes: [ArgType.string, ArgType.string],
      ));
    }

    return queries;
  }

  /// Compile M2M disconnect operations into DELETE statements for junction table.
  ///
  /// For each item to disconnect, generates:
  /// ```sql
  /// DELETE FROM "_JunctionTable" WHERE "A" = $1 AND "B" = $2
  /// ```
  List<SqlQuery> _compileDisconnectOperations({
    required String parentId,
    required RelationInfo relation,
    required List<Map<String, dynamic>> disconnectItems,
    required SchemaRegistry effectiveSchema,
  }) {
    final queries = <SqlQuery>[];

    if (relation.joinTable == null ||
        relation.joinColumn == null ||
        relation.inverseJoinColumn == null) {
      return queries; // Invalid M2M relation configuration
    }

    final junctionTable = _quoteIdentifier(relation.joinTable!);
    final joinCol = _quoteIdentifier(relation.joinColumn!);
    final inverseCol = _quoteIdentifier(relation.inverseJoinColumn!);

    // Get target model's primary key field name (fallback to 'id' for compatibility)
    final targetModel = effectiveSchema.getModel(relation.targetModel);
    final targetPkFieldName = targetModel?.primaryKeys.isNotEmpty == true
        ? targetModel!.primaryKeys.first.name
        : 'id';

    for (final item in disconnectItems) {
      final targetId = item[targetPkFieldName]?.toString();
      if (targetId == null) continue;

      final sql = 'DELETE FROM $junctionTable '
          'WHERE $joinCol = ${_placeholder(1)} AND $inverseCol = ${_placeholder(2)}';

      queries.add(SqlQuery(
        sql: sql,
        args: [parentId, targetId],
        argTypes: [ArgType.string, ArgType.string],
      ));
    }

    return queries;
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
            final aliasName = '${relationName}__$relationField';
            columns.add(
                '"$relationAlias".${_quoteIdentifier(relationField)} AS ${_quoteIdentifier(aliasName)}');
          } else {
            // Relation not found in include, use placeholder
            columns.add(
                'NULL AS ${_quoteIdentifier('${relationName}__$relationField')}');
          }
        } else {
          // Nested relation (e.g., user.profile.bio) - not yet supported
          columns
              .add('NULL AS ${_quoteIdentifier(field.replaceAll('.', '__'))}');
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
          // e.g., 'user.name' -> 'user__name' (the alias format, matches RelationCompiler)
          explicitRelationColumns.add('${parts[0]}__${parts[1]}');
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

  /// Check if a WHERE clause contains relationPath filters (v0.2.9+).
  ///
  /// Recursively searches through the WHERE map for '_relationPath' keys
  /// which indicate FilterOperators.relationPath() usage.
  bool _containsRelationPath(Map<String, dynamic>? where) {
    if (where == null || where.isEmpty) return false;

    for (final entry in where.entries) {
      final key = entry.key;
      final value = entry.value;

      // Direct relationPath filter
      if (key == '_relationPath') return true;

      // Check nested maps (e.g., in AND/OR conditions or nested objects)
      if (value is Map<String, dynamic>) {
        if (_containsRelationPath(value)) return true;
      }

      // Check lists (e.g., AND: [...] or OR: [...])
      if (value is List) {
        for (final item in value) {
          if (item is Map<String, dynamic>) {
            if (_containsRelationPath(item)) return true;
          }
        }
      }
    }

    return false;
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

    return fields
        .map((field) => '"$alias".${_quoteIdentifier(field)}')
        .join(', ');
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
      'count' =>
        field == '*' ? 'COUNT(*)' : 'COUNT(${_quoteIdentifier(field)})',
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

  /// Known filter operators for scalar fields.
  ///
  /// These are valid keys in a Map filter value for non-relation fields.
  /// Any unknown key will result in an error to catch invalid queries early.
  static const _knownScalarOperators = {
    'equals',
    'not',
    'in',
    'notIn',
    'lt',
    'lte',
    'gt',
    'gte',
    'contains',
    'startsWith',
    'endsWith',
    'isNull',
    'isNotNull',
    'notInOrNull',
    'inOrNull',
    'equalsOrNull',
  };

  /// Validate that a Map filter value contains only known operators.
  ///
  /// Throws [ArgumentError] if unknown operators are found, helping users
  /// identify invalid queries before they generate bad SQL.
  void _validateScalarFilterOperators(
    String field,
    Map<String, dynamic> value,
    String? modelName,
  ) {
    final unknownOperators = value.keys
        .where((key) => !_knownScalarOperators.contains(key))
        .toList();

    if (unknownOperators.isNotEmpty) {
      final modelInfo = modelName != null ? ' on model "$modelName"' : '';
      final plural = unknownOperators.length > 1;
      throw ArgumentError(
        'Unknown filter operator${plural ? 's' : ''} "${unknownOperators.join('", "')}" for field "$field"$modelInfo. '
        'Valid scalar operators: ${_knownScalarOperators.join(', ')}. '
        'If "$field" is a relation, use FilterOperators.some(), every(), or none().',
      );
    }
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

      // Handle deep relation path filter (v0.2.9+)
      // Used with FilterOperators.relationPath() for OR conditions across relation trees
      if (field == '_relationPath' && value is String) {
        final relationWhere = where['_relationWhere'] as Map<String, dynamic>?;
        if (relationWhere != null && modelName != null) {
          final (clause, vals, typs) = _buildRelationPathFilter(
            path: value,
            where: relationWhere,
            baseModel: modelName,
            baseAlias: baseAlias ?? 't0',
            startIndex: paramIndex,
          );
          if (clause.isNotEmpty) {
            conditions.add(clause);
            values.addAll(vals);
            types.addAll(typs);
            paramIndex += vals.length;
          }
        }
        continue;
      }

      // Skip _relationWhere as it's handled with _relationPath
      if (field == '_relationWhere') {
        continue;
      }

      // Check if field is a relation with a filter operator (some/every/none)
      if (modelName != null && value is Map<String, dynamic>) {
        final effectiveSchema = schema ?? schemaRegistry;
        final relation = effectiveSchema.getRelation(modelName, field);
        final relOperator = _detectRelationOperator(value);

        if (relation != null && relOperator != null) {
          final whereCondition = value[relOperator];
          // Use baseAlias if available, otherwise fall back to parentAlias
          // This ensures relation filters use the correct table alias (e.g., 't0')
          final effectiveParentAlias = baseAlias ?? parentAlias;
          final (clause, vals, typs) = _buildRelationFilterClause(
            parentModel: modelName,
            parentAlias: effectiveParentAlias,
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
        } else if (relation != null && relOperator == null) {
          // Relation field used without some/every/none operator
          // This is a common mistake that generates invalid SQL
          throw ArgumentError(
            'Relation field "$field" on model "$modelName" requires a filter '
            'operator. Use FilterOperators.some(), every(), or none(). '
            'Example: {\'$field\': FilterOperators.some({\'fieldName\': value})}. '
            'For complex OR conditions across relations, use '
            'FilterOperators.relationPath() instead.',
          );
        }
      }

      // Handle field conditions
      // Use field name as-is (don't convert to snake_case)
      // Prefix with table alias if baseAlias is provided (for disambiguating JOINs)
      final columnName = baseAlias != null
          ? '"$baseAlias".${_quoteIdentifier(field)}'
          : _quoteIdentifier(field);

      if (value is Map<String, dynamic>) {
        // Validate that all keys are known operators before processing
        // This catches invalid patterns early instead of generating bad SQL
        _validateScalarFilterOperators(field, value, modelName);

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

            // ==================== NULL-Coalescing Operators ====================

            case 'isNull':
              // Generates: field IS NULL
              conditions.add('$columnName IS NULL');
              break;

            case 'isNotNull':
              // Generates: field IS NOT NULL
              conditions.add('$columnName IS NOT NULL');
              break;

            case 'notInOrNull':
              // Generates: (field NOT IN (...) OR field IS NULL)
              // Useful for LEFT JOIN filtering where NULL means "no match"
              final notInOrNullList = op.value as List;
              if (notInOrNullList.isEmpty) {
                // Empty list means always true (nothing to exclude)
                conditions.add('(1=1)');
              } else {
                final placeholders = List.generate(
                  notInOrNullList.length,
                  (_) => _placeholder(paramIndex++),
                );
                conditions.add(
                  '($columnName NOT IN (${placeholders.join(', ')}) OR $columnName IS NULL)',
                );
                values.addAll(notInOrNullList);
                types.addAll(notInOrNullList.map(_inferArgType));
              }
              break;

            case 'inOrNull':
              // Generates: (field IN (...) OR field IS NULL)
              final inOrNullList = op.value as List;
              if (inOrNullList.isEmpty) {
                // Empty list means only NULL matches
                conditions.add('$columnName IS NULL');
              } else {
                final placeholders = List.generate(
                  inOrNullList.length,
                  (_) => _placeholder(paramIndex++),
                );
                conditions.add(
                  '($columnName IN (${placeholders.join(', ')}) OR $columnName IS NULL)',
                );
                values.addAll(inOrNullList);
                types.addAll(inOrNullList.map(_inferArgType));
              }
              break;

            case 'equalsOrNull':
              // Generates: (field = value OR field IS NULL)
              conditions.add(
                '($columnName = ${_placeholder(paramIndex++)} OR $columnName IS NULL)',
              );
              values.add(op.value);
              types.add(_inferArgType(op.value));
              break;
            default:
              // This should not be reached if _knownScalarOperators is in sync
              // with this switch statement, but serves as a safeguard.
              throw StateError(
                'Unsupported filter operator "${op.key}" passed validation but is not implemented. '
                'Please add implementation for this operator or remove it from _knownScalarOperators.',
              );
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
    // The targetAlias must match the parentAlias passed to _buildWhereClause above
    // so that nested relation filters can reference this table by alias.
    final targetAlias = 'sub_$relationName';
    String existsClause;

    switch (relation.type) {
      case RelationType.oneToMany:
        // Parent has many targets. FK is on target table.
        // EXISTS (SELECT 1 FROM Target AS sub_X WHERE sub_X.fk = Parent.id AND ...)
        existsClause = _buildOneToManyExistsClause(
          operator: operator,
          targetTable: targetTable,
          targetAlias: targetAlias,
          targetFk: relation.foreignKey,
          parentRef: parentRef,
          parentPk: relation.references.first,
          subWhere: subWhere,
        );

      case RelationType.manyToOne:
        // Parent belongs to target. FK is on parent table.
        // EXISTS (SELECT 1 FROM Target AS sub_X WHERE sub_X.id = Parent.fk AND ...)
        existsClause = _buildManyToOneExistsClause(
          operator: operator,
          targetTable: targetTable,
          targetAlias: targetAlias,
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
            targetAlias: targetAlias,
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
            targetAlias: targetAlias,
            targetFk: relation.foreignKey,
            parentRef: parentRef,
            parentPk: relation.references.first,
            subWhere: subWhere,
          );
        }

      case RelationType.manyToMany:
        // Uses a join table.
        // EXISTS (SELECT 1 FROM JoinTable JOIN Target AS sub_X ON ... WHERE ...)
        existsClause = _buildManyToManyExistsClause(
          operator: operator,
          targetTable: targetTable,
          targetAlias: targetAlias,
          joinTable: _quoteIdentifier(relation.joinTable ?? ''),
          joinColumn: _quoteIdentifier(relation.joinColumn ?? 'A'),
          inverseJoinColumn:
              _quoteIdentifier(relation.inverseJoinColumn ?? 'B'),
          parentRef: parentRef,
          parentPk: relation.references.first,
          subWhere: subWhere,
        );
    }

    return (existsClause, values, types);
  }

  /// Build EXISTS clause for one-to-many relations.
  ///
  /// The [targetAlias] parameter is used to alias the target table in the
  /// FROM clause. This is essential for nested relation filters, where inner
  /// EXISTS subqueries need to reference the outer table by alias.
  String _buildOneToManyExistsClause({
    required String operator,
    required String targetTable,
    required String targetAlias,
    required String targetFk,
    required String parentRef,
    required String parentPk,
    required String subWhere,
  }) {
    final fkCol = _quoteIdentifier(targetFk);
    final pkCol = _quoteIdentifier(parentPk);

    // Use alias for column references so nested filters can reference this table
    final joinCondition = '$targetAlias.$fkCol = $parentRef.$pkCol';
    final fullCondition =
        subWhere.isNotEmpty ? '$joinCondition AND $subWhere' : joinCondition;

    // Add AS $targetAlias to define the alias in FROM clause
    return switch (operator) {
      'some' =>
        'EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $fullCondition)',
      'every' => subWhere.isNotEmpty
          ? 'NOT EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $joinCondition AND NOT ($subWhere))'
          : 'TRUE', // every with no condition is always true
      'none' =>
        'NOT EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $fullCondition)',
      _ => throw ArgumentError('Unknown relation operator: $operator'),
    };
  }

  /// Build EXISTS clause for many-to-one relations.
  ///
  /// The [targetAlias] parameter is used to alias the target table in the
  /// FROM clause. This is essential for nested relation filters.
  String _buildManyToOneExistsClause({
    required String operator,
    required String targetTable,
    required String targetAlias,
    required String targetPk,
    required String parentRef,
    required String parentFk,
    required String subWhere,
  }) {
    final pkCol = _quoteIdentifier(targetPk);
    final fkCol = _quoteIdentifier(parentFk);

    // Use alias for column references so nested filters can reference this table
    final joinCondition = '$targetAlias.$pkCol = $parentRef.$fkCol';
    final fullCondition =
        subWhere.isNotEmpty ? '$joinCondition AND $subWhere' : joinCondition;

    // Add AS $targetAlias to define the alias in FROM clause
    return switch (operator) {
      'some' =>
        'EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $fullCondition)',
      'every' => subWhere.isNotEmpty
          ? 'NOT EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $joinCondition AND NOT ($subWhere))'
          : 'TRUE',
      'none' =>
        'NOT EXISTS (SELECT 1 FROM $targetTable AS $targetAlias WHERE $fullCondition)',
      _ => throw ArgumentError('Unknown relation operator: $operator'),
    };
  }

  /// Build EXISTS clause for many-to-many relations (via junction table).
  ///
  /// The [targetAlias] parameter is used to alias the target table in the
  /// INNER JOIN clause. This is essential for nested relation filters.
  String _buildManyToManyExistsClause({
    required String operator,
    required String targetTable,
    required String targetAlias,
    required String joinTable,
    required String joinColumn,
    required String inverseJoinColumn,
    required String parentRef,
    required String parentPk,
    required String subWhere,
  }) {
    final pkCol = _quoteIdentifier(parentPk);

    // Subquery joins through junction table to target table (with alias)
    // The alias allows nested relation filters to reference this table
    final joinClause = '''
SELECT 1 FROM $joinTable
INNER JOIN $targetTable AS $targetAlias ON $targetAlias."id" = $joinTable.$inverseJoinColumn
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

  /// Build EXISTS clause for deep relation path filtering (v0.2.9+).
  ///
  /// Handles paths like 'appointment.consultation.consultationPlan'
  /// by building an EXISTS subquery that chains JOINs through the relations.
  ///
  /// Example: For path 'appointment.consultation.consultationPlan'
  /// on model 'SlotOfAppointment' with where {'consultantProfileId': 'abc'}
  ///
  /// Generates:
  /// ```sql
  /// EXISTS (
  ///   SELECT 1 FROM "Appointment" rp1
  ///   LEFT JOIN "Consultation" rp2 ON rp2."id" = rp1."consultationId"
  ///   LEFT JOIN "ConsultationPlan" rp3 ON rp3."id" = rp2."consultationPlanId"
  ///   WHERE rp3."consultantProfileId" = $1 AND rp1."id" = t0."appointmentId"
  /// )
  /// ```
  (String, List<dynamic>, List<ArgType>) _buildRelationPathFilter({
    required String path,
    required Map<String, dynamic> where,
    required String baseModel,
    required String baseAlias,
    required int startIndex,
  }) {
    final parts = path.split('.');
    if (parts.isEmpty) return ('', [], []);

    final effectiveSchema = schema ?? schemaRegistry;
    final values = <dynamic>[];
    final types = <ArgType>[];
    final paramIndex = startIndex;

    // Build the subquery with chained JOINs
    final joinClauses = <String>[];
    String currentModel = baseModel;
    String previousAlias = baseAlias;
    var aliasCounter = 1;

    // First relation determines the FROM clause
    // Subsequent relations are JOINs
    String? fromTable;
    String? fromAlias;
    String? linkToBaseCondition;

    for (var i = 0; i < parts.length; i++) {
      final relationName = parts[i];
      final relation = effectiveSchema.getRelation(currentModel, relationName);

      if (relation == null) {
        // Unknown relation - return empty (will be ignored)
        return ('', [], []);
      }

      final targetModelSchema = effectiveSchema.getModel(relation.targetModel);
      if (targetModelSchema == null) {
        return ('', [], []);
      }

      final targetTable = _quoteIdentifier(targetModelSchema.tableName);
      final alias = 'rp$aliasCounter';
      aliasCounter++;

      if (i == 0) {
        // First relation: this is the FROM clause
        fromTable = targetTable;
        fromAlias = alias;

        // Build the link back to the base table
        // Depends on relation type
        switch (relation.type) {
          case RelationType.oneToMany:
            // FK is on target side (target.fk = base.pk)
            linkToBaseCondition =
                '"$alias".${_quoteIdentifier(relation.foreignKey)} = "$baseAlias".${_quoteIdentifier(relation.references.first)}';
          case RelationType.manyToOne:
          case RelationType.oneToOne:
            // FK is on base side (target.pk = base.fk)
            linkToBaseCondition =
                '"$alias".${_quoteIdentifier(relation.references.first)} = "$baseAlias".${_quoteIdentifier(relation.foreignKey)}';
          case RelationType.manyToMany:
            // Many-to-many relations not yet supported (requires junction table)
            // TODO(v0.3.0): Add many-to-many support via junction table joins
            return ('', [], []);
        }
      } else {
        // Subsequent relations: these are JOINs
        String joinCondition;
        switch (relation.type) {
          case RelationType.oneToMany:
            // FK is on target side
            joinCondition =
                '"$alias".${_quoteIdentifier(relation.foreignKey)} = "$previousAlias".${_quoteIdentifier(relation.references.first)}';
          case RelationType.manyToOne:
          case RelationType.oneToOne:
            // FK is on parent side (previous table)
            joinCondition =
                '"$alias".${_quoteIdentifier(relation.references.first)} = "$previousAlias".${_quoteIdentifier(relation.foreignKey)}';
          case RelationType.manyToMany:
            // Many-to-many relations not yet supported (requires junction table)
            // TODO(v0.3.0): Add many-to-many support via junction table joins
            return ('', [], []);
        }

        joinClauses.add('LEFT JOIN $targetTable "$alias" ON $joinCondition');
      }

      previousAlias = alias;
      currentModel = relation.targetModel;
    }

    if (fromTable == null || fromAlias == null || linkToBaseCondition == null) {
      return ('', [], []);
    }

    // Build WHERE clause for the deepest relation
    final (whereClause, whereVals, whereTypes) = _buildWhereClause(
      where,
      startIndex: paramIndex,
      modelName: currentModel,
      baseAlias: previousAlias,
    );
    values.addAll(whereVals);
    types.addAll(whereTypes);

    // Combine all parts into EXISTS subquery
    final joinClausesStr =
        joinClauses.isNotEmpty ? ' ${joinClauses.join(' ')}' : '';

    String fullWhere;
    if (whereClause.isNotEmpty) {
      fullWhere = '$whereClause AND $linkToBaseCondition';
    } else {
      fullWhere = linkToBaseCondition;
    }

    final existsClause =
        'EXISTS (SELECT 1 FROM $fromTable "$fromAlias"$joinClausesStr WHERE $fullWhere)';

    return (existsClause, values, types);
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
  String _buildOrderByClause(Map<String, dynamic>? orderBy,
      {String? baseAlias}) {
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
    if (!_yearPattern.hasMatch(value)) return false;

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
