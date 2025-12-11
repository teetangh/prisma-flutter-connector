/// API generator for type-safe API classes from Prisma models
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Generates API interface classes from Prisma models
class APIGenerator {
  final PrismaSchema schema;

  const APIGenerator(this.schema);

  /// Generate API class for a single model
  String generateAPI(PrismaModel model) {
    final buffer = StringBuffer();
    final modelName = model.name;
    final modelNameLower = _toLowerCamelCase(modelName);

    // Imports
    buffer.writeln("import 'package:graphql_flutter/graphql_flutter.dart'");
    buffer.writeln("    hide NetworkException; // Avoid conflict");
    buffer.writeln(
        "import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';");
    buffer.writeln("import '../models/${_toSnakeCase(modelName)}.dart';");
    buffer.writeln();

    // API class
    buffer.writeln('/// API interface for $modelName operations');
    buffer.writeln('class ${modelName}API extends BaseAPI {');
    buffer.writeln('  ${modelName}API(super.client, super.config);');
    buffer.writeln();

    // FindUnique method
    buffer.writeln('  /// Get a single $modelName by ID');
    buffer.writeln(
        '  Future<$modelName?> findUnique({required String id}) async {');
    buffer.writeln('    const query = r\'\'\'');
    buffer.writeln('      query Get$modelName(\$id: String!) {');
    buffer.writeln('        $modelNameLower(id: \$id) {');
    _writeModelFields(buffer, model, '          ');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    \'\'\';');
    buffer.writeln();
    buffer.writeln(
        '    final result = await executeQuery(query, variables: {\'id\': id});');
    buffer.writeln('    handleErrors(result);');
    buffer.writeln();
    buffer.writeln('    final data = result.data?[\'$modelNameLower\'];');
    buffer.writeln('    if (data == null) return null;');
    buffer.writeln();
    buffer.writeln(
        '    return $modelName.fromJson(data as Map<String, dynamic>);');
    buffer.writeln('  }');
    buffer.writeln();

    // List method
    buffer.writeln('  /// List ${modelName}s with optional filters');
    buffer.writeln('  Future<List<$modelName>> list({');
    buffer.writeln('    ${modelName}Filter? filter,');
    buffer.writeln('    ${modelName}OrderBy? orderBy,');
    buffer.writeln('  }) async {');
    buffer.writeln('    const query = r\'\'\'');
    buffer.writeln('      query List${modelName}s {');
    buffer.writeln('        ${modelNameLower}s {');
    _writeModelFields(buffer, model, '          ');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    \'\'\';');
    buffer.writeln();
    buffer.writeln('    final result = await executeQuery(query);');
    buffer.writeln('    handleErrors(result);');
    buffer.writeln();
    buffer.writeln(
        '    final data = result.data?[\'${modelNameLower}s\'] as List?;');
    buffer.writeln('    if (data == null) return [];');
    buffer.writeln();
    buffer.writeln(
        '    return data.map((json) => $modelName.fromJson(json as Map<String, dynamic>)).toList();');
    buffer.writeln('  }');
    buffer.writeln();

    // Create method
    buffer.writeln('  /// Create a new $modelName');
    buffer.writeln(
        '  Future<$modelName> create({required Create${modelName}Input input}) async {');
    buffer.writeln('    const mutation = r\'\'\'');
    buffer.writeln(
        '      mutation Create$modelName(\$input: Create${modelName}Input!) {');
    buffer.writeln('        create$modelName(input: \$input) {');
    _writeModelFields(buffer, model, '          ');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    \'\'\';');
    buffer.writeln();
    buffer.writeln(
        '    final result = await executeMutation(mutation, variables: {\'input\': input.toJson()});');
    buffer.writeln('    handleErrors(result);');
    buffer.writeln();
    buffer.writeln('    final data = result.data?[\'create$modelName\'];');
    buffer.writeln(
        '    return $modelName.fromJson(data as Map<String, dynamic>);');
    buffer.writeln('  }');
    buffer.writeln();

    // Update method
    buffer.writeln('  /// Update an existing $modelName');
    buffer.writeln(
        '  Future<$modelName> update({required String id, required Update${modelName}Input input}) async {');
    buffer.writeln('    const mutation = r\'\'\'');
    buffer.writeln(
        '      mutation Update$modelName(\$id: String!, \$input: Update${modelName}Input!) {');
    buffer.writeln('        update$modelName(id: \$id, input: \$input) {');
    _writeModelFields(buffer, model, '          ');
    buffer.writeln('        }');
    buffer.writeln('      }');
    buffer.writeln('    \'\'\';');
    buffer.writeln();
    buffer.writeln(
        '    final result = await executeMutation(mutation, variables: {\'id\': id, \'input\': input.toJson()});');
    buffer.writeln('    handleErrors(result);');
    buffer.writeln();
    buffer.writeln('    final data = result.data?[\'update$modelName\'];');
    buffer.writeln(
        '    return $modelName.fromJson(data as Map<String, dynamic>);');
    buffer.writeln('  }');
    buffer.writeln();

    // Delete method
    buffer.writeln('  /// Delete a $modelName');
    buffer.writeln('  Future<bool> delete({required String id}) async {');
    buffer.writeln('    const mutation = r\'\'\'');
    buffer.writeln('      mutation Delete$modelName(\$id: String!) {');
    buffer.writeln('        delete$modelName(id: \$id)');
    buffer.writeln('      }');
    buffer.writeln('    \'\'\';');
    buffer.writeln();
    buffer.writeln(
        '    final result = await executeMutation(mutation, variables: {\'id\': id});');
    buffer.writeln('    handleErrors(result);');
    buffer.writeln();
    buffer.writeln('    return result.data?[\'delete$modelName\'] == true;');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  void _writeModelFields(
      StringBuffer buffer, PrismaModel model, String indent) {
    for (final field in model.fields) {
      buffer.writeln('$indent${field.name}');
    }
  }

  /// Generate all API files
  Map<String, String> generateAll() {
    final files = <String, String>{};

    for (final model in schema.models) {
      final fileName = '${_toSnakeCase(model.name)}_api.dart';
      files[fileName] = generateAPI(model);
    }

    return files;
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1);
  }

  String _toLowerCamelCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }
}
