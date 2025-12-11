/// Delegate generator for adapter-based ORM
///
/// Generates type-safe delegate classes that use QueryExecutor and database adapters
/// instead of GraphQL. This provides a true Prisma-style ORM experience.
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Generates delegate classes for adapter-based database access
class DelegateGenerator {
  final PrismaSchema schema;

  const DelegateGenerator(this.schema);

  /// Generate delegate class for a single model
  String generateDelegate(PrismaModel model) {
    final buffer = StringBuffer();
    final modelName = model.name;
    final tableName = model.tableName; // Use database table name for queries

    // Imports
    buffer.writeln("import 'package:prisma_flutter_connector/runtime.dart';");
    buffer.writeln("import '../models/${_toSnakeCase(modelName)}.dart';");
    buffer.writeln("import '../filters.dart';");
    buffer.writeln();

    // Delegate class
    buffer.writeln('/// Delegate for $modelName operations');
    buffer.writeln(
        '/// Provides type-safe CRUD operations using database adapters');
    buffer.writeln('class ${modelName}Delegate {');
    buffer.writeln('  final QueryExecutor _executor;');
    buffer.writeln();
    buffer.writeln('  ${modelName}Delegate(this._executor);');
    buffer.writeln();

    // FindUnique method
    buffer.writeln('  /// Find a single $modelName by unique field(s)');
    buffer.writeln('  Future<$modelName?> findUnique({');
    buffer.writeln('    required ${modelName}WhereUniqueInput where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.findUnique)');
    buffer.writeln('        .where(_whereUniqueToJson(where))');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln(
        '    final result = await _executor.executeQueryAsSingleMap(query);');
    buffer.writeln(
        '    return result != null ? $modelName.fromJson(result) : null;');
    buffer.writeln('  }');
    buffer.writeln();

    // FindUniqueOrThrow method
    buffer.writeln('  /// Find a single $modelName or throw if not found');
    buffer.writeln('  Future<$modelName> findUniqueOrThrow({');
    buffer.writeln('    required ${modelName}WhereUniqueInput where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final result = await findUnique(where: where);');
    buffer.writeln('    if (result == null) {');
    buffer.writeln('      throw Exception(\'$modelName not found\');');
    buffer.writeln('    }');
    buffer.writeln('    return result;');
    buffer.writeln('  }');
    buffer.writeln();

    // FindFirst method
    buffer.writeln('  /// Find the first $modelName matching criteria');
    buffer.writeln('  Future<$modelName?> findFirst({');
    buffer.writeln('    ${modelName}WhereInput? where,');
    buffer.writeln('    ${modelName}OrderByInput? orderBy,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.findFirst);');
    buffer.writeln();
    buffer.writeln(
        '    if (where != null) queryBuilder.where(_whereToJson(where));');
    buffer.writeln(
        '    if (orderBy != null) queryBuilder.orderBy(_orderByToJson(orderBy));');
    buffer.writeln();
    buffer.writeln(
        '    final result = await _executor.executeQueryAsSingleMap(queryBuilder.build());');
    buffer.writeln(
        '    return result != null ? $modelName.fromJson(result) : null;');
    buffer.writeln('  }');
    buffer.writeln();

    // FindMany method
    buffer.writeln('  /// Find multiple ${modelName}s with optional filters');
    buffer.writeln('  Future<List<$modelName>> findMany({');
    buffer.writeln('    ${modelName}WhereInput? where,');
    buffer.writeln('    ${modelName}OrderByInput? orderBy,');
    buffer.writeln('    int? take,');
    buffer.writeln('    int? skip,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.findMany);');
    buffer.writeln();
    buffer.writeln(
        '    if (where != null) queryBuilder.where(_whereToJson(where));');
    buffer.writeln(
        '    if (orderBy != null) queryBuilder.orderBy(_orderByToJson(orderBy));');
    buffer.writeln('    if (take != null) queryBuilder.take(take);');
    buffer.writeln('    if (skip != null) queryBuilder.skip(skip);');
    buffer.writeln();
    buffer.writeln(
        '    final results = await _executor.executeQueryAsMaps(queryBuilder.build());');
    buffer.writeln(
        '    return results.map((json) => $modelName.fromJson(json)).toList();');
    buffer.writeln('  }');
    buffer.writeln();

    // Create method
    buffer.writeln('  /// Create a new $modelName');
    buffer.writeln('  Future<$modelName> create({');
    buffer.writeln('    required Create${modelName}Input data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.create)');
    buffer.writeln('        .data(data.toJson())');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln(
        '    final result = await _executor.executeQueryAsSingleMap(query);');
    buffer.writeln('    if (result == null) {');
    buffer.writeln('      throw Exception(\'Failed to create $modelName\');');
    buffer.writeln('    }');
    buffer.writeln('    return $modelName.fromJson(result);');
    buffer.writeln('  }');
    buffer.writeln();

    // CreateMany method
    buffer.writeln('  /// Create multiple ${modelName}s');
    buffer.writeln('  Future<int> createMany({');
    buffer.writeln('    required List<Create${modelName}Input> data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.createMany)');
    buffer.writeln(
        '        .data({\'data\': data.map((d) => d.toJson()).toList()})');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Update method
    buffer.writeln('  /// Update a $modelName');
    buffer.writeln('  Future<$modelName> update({');
    buffer.writeln('    required ${modelName}WhereUniqueInput where,');
    buffer.writeln('    required Update${modelName}Input data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.update)');
    buffer.writeln('        .where(_whereUniqueToJson(where))');
    buffer.writeln('        .data(data.toJson())');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    await _executor.executeMutation(query);');
    buffer.writeln();
    buffer.writeln('    // Fetch the updated record');
    buffer.writeln('    return await findUniqueOrThrow(where: where);');
    buffer.writeln('  }');
    buffer.writeln();

    // UpdateMany method
    buffer.writeln('  /// Update multiple ${modelName}s');
    buffer.writeln('  Future<int> updateMany({');
    buffer.writeln('    required ${modelName}WhereInput where,');
    buffer.writeln('    required Update${modelName}Input data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.updateMany)');
    buffer.writeln('        .where(_whereToJson(where))');
    buffer.writeln('        .data(data.toJson())');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Delete method
    buffer.writeln('  /// Delete a $modelName');
    buffer.writeln('  Future<$modelName> delete({');
    buffer.writeln('    required ${modelName}WhereUniqueInput where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    // Fetch before deleting');
    buffer
        .writeln('    final existing = await findUniqueOrThrow(where: where);');
    buffer.writeln();
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.delete)');
    buffer.writeln('        .where(_whereUniqueToJson(where))');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    await _executor.executeMutation(query);');
    buffer.writeln('    return existing;');
    buffer.writeln('  }');
    buffer.writeln();

