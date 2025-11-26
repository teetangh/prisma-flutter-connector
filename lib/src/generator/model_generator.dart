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

    // Import filter types for WhereInput
    buffer.writeln("import '../filters.dart';");
    buffer.writeln();

    // Add imports for related models
    for (final relation in model.relations) {
      buffer.writeln("import '${_toSnakeCase(relation.targetModel)}.dart';");
    }
    if (model.relations.isNotEmpty) {
      buffer.writeln();
    }

    // Add imports for enums
    final enumFields = model.fields.where((f) => _isEnumType(f.type));
    for (final field in enumFields) {
      buffer.writeln("import '${_toSnakeCase(field.type)}.dart';");
    }
    if (enumFields.isNotEmpty) {
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
      // Handle relation fields - exclude from JSON serialization
      if (field.isRelation) {
        buffer.writeln('    @JsonKey(includeFromJson: false, includeToJson: false)');
        // Relation fields are always optional
        final relationType = field.isList ? 'List<${field.type}>' : field.type;
        buffer.writeln('    $relationType? ${field.name},');
        continue;
      }

      // Handle list fields with empty default
      if (field.hasEmptyListDefault && field.isList) {
        final elementType = field.type;
        buffer.writeln('    @Default(<$elementType>[])');
        buffer.writeln('    List<$elementType>? ${field.name},');
        continue;
      }

      // Handle enum defaults
      if (field.defaultValue != null && _isEnumType(field.type)) {
        final enumValue = _toCamelCase(field.defaultValue!);
        buffer.writeln('    @Default(${field.type}.$enumValue)');
        if (field.isRequired && !field.isList) {
          buffer.writeln('    required ${field.dartType} ${field.name},');
        } else {
          buffer.writeln('    ${field.dartType} ${field.name},');
        }
        continue;
      }

      // Handle scalar defaults
      if (field.defaultValue != null && !field.isRelation) {
        buffer.writeln('    @Default(${field.defaultValue})');
      }

      // Regular fields - use correct required/optional logic
      if (field.isRequired && !field.isList) {
        // Required non-list fields
        buffer.writeln('    required ${field.type} ${field.name},');
      } else if (!field.isRequired && !field.isList) {
        // Optional non-list fields
        buffer.writeln('    ${field.type}? ${field.name},');
      } else if (field.isList && field.isRequired) {
        // Required list fields
        buffer.writeln('    required List<${field.type}> ${field.name},');
      } else {
        // Optional list fields
        buffer.writeln('    List<${field.type}>? ${field.name},');
      }
    }

    buffer.writeln('  }) = _${model.name};');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}FromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    // Input types
    buffer.write(_generateInputTypes(model));

    // Where input types
    buffer.write(_generateWhereUniqueInput(model));
    buffer.write(_generateWhereInput(model));

    // OrderBy input
    buffer.write(_generateOrderByInput(model));

    return buffer.toString();
  }

  /// Check if a type is an enum (defined in the schema)
  bool _isEnumType(String typeName) {
    return schema.enums.any((e) => e.name == typeName);
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
      // Skip auto-generated fields and relations
      if (field.isId || field.isCreatedAt || field.isUpdatedAt || field.isRelation) {
        continue;
      }

      // Handle list fields with empty default
      if (field.hasEmptyListDefault && field.isList) {
        final elementType = field.type;
        buffer.writeln('    @Default(<$elementType>[])');
        buffer.writeln('    List<$elementType>? ${field.name},');
        continue;
      }

      // Handle enum defaults
      if (field.defaultValue != null && _isEnumType(field.type)) {
        final enumValue = _toCamelCase(field.defaultValue!);
        buffer.writeln('    @Default(${field.type}.$enumValue)');
        if (field.isRequired) {
          buffer.writeln('    required ${field.type} ${field.name},');
        } else {
          buffer.writeln('    ${field.type}? ${field.name},');
        }
        continue;
      }

      // Handle other defaults
      if (field.isRequired && field.defaultValue == null) {
        if (field.isList) {
          buffer.writeln('    required List<${field.type}> ${field.name},');
        } else {
          buffer.writeln('    required ${field.type} ${field.name},');
        }
      } else if (field.defaultValue != null) {
        buffer.writeln('    @Default(${field.defaultValue})');
        if (field.isList) {
          buffer.writeln('    List<${field.type}>? ${field.name},');
        } else {
          buffer.writeln('    ${field.type}? ${field.name},');
        }
      } else {
        if (field.isList) {
          buffer.writeln('    List<${field.type}>? ${field.name},');
        } else {
          buffer.writeln('    ${field.type}? ${field.name},');
        }
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
      // Skip auto-generated, ID fields, and relations
      if (field.isId || field.isCreatedAt || field.isUpdatedAt || field.isRelation) {
        continue;
      }

      // All update fields are optional
      if (field.isList) {
        buffer.writeln('    List<${field.type}>? ${field.name},');
      } else {
        buffer.writeln('    ${field.type}? ${field.name},');
      }
    }

    buffer.writeln('  }) = _Update${model.name}Input;');
    buffer.writeln();
    buffer.writeln('  factory Update${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$Update${model.name}InputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate WhereUniqueInput type for unique lookups
  String _generateWhereUniqueInput(PrismaModel model) {
    final buffer = StringBuffer();

    // Find unique fields (id or @unique)
    final uniqueFields = model.fields.where((f) =>
        (f.isId || f.isUnique) && !f.isRelation).toList();

    if (uniqueFields.isEmpty) {
      return ''; // No unique fields, skip generation
    }

    buffer.writeln('/// Unique where input for ${model.name}');
    buffer.writeln('/// At least one field must be provided');
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name}WhereUniqueInput with _\$${model.name}WhereUniqueInput {');
    buffer.writeln('  const factory ${model.name}WhereUniqueInput({');

    // All unique fields are optional (but at least one required at runtime)
    for (final field in uniqueFields) {
      if (field.isList) {
        buffer.writeln('    List<${field.type}>? ${field.name},');
      } else {
        buffer.writeln('    ${field.type}? ${field.name},');
      }
    }

    buffer.writeln('  }) = _${model.name}WhereUniqueInput;');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}WhereUniqueInput.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}WhereUniqueInputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate WhereInput type for filtering
  String _generateWhereInput(PrismaModel model) {
    final buffer = StringBuffer();

    buffer.writeln('/// Where input for filtering ${model.name} records');
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name}WhereInput with _\$${model.name}WhereInput {');
    buffer.writeln('  const factory ${model.name}WhereInput({');

    // Add field filters (using field-level filter types)
    for (final field in model.fields) {
      // Skip relations for now
      if (field.isRelation) continue;

      final filterType = _getFilterTypeForField(field);
      if (filterType != null) {
        buffer.writeln('    $filterType? ${field.name},');
      }
    }

    // Add logical operators
    buffer.writeln('    List<${model.name}WhereInput>? AND,');
    buffer.writeln('    List<${model.name}WhereInput>? OR,');
    buffer.writeln('    ${model.name}WhereInput? NOT,');

    buffer.writeln('  }) = _${model.name}WhereInput;');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}WhereInput.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}WhereInputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate OrderByInput type for sorting
  String _generateOrderByInput(PrismaModel model) {
    final buffer = StringBuffer();

    buffer.writeln('/// Order by input for sorting ${model.name} records');
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name}OrderByInput with _\$${model.name}OrderByInput {');
    buffer.writeln('  const factory ${model.name}OrderByInput({');

    // Include sortable fields
    final sortableFields = model.fields.where((f) =>
        !f.isRelation &&
        (f.type == 'String' ||
            f.type == 'Int' ||
            f.type == 'Float' ||
            f.type == 'DateTime' ||
            f.type == 'Boolean' ||
            f.isCreatedAt ||
            f.isUpdatedAt));

    for (final field in sortableFields) {
      buffer.writeln('    SortOrder? ${field.name},');
    }

    buffer.writeln('  }) = _${model.name}OrderByInput;');
    buffer.writeln();
    buffer.writeln('  factory ${model.name}OrderByInput.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${model.name}OrderByInputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    // Generate SortOrder enum (only once, could be shared)
    buffer.writeln('/// Sort order for ordering results');
    buffer.writeln('enum SortOrder {');
    buffer.writeln("  @JsonValue('asc')");
    buffer.writeln('  asc,');
    buffer.writeln("  @JsonValue('desc')");
    buffer.writeln('  desc,');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Get the filter type for a field based on its Prisma type
  String? _getFilterTypeForField(PrismaField field) {
    if (field.isList) {
      // List fields use special list filters
      return '${field.type}ListFilter';
    }

    switch (field.type) {
      case 'String':
        return 'StringFilter';
      case 'Int':
        return 'IntFilter';
      case 'Float':
      case 'Decimal':
        return 'FloatFilter';
      case 'Boolean':
        return 'BooleanFilter';
      case 'DateTime':
        return 'DateTimeFilter';
      default:
        // Check if it's an enum
        if (_isEnumType(field.type)) {
          return '${field.type}Filter';
        }
        // Unknown type, skip filter
        return null;
    }
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
