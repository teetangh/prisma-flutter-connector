/// Relation Compiler for generating SQL JOINs from Prisma include/select.
///
/// This module compiles Prisma's `include` directive into SQL JOIN clauses
/// and generates the SELECT columns with proper aliasing to avoid conflicts.
///
/// Example:
/// ```dart
/// // Input: include: {posts: true, profile: true}
/// // Output: LEFT JOIN "posts" ON ... LEFT JOIN "profiles" ON ...
/// ```
library;

import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

/// Compiled result containing JOIN clauses and column selection.
class CompiledRelations implements RelationMetadata {
  /// SQL JOIN clauses to append to the query.
  final String joinClauses;

  /// Column aliases for SELECT (maps alias to original column).
  final Map<String, ColumnAlias> columnAliases;

  /// Relations that were included, with their metadata.
  final List<IncludedRelation> includedRelations;

  const CompiledRelations({
    required this.joinClauses,
    required this.columnAliases,
    required this.includedRelations,
  });

  /// Empty result (no relations).
  static const empty = CompiledRelations(
    joinClauses: '',
    columnAliases: {},
    includedRelations: [],
  );

  bool get isEmpty => joinClauses.isEmpty;
  bool get isNotEmpty => joinClauses.isNotEmpty;
}

/// Alias information for a column.
class ColumnAlias {
  /// The table alias (e.g., 't0', 't1').
  final String tableAlias;

  /// The original column name.
  final String columnName;

  /// The model this column belongs to.
  final String modelName;

  /// The relation path (e.g., 'posts', 'posts.comments').
  final String? relationPath;

  const ColumnAlias({
    required this.tableAlias,
    required this.columnName,
    required this.modelName,
    this.relationPath,
  });
}

/// Information about an included relation.
class IncludedRelation {
  /// The relation field name (e.g., 'posts').
  final String name;

  /// The relation info from schema.
  final RelationInfo relation;

  /// Table alias used in the query.
  final String tableAlias;

  /// The parent table alias (for nested relations).
  final String parentAlias;

  /// Nested includes within this relation.
  final List<IncludedRelation> nestedIncludes;

  const IncludedRelation({
    required this.name,
    required this.relation,
    required this.tableAlias,
    required this.parentAlias,
    this.nestedIncludes = const [],
  });
}

/// Compiles Prisma include/select into SQL JOINs.
class RelationCompiler {
  final SchemaRegistry _schema;
  final String _provider;

  /// Starting counter for table aliases (default 1 since t0 is reserved for base table).
  final int _startingCounter;

  int _aliasCounter;

  RelationCompiler({
    required SchemaRegistry schema,
    String provider = 'postgresql',
    int startingCounter = 1,
  })  : _schema = schema,
        _provider = provider,
        _startingCounter = startingCounter,
        _aliasCounter = startingCounter;

  /// Compile include directive into JOIN clauses.
  ///
  /// [baseModel] - The main model being queried (e.g., 'User').
  /// [baseAlias] - The alias for the base table (e.g., 't0').
  /// [include] - The include map from the query.
  /// [baseSelectFields] - Optional list of fields to select from base model.
  ///
  /// Returns compiled relations with JOIN clauses and aliases.
  ///
  /// Include syntax supports selecting specific fields from relations:
  /// ```dart
  /// include: {
  ///   'user': true,  // Include all fields
  ///   'domain': {
  ///     'select': {'id': true, 'name': true}  // Only id and name
  ///   },
  ///   'posts': {
  ///     'select': {'title': true},
  ///     'include': {'author': true}  // Nested include
  ///   }
  /// }
  /// ```
  CompiledRelations compile({
    required String baseModel,
    required String baseAlias,
    required Map<String, dynamic> include,
    List<String>? baseSelectFields,
  }) {
    // Reset to starting counter (default 1 since t0 is reserved for base table)
    _aliasCounter = _startingCounter;

    final joins = <String>[];
    final aliases = <String, ColumnAlias>{};
    final includedRelations = <IncludedRelation>[];

    // Add base model columns (either all or selected)
    if (baseSelectFields != null && baseSelectFields.isNotEmpty) {
      _addSelectedColumns(
        modelName: baseModel,
        tableAlias: baseAlias,
        aliases: aliases,
        selectedFields: baseSelectFields,
      );
    } else {
      _addModelColumns(
        modelName: baseModel,
        tableAlias: baseAlias,
        aliases: aliases,
      );
    }

    // Process each include
    for (final entry in include.entries) {
      final relationName = entry.key;
      final relationValue = entry.value;

      // Skip if not included
      if (relationValue == false) continue;

      final relation = _schema.getRelation(baseModel, relationName);
      if (relation == null) {
        // Unknown relation, skip
        continue;
      }

      final result = _compileRelation(
        relation: relation,
        relationName: relationName,
        parentModel: baseModel,
        parentAlias: baseAlias,
        includeValue: relationValue,
        aliases: aliases,
      );

      if (result != null) {
        joins.add(result.joinClause);
        includedRelations.add(result.includedRelation);
      }
    }

    return CompiledRelations(
      joinClauses: joins.join(' '),
      columnAliases: aliases,
      includedRelations: includedRelations,
    );
  }

