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

    // Imports
    buffer.writeln("import 'package:prisma_flutter_connector/runtime.dart';");
    buffer.writeln("import '../models/${_toSnakeCase(modelName)}.dart';");
    buffer.writeln();

    // Delegate class
    buffer.writeln('/// Delegate for $modelName operations');
    buffer.writeln('/// Provides type-safe CRUD operations using database adapters');
    buffer.writeln('class ${modelName}Delegate {');
    buffer.writeln('  final QueryExecutor _executor;');
    buffer.writeln();
    buffer.writeln('  ${modelName}Delegate(this._executor);');
    buffer.writeln();

    // FindUnique method
    buffer.writeln('  /// Find a single $modelName by unique field(s)');
    buffer.writeln('  Future<$modelName?> findUnique({');
    buffer.writeln('    required Map<String, dynamic> where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.findUnique)');
    buffer.writeln('        .where(where)');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    final result = await _executor.executeQueryAsSingleMap(query);');
    buffer.writeln('    return result != null ? $modelName.fromJson(result) : null;');
    buffer.writeln('  }');
    buffer.writeln();

    // FindUniqueOrThrow method
    buffer.writeln('  /// Find a single $modelName or throw if not found');
    buffer.writeln('  Future<$modelName> findUniqueOrThrow({');
    buffer.writeln('    required Map<String, dynamic> where,');
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
    buffer.writeln('    Map<String, dynamic>? where,');
    buffer.writeln('    Map<String, String>? orderBy,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.findFirst);');
    buffer.writeln();
    buffer.writeln('    if (where != null) queryBuilder.where(where);');
    buffer.writeln('    if (orderBy != null) queryBuilder.orderBy(orderBy);');
    buffer.writeln();
    buffer.writeln('    final result = await _executor.executeQueryAsSingleMap(queryBuilder.build());');
    buffer.writeln('    return result != null ? $modelName.fromJson(result) : null;');
    buffer.writeln('  }');
    buffer.writeln();

    // FindMany method
    buffer.writeln('  /// Find multiple ${modelName}s with optional filters');
    buffer.writeln('  Future<List<$modelName>> findMany({');
    buffer.writeln('    Map<String, dynamic>? where,');
    buffer.writeln('    Map<String, String>? orderBy,');
    buffer.writeln('    int? take,');
    buffer.writeln('    int? skip,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.findMany);');
    buffer.writeln();
    buffer.writeln('    if (where != null) queryBuilder.where(where);');
    buffer.writeln('    if (orderBy != null) queryBuilder.orderBy(orderBy);');
    buffer.writeln('    if (take != null) queryBuilder.take(take);');
    buffer.writeln('    if (skip != null) queryBuilder.skip(skip);');
    buffer.writeln();
    buffer.writeln('    final results = await _executor.executeQueryAsMaps(queryBuilder.build());');
    buffer.writeln('    return results.map((json) => $modelName.fromJson(json)).toList();');
    buffer.writeln('  }');
    buffer.writeln();

    // Create method
    buffer.writeln('  /// Create a new $modelName');
    buffer.writeln('  Future<$modelName> create({');
    buffer.writeln('    required Map<String, dynamic> data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.create)');
    buffer.writeln('        .data(data)');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    final result = await _executor.executeQueryAsSingleMap(query);');
    buffer.writeln('    if (result == null) {');
    buffer.writeln('      throw Exception(\'Failed to create $modelName\');');
    buffer.writeln('    }');
    buffer.writeln('    return $modelName.fromJson(result);');
    buffer.writeln('  }');
    buffer.writeln();

    // CreateMany method
    buffer.writeln('  /// Create multiple ${modelName}s');
    buffer.writeln('  Future<int> createMany({');
    buffer.writeln('    required List<Map<String, dynamic>> data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.createMany)');
    buffer.writeln('        .data({\'data\': data})');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Update method
    buffer.writeln('  /// Update a $modelName');
    buffer.writeln('  Future<$modelName> update({');
    buffer.writeln('    required Map<String, dynamic> where,');
    buffer.writeln('    required Map<String, dynamic> data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.update)');
    buffer.writeln('        .where(where)');
    buffer.writeln('        .data(data)');
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
    buffer.writeln('    required Map<String, dynamic> where,');
    buffer.writeln('    required Map<String, dynamic> data,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.updateMany)');
    buffer.writeln('        .where(where)');
    buffer.writeln('        .data(data)');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Delete method
    buffer.writeln('  /// Delete a $modelName');
    buffer.writeln('  Future<$modelName> delete({');
    buffer.writeln('    required Map<String, dynamic> where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    // Fetch before deleting');
    buffer.writeln('    final existing = await findUniqueOrThrow(where: where);');
    buffer.writeln();
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.delete)');
    buffer.writeln('        .where(where)');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    await _executor.executeMutation(query);');
    buffer.writeln('    return existing;');
    buffer.writeln('  }');
    buffer.writeln();

    // DeleteMany method
    buffer.writeln('  /// Delete multiple ${modelName}s');
    buffer.writeln('  Future<int> deleteMany({');
    buffer.writeln('    required Map<String, dynamic> where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final query = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.deleteMany)');
    buffer.writeln('        .where(where)');
    buffer.writeln('        .build();');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeMutation(query);');
    buffer.writeln('  }');
    buffer.writeln();

    // Count method
    buffer.writeln('  /// Count ${modelName}s matching criteria');
    buffer.writeln('  Future<int> count({');
    buffer.writeln('    Map<String, dynamic>? where,');
    buffer.writeln('  }) async {');
    buffer.writeln('    final queryBuilder = JsonQueryBuilder()');
    buffer.writeln('        .model(\'$modelName\')');
    buffer.writeln('        .action(QueryAction.count);');
    buffer.writeln();
    buffer.writeln('    if (where != null) queryBuilder.where(where);');
    buffer.writeln();
    buffer.writeln('    return await _executor.executeCount(queryBuilder.build());');
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
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).replaceFirst(RegExp(r'^_'), '');
  }
}
