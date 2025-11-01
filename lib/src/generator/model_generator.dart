/// Model generator for Freezed models from Prisma schema
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Generates Freezed model files from Prisma models
class ModelGenerator {
  final PrismaSchema schema;

  const ModelGenerator(this.schema);

  /// Generate Dart code for a single model
  String generateModel(PrismaModel model) {
    final buffer = StringBuffer();

    // Imports
    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();

    // Add imports for related models
    for (final relation in model.relations) {
      buffer.writeln("import '${_toSnakeCase(relation.targetModel)}.dart';");
    }
    if (model.relations.isNotEmpty) {
      buffer.writeln();
    }

    // Part files
    buffer.writeln("part '${_toSnakeCase(model.name)}.freezed.dart';");
    buffer.writeln("part '${_toSnakeCase(model.name)}.g.dart';");
    buffer.writeln();

    // Main model class
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name} with _\$${model.name} {');
    buffer.writeln('  const factory ${model.name}({');

    // Fields
    for (final field in model.fields) {
      if (field.isRequired && !field.isList) {
        buffer.writeln('    required ${field.dartType} ${field.name},');
      } else {
        buffer.writeln('    ${field.dartType} ${field.name},');
      }
    }

    // Relations (optional)
    for (final relation in model.relations) {
      final relationType = relation.targetModel;
      buffer.writeln('    $relationType? ${relation.name},');
    }

    buffer.writeln('  }) = _${model.name};');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}FromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    // Input types
    buffer.write(_generateInputTypes(model));

    // Filter types
    buffer.write(_generateFilterType(model));

    // OrderBy enum
    buffer.write(_generateOrderByEnum(model));

    return buffer.toString();
  }

  /// Generate Create input type
  String _generateInputTypes(PrismaModel model) {
    final buffer = StringBuffer();

    // CreateInput
    buffer.writeln('/// Input for creating a new ${model.name}');
    buffer.writeln('@freezed');
    buffer.writeln('class Create${model.name}Input with _\$Create${model.name}Input {');
    buffer.writeln('  const factory Create${model.name}Input({');

    for (final field in model.fields) {
      // Skip auto-generated fields
      if (field.isId || field.isCreatedAt || field.isUpdatedAt) {
        continue;
      }

      if (field.isRequired) {
        buffer.writeln('    required ${field.dartType} ${field.name},');
      } else if (field.defaultValue != null) {
        buffer.writeln('    @Default(${field.defaultValue}) ${field.dartType} ${field.name},');
      } else {
        buffer.writeln('    ${field.dartType} ${field.name},');
      }
    }

    buffer.writeln('  }) = _Create${model.name}Input;');
    buffer.writeln();
    buffer.writeln('  factory Create${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$Create${model.name}InputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    // UpdateInput
    buffer.writeln('/// Input for updating an existing ${model.name}');
    buffer.writeln('@freezed');
    buffer.writeln('class Update${model.name}Input with _\$Update${model.name}Input {');
    buffer.writeln('  const factory Update${model.name}Input({');

    for (final field in model.fields) {
      // Skip auto-generated and ID fields
      if (field.isId || field.isCreatedAt || field.isUpdatedAt) {
        continue;
      }

      // Make all fields optional for updates
      var dartType = field.dartType;
      if (!dartType.endsWith('?')) {
        dartType = '$dartType?';
      }
      buffer.writeln('    $dartType ${field.name},');
    }

    buffer.writeln('  }) = _Update${model.name}Input;');
    buffer.writeln();
    buffer.writeln('  factory Update${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$Update${model.name}InputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate Filter type
  String _generateFilterType(PrismaModel model) {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter options for querying ${model.name}');
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name}Filter with _\$${model.name}Filter {');
    buffer.writeln('  const factory ${model.name}Filter({');

    for (final field in model.fields) {
      // Skip relations
      if (field.type[0].toUpperCase() == field.type[0] &&
          field.type != 'String' &&
          field.type != 'DateTime') {
        continue;
      }

      // Add common filter operations
      if (field.type == 'String') {
        buffer.writeln('    String? ${field.name}Contains,');
        buffer.writeln('    String? ${field.name}Equals,');
      } else if (field.type == 'Int' || field.type == 'Float' || field.type == 'Decimal') {
        buffer.writeln('    ${field.dartType} ${field.name}Equals,');
        buffer.writeln('    ${field.dartType} ${field.name}Gt,');
        buffer.writeln('    ${field.dartType} ${field.name}Lt,');
      } else if (field.type == 'DateTime') {
        buffer.writeln('    DateTime? ${field.name}After,');
        buffer.writeln('    DateTime? ${field.name}Before,');
      } else if (field.type == 'Boolean') {
        buffer.writeln('    bool? ${field.name},');
      }
    }

    buffer.writeln('  }) = _${model.name}Filter;');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}Filter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}FilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate OrderBy enum
  String _generateOrderByEnum(PrismaModel model) {
    final buffer = StringBuffer();

    buffer.writeln('/// Sort options for ${model.name}');
    buffer.writeln('enum ${model.name}OrderBy {');

    final sortableFields = model.fields.where((f) =>
        f.type == 'String' ||
        f.type == 'Int' ||
        f.type == 'Float' ||
        f.type == 'DateTime' ||
        f.isCreatedAt ||
        f.isUpdatedAt);

    for (final field in sortableFields) {
      buffer.writeln("  @JsonValue('${field.name}_ASC')");
      buffer.writeln('  ${field.name}Asc,');
      buffer.writeln("  @JsonValue('${field.name}_DESC')");
      buffer.writeln('  ${field.name}Desc,');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate enum class
  String generateEnum(PrismaEnum enumDef) {
    final buffer = StringBuffer();

    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();
    buffer.writeln('enum ${enumDef.name} {');

    for (final value in enumDef.values) {
      buffer.writeln("  @JsonValue('$value')");
      buffer.writeln('  ${_toCamelCase(value)},');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate all model files
  Map<String, String> generateAll() {
    final files = <String, String>{};

    // Generate models
    for (final model in schema.models) {
      final fileName = '${_toSnakeCase(model.name)}.dart';
      files[fileName] = generateModel(model);
    }

    // Generate enums
    for (final enumDef in schema.enums) {
      final fileName = '${_toSnakeCase(enumDef.name)}.dart';
      files[fileName] = generateEnum(enumDef);
    }

    return files;
  }

  /// Convert PascalCase to snake_case
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    ).substring(1); // Remove leading underscore
  }

  /// Convert SCREAMING_CASE to camelCase
  String _toCamelCase(String input) {
    final parts = input.toLowerCase().split('_');
    if (parts.isEmpty) return input;

    final result = StringBuffer(parts[0]);
    for (var i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        result.write(parts[i][0].toUpperCase() + parts[i].substring(1));
      }
    }

    return result.toString();
  }
}