  /// Generate SELECT columns with aliases.
  String generateSelectColumns(Map<String, ColumnAlias> aliases) {
    final columns = <String>[];

    for (final entry in aliases.entries) {
      final alias = entry.key;
      final info = entry.value;
      columns.add(
          '${_quote(info.tableAlias)}.${_quote(info.columnName)} AS ${_quote(alias)}');
    }

    return columns.join(', ');
  }

  _RelationCompileResult? _compileRelation({
    required RelationInfo relation,
    required String relationName,
    required String parentModel,
    required String parentAlias,
    required dynamic includeValue,
    required Map<String, ColumnAlias> aliases,
  }) {
    final targetModel = _schema.getModel(relation.targetModel);
    if (targetModel == null) return null;

    final tableAlias = _nextAlias();

    // Build the JOIN clause based on relation type
    final joinClause = _buildJoinClause(
      relation: relation,
      parentModel: parentModel,
      parentAlias: parentAlias,
      targetModel: targetModel,
      targetAlias: tableAlias,
    );

    // Check if includeValue has a 'select' directive for field selection
    List<String>? selectFields;
    if (includeValue is Map<String, dynamic>) {
      final select = includeValue['select'];
      if (select is Map<String, dynamic>) {
        // Extract field names where value is true
        selectFields = select.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toList();
      }
    }

    // Add target model columns with proper aliasing
    if (selectFields != null && selectFields.isNotEmpty) {
      // Only add selected fields
      _addSelectedColumns(
        modelName: relation.targetModel,
        tableAlias: tableAlias,
        aliases: aliases,
        selectedFields: selectFields,
        relationPath: relationName,
      );
    } else {
      // Add all columns
      _addModelColumns(
        modelName: relation.targetModel,
        tableAlias: tableAlias,
        aliases: aliases,
        relationPath: relationName,
      );
    }

    // Handle nested includes
    final nestedIncludes = <IncludedRelation>[];
    if (includeValue is Map<String, dynamic>) {
      final nestedInclude = includeValue['include'] as Map<String, dynamic>?;
      if (nestedInclude != null) {
        for (final nested in nestedInclude.entries) {
          final nestedRelation = _schema.getRelation(
            relation.targetModel,
            nested.key,
          );
          if (nestedRelation != null) {
            final nestedResult = _compileRelation(
              relation: nestedRelation,
              relationName: '$relationName.${nested.key}',
              parentModel: relation.targetModel,
              parentAlias: tableAlias,
              includeValue: nested.value,
              aliases: aliases,
            );
            if (nestedResult != null) {
              nestedIncludes.add(nestedResult.includedRelation);
            }
          }
        }
      }
    }

    return _RelationCompileResult(
      joinClause: joinClause,
      includedRelation: IncludedRelation(
        name: relationName,
        relation: relation,
        tableAlias: tableAlias,
        parentAlias: parentAlias,
        nestedIncludes: nestedIncludes,
      ),
    );
  }

