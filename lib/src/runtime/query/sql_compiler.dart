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

/// Compiles JSON queries to SQL.
class SqlCompiler {
  final String provider;
  final String? schemaName;

  SqlCompiler({
    required this.provider,
    this.schemaName,
  });

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

    // Build SELECT clause
    final selectFields = _buildSelectFields(query.args.selection);
    final selectClause = selectFields.isEmpty ? '*' : selectFields.join(', ');

    // Build WHERE clause
    final where = args['where'] as Map<String, dynamic>?;
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where);

    // Build ORDER BY clause
    final orderBy = args['orderBy'] as Map<String, dynamic>?;
    final orderByClause = _buildOrderByClause(orderBy);

    // Build LIMIT/OFFSET
    final take = args['take'] as int?;
    final skip = args['skip'] as int?;

    // Construct SQL
    final sql = StringBuffer('SELECT $selectClause FROM ${_quoteIdentifier(tableName)}');

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
    );
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

    // Add RETURNING clause for PostgreSQL
    final sqlWithReturning = provider == 'postgresql' ? '$sql RETURNING *' : sql;

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
      setClauses.add('${_quoteIdentifier(entry.key)} = ${_placeholder(paramIndex++)}');
      values.add(entry.value);
      types.add(_inferArgType(entry.value));
    }

    // Build WHERE clause
    final (whereClause, whereArgs, whereTypes) = _buildWhereClause(where, startIndex: paramIndex);
    values.addAll(whereArgs);
    types.addAll(whereTypes);

    final sql = 'UPDATE ${_quoteIdentifier(tableName)} '
        'SET ${setClauses.join(', ')}'
        '${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}';

    return SqlQuery(
      sql: sql,
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

  /// Build SELECT fields from selection.
  List<String> _buildSelectFields(JsonSelection? selection) {
    if (selection == null || selection.scalars == true && selection.fields == null) {
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
              final placeholders = List.generate(list.length, (_) => _placeholder(paramIndex++));
              conditions.add('$columnName IN (${placeholders.join(', ')})');
              values.addAll(list);
              types.addAll(list.map(_inferArgType));
              break;
            case 'notIn':
              final list = op.value as List;
              final placeholders = List.generate(list.length, (_) => _placeholder(paramIndex++));
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

  /// Convert camelCase to snake_case.
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
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
  bool _isIso8601DateTime(String value) {
    try {
      DateTime.parse(value);
      return true;
    } catch (_) {
      return false;
    }
  }
}