    // DeleteMany method
    buffer.writeln('  /// Delete multiple ${modelName}s');
    buffer.writeln('  Future<int> deleteMany({');
    buffer.writeln('    required ${modelName}WhereInput where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.deleteMany)');
    buffer.writeln('        .where(_whereToJson(where))');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Count method
    buffer.writeln('  /// Count ${modelName}s matching criteria');
    buffer.writeln('  Future<int> count({');
    buffer.writeln('    ${modelName}WhereInput? where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$tableName\')');
    buffer.writeln('        .action(QueryAction.count);');
    buffer.writeln();
    buffer.writeln(
        '    if (where != null) queryBuilder.where(_whereToJson(where));');
    buffer.writeln();
    buffer.writeln(
        '    return await _executor.executeCount(queryBuilder.build());');
    buffer.writeln('  }');
    buffer.writeln();

    // Helper methods for converting typed inputs to JSON
    buffer
        .writeln('  /// Convert WhereUniqueInput to JSON for JsonQueryBuilder');
    buffer.writeln(
        '  Map<String, dynamic> _whereUniqueToJson(${modelName}WhereUniqueInput where) {');
    buffer.writeln(
        '    return where.toJson()..removeWhere((key, value) => value == null);');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Convert WhereInput to JSON for JsonQueryBuilder');
    buffer.writeln(
        '  Map<String, dynamic> _whereToJson(${modelName}WhereInput where) {');
    buffer.writeln('    final json = where.toJson();');
    buffer.writeln('    final result = <String, dynamic>{};');
    buffer.writeln();
    buffer
        .writeln('    // Convert filter objects to their JSON representation');
    buffer.writeln('    for (final entry in json.entries) {');
    buffer.writeln('      if (entry.value == null) continue;');
    buffer.writeln();
    buffer.writeln('      // Handle logical operators (AND, OR, NOT)');
    buffer.writeln('      if (entry.key == \'AND\' || entry.key == \'OR\') {');
    buffer.writeln('        final list = entry.value as List?;');
    buffer.writeln('        if (list != null && list.isNotEmpty) {');
    buffer.writeln('          result[entry.key] = list.map((item) {');
    buffer.writeln('            if (item is Map) return item;');
    buffer.writeln(
        '            return (item as ${modelName}WhereInput).toJson();');
    buffer.writeln('          }).toList();');
    buffer.writeln('        }');
    buffer.writeln('      } else if (entry.key == \'NOT\') {');
    buffer.writeln('        final not = entry.value;');
    buffer.writeln('        if (not is Map) {');
    buffer.writeln('          result[entry.key] = not;');
    buffer.writeln('        } else if (not is ${modelName}WhereInput) {');
    buffer.writeln('          result[entry.key] = not.toJson();');
    buffer.writeln('        }');
    buffer.writeln('      } else {');
    buffer.writeln(
        '        // Handle filter objects (StringFilter, IntFilter, etc.)');
    buffer.writeln('        if (entry.value is Map) {');
    buffer.writeln('          final filterMap = entry.value as Map;');
    buffer.writeln('          final cleanedFilter = <String, dynamic>{};');
    buffer.writeln('          for (final filterEntry in filterMap.entries) {');
    buffer.writeln('            if (filterEntry.value != null) {');
    buffer.writeln(
        '              cleanedFilter[filterEntry.key.toString()] = filterEntry.value;');
    buffer.writeln('            }');
    buffer.writeln('          }');
    buffer.writeln('          if (cleanedFilter.isNotEmpty) {');
    buffer.writeln('            result[entry.key] = cleanedFilter;');
    buffer.writeln('          }');
    buffer.writeln('        } else {');
    buffer.writeln('          result[entry.key] = entry.value;');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    return result;');
    buffer.writeln('  }');
    buffer.writeln();

    buffer.writeln('  /// Convert OrderByInput to JSON for JsonQueryBuilder');
    buffer.writeln(
        '  Map<String, dynamic> _orderByToJson(${modelName}OrderByInput orderBy) {');
    buffer.writeln('    final json = orderBy.toJson();');
    buffer.writeln('    final result = <String, dynamic>{};');
    buffer.writeln();
    buffer.writeln('    for (final entry in json.entries) {');
    buffer.writeln('      if (entry.value != null) {');
    buffer.writeln('        // Convert SortOrder enum to string');
    buffer.writeln(
        '        result[entry.key] = entry.value.toString().split(\'.\').last;');
    buffer.writeln('      }');
    buffer.writeln('    }');
    buffer.writeln();
    buffer.writeln('    return result;');
    buffer.writeln('  }');

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate all delegate files
  Map<String, String> generateAll() {
    final files = <String, String>{};

    for (final model in schema.models) {
      final fileName = '${_toSnakeCase(model.name)}_delegate.dart';
      files[fileName] = generateDelegate(model);
    }

    return files;
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}