  String _buildJoinClause({
    required RelationInfo relation,
    required String parentModel,
    required String parentAlias,
    required ModelSchema targetModel,
    required String targetAlias,
  }) {
    final targetTable = _quote(targetModel.tableName);

    switch (relation.type) {
      case RelationType.oneToMany:
        // Parent has many targets, FK is on target
        // LEFT JOIN "posts" t1 ON t1."author_id" = t0."id"
        return 'LEFT JOIN $targetTable ${_quote(targetAlias)} ON '
            '${_quote(targetAlias)}.${_quote(relation.foreignKey)} = '
            '${_quote(parentAlias)}.${_quote(relation.references.first)}';

      case RelationType.manyToOne:
        // Target has many parents, FK is on parent
        // LEFT JOIN "users" t1 ON t1."id" = t0."author_id"
        return 'LEFT JOIN $targetTable ${_quote(targetAlias)} ON '
            '${_quote(targetAlias)}.${_quote(relation.references.first)} = '
            '${_quote(parentAlias)}.${_quote(relation.foreignKey)}';

      case RelationType.oneToOne:
        // Depends on which side owns the FK
        if (relation.isOwner) {
          // FK is on this model
          return 'LEFT JOIN $targetTable ${_quote(targetAlias)} ON '
              '${_quote(targetAlias)}.${_quote(relation.references.first)} = '
              '${_quote(parentAlias)}.${_quote(relation.foreignKey)}';
        } else {
          // FK is on target model
          return 'LEFT JOIN $targetTable ${_quote(targetAlias)} ON '
              '${_quote(targetAlias)}.${_quote(relation.foreignKey)} = '
              '${_quote(parentAlias)}.${_quote(relation.references.first)}';
        }

      case RelationType.manyToMany:
        // Need join table
        // LEFT JOIN "_UserToRole" j ON j."A" = t0."id"
        // LEFT JOIN "roles" t1 ON t1."id" = j."B"
        final joinTable = _quote(relation.joinTable!);
        final joinAlias = 'j$_aliasCounter';

        return 'LEFT JOIN $joinTable ${_quote(joinAlias)} ON '
            '${_quote(joinAlias)}.${_quote(relation.joinColumn!)} = '
            '${_quote(parentAlias)}.${_quote(relation.references.first)} '
            'LEFT JOIN $targetTable ${_quote(targetAlias)} ON '
            '${_quote(targetAlias)}.${_quote(relation.references.first)} = '
            '${_quote(joinAlias)}.${_quote(relation.inverseJoinColumn!)}';
    }
  }

  void _addModelColumns({
    required String modelName,
    required String tableAlias,
    required Map<String, ColumnAlias> aliases,
    String? relationPath,
  }) {
    final model = _schema.getModel(modelName);
    if (model == null) return;

    for (final field in model.scalarFields) {
      // Create unique alias: relationPath_columnName or just columnName
      final aliasKey = relationPath != null
          ? '${relationPath}__${field.columnName}'
          : field.columnName;

      aliases[aliasKey] = ColumnAlias(
        tableAlias: tableAlias,
        columnName: field.columnName,
        modelName: modelName,
        relationPath: relationPath,
      );
    }
  }

  /// Add only selected columns from a model.
  ///
  /// This is used when the include directive specifies which fields to select.
  void _addSelectedColumns({
    required String modelName,
    required String tableAlias,
    required Map<String, ColumnAlias> aliases,
    required List<String> selectedFields,
    String? relationPath,
  }) {
    final model = _schema.getModel(modelName);
    if (model == null) {
      // Model not in schema, add fields directly by name
      for (final fieldName in selectedFields) {
        final aliasKey =
            relationPath != null ? '${relationPath}__$fieldName' : fieldName;

        aliases[aliasKey] = ColumnAlias(
          tableAlias: tableAlias,
          columnName: fieldName,
          modelName: modelName,
          relationPath: relationPath,
        );
      }
      return;
    }

    // Map of field name -> column name for the model
    final fieldToColumn = <String, String>{};
    for (final field in model.scalarFields) {
      fieldToColumn[field.name] = field.columnName;
    }

    for (final fieldName in selectedFields) {
      // Get actual column name (may differ from field name)
      final columnName = fieldToColumn[fieldName] ?? fieldName;

      final aliasKey =
          relationPath != null ? '${relationPath}__$columnName' : columnName;

      aliases[aliasKey] = ColumnAlias(
        tableAlias: tableAlias,
        columnName: columnName,
        modelName: modelName,
        relationPath: relationPath,
      );
    }
  }

  String _nextAlias() {
    return 't${_aliasCounter++}';
  }

  String _quote(String identifier) {
    return switch (_provider) {
      'mysql' => '`$identifier`',
      _ => '"$identifier"',
    };
  }
}

class _RelationCompileResult {
  final String joinClause;
  final IncludedRelation includedRelation;

  const _RelationCompileResult({
    required this.joinClause,
    required this.includedRelation,
  });
}

/// Deserializes flat JOIN results into nested objects.
class RelationDeserializer {
  final SchemaRegistry _schema;

  RelationDeserializer({required SchemaRegistry schema}) : _schema = schema;

  /// Deserialize flat rows into nested structure.
  ///
  /// [rows] - Flat rows from JOIN query.
  /// [baseModel] - The base model name.
  /// [columnAliases] - Column alias mapping.
  /// [includedRelations] - List of included relations.
  ///
  /// Returns list of nested objects.
  List<Map<String, dynamic>> deserialize({
    required List<Map<String, dynamic>> rows,
    required String baseModel,
    required Map<String, ColumnAlias> columnAliases,
    required List<IncludedRelation> includedRelations,
  }) {
    if (rows.isEmpty) return [];

    // Group rows by base model primary key
    final model = _schema.getModel(baseModel);
    if (model == null) return rows;

    final pkFields = model.primaryKeys;
    if (pkFields.isEmpty) return rows;

    final pkColumn = pkFields.first.columnName;

    // Group by primary key
    final grouped = <dynamic, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final pk = row[pkColumn];
      (grouped[pk] ??= []).add(row);
    }

    // Build result for each unique base record
    return grouped.entries.map((entry) {
      final rowGroup = entry.value;
      final baseRow = _extractBaseColumns(rowGroup.first, columnAliases);

      // Add relations
      for (final relation in includedRelations) {
        baseRow[relation.name] = _extractRelation(
          rows: rowGroup,
          relation: relation,
          columnAliases: columnAliases,
        );
      }

      return baseRow;
    }).toList();
  }

  Map<String, dynamic> _extractBaseColumns(
    Map<String, dynamic> row,
    Map<String, ColumnAlias> aliases,
  ) {
    final result = <String, dynamic>{};

    for (final entry in aliases.entries) {
      final alias = entry.key;
      final info = entry.value;

      // Only include base model columns (no relation path)
      if (info.relationPath == null) {
        result[info.columnName] = row[alias];
      }
    }

    return result;
  }

  dynamic _extractRelation({
    required List<Map<String, dynamic>> rows,
    required IncludedRelation relation,
    required Map<String, ColumnAlias> columnAliases,
  }) {
    final prefix = '${relation.name}__';

    if (relation.relation.isToOne) {
      // To-one: return single object or null
      final row = rows.first;
      final obj = <String, dynamic>{};
      var hasData = false;

      for (final entry in columnAliases.entries) {
        final alias = entry.key;
        final info = entry.value;

        if (alias.startsWith(prefix) &&
            !alias.substring(prefix.length).contains('__')) {
          final columnName = info.columnName;
          final value = row[alias];
          obj[columnName] = value;
          if (value != null) hasData = true;
        }
      }

      if (!hasData) return null;

      // Handle nested relations
      for (final nested in relation.nestedIncludes) {
        obj[nested.name] = _extractRelation(
          rows: rows,
          relation: nested,
          columnAliases: columnAliases,
        );
      }

      return obj;
    } else {
      // To-many: return list of objects
      final targetModel = _schema.getModel(relation.relation.targetModel);
      if (targetModel == null) return <Map<String, dynamic>>[];

      final pkFields = targetModel.primaryKeys;
      if (pkFields.isEmpty) return <Map<String, dynamic>>[];

      final pkColumn = pkFields.first.columnName;
      final pkAlias = '${relation.name}__$pkColumn';

      // Group by relation's primary key to avoid duplicates
      final seen = <dynamic>{};
      final results = <Map<String, dynamic>>[];

      for (final row in rows) {
        final pk = row[pkAlias];
        if (pk == null || seen.contains(pk)) continue;
        seen.add(pk);

        final obj = <String, dynamic>{};
        for (final entry in columnAliases.entries) {
          final alias = entry.key;
          final info = entry.value;

          if (alias.startsWith(prefix) &&
              !alias.substring(prefix.length).contains('__')) {
            obj[info.columnName] = row[alias];
          }
        }

        // Handle nested relations
        for (final nested in relation.nestedIncludes) {
          obj[nested.name] = _extractRelation(
            rows: rows.where((r) => r[pkAlias] == pk).toList(),
            relation: nested,
            columnAliases: columnAliases,
          );
        }

        results.add(obj);
      }

      return results;
    }
  }
}
