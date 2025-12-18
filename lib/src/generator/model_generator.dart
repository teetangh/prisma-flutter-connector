/// Model generator for Freezed models from Prisma schema
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates Freezed model files from Prisma models
class ModelGenerator {
  final PrismaSchema schema;

  const ModelGenerator(this.schema);

  /// Generate Dart code for a single model
  String generateModel(PrismaModel model) {
    final buffer = StringBuffer();

    // Imports
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();

    // Import filter types for WhereInput
    buffer.writeln("import '../filters.dart';");
    buffer.writeln();

    // Collect all types that need imports (models and enums)
    final imports = <String>{};

    for (final field in model.fields) {
      final fieldType = field.type;

      // Skip primitive types
      if (_isPrimitiveType(fieldType)) continue;

      // Add import for this type (could be model or enum)
      imports.add(fieldType);
    }

    // Write imports
    for (final importType in imports) {
      buffer.writeln("import '${toSnakeCase(importType)}.dart';");
    }
    if (imports.isNotEmpty) {
      buffer.writeln();
    }

    // Part files
    buffer.writeln("part '${toSnakeCase(model.name)}.freezed.dart';");
    buffer.writeln("part '${toSnakeCase(model.name)}.g.dart';");
    buffer.writeln();

    // Main model class
    buffer.writeln('@freezed');
    buffer.writeln('class ${model.name} with _\$${model.name} {');
    buffer.writeln('  const factory ${model.name}({');

    // Fields
    for (final field in model.fields) {
      // Handle relation fields - exclude from JSON serialization
      if (field.isRelation) {
        buffer.writeln(
            '    @JsonKey(includeFromJson: false, includeToJson: false)');
        // Relation fields are always optional
        final relationType = field.isList ? 'List<${field.type}>' : field.type;
        buffer.writeln('    $relationType? ${field.name},');
        continue;
      }

      // Add @JsonKey for fields with database name mapping (reserved keyword renames)
      if (field.dbName != null) {
        buffer.writeln("    @JsonKey(name: '${field.dbName}')");
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
        final enumValue = toCamelCase(field.defaultValue!);
        buffer.writeln('    @Default(${field.type}.$enumValue)');
        if (field.isRequired && !field.isList) {
          buffer.writeln('    required ${field.dartType} ${field.name},');
        } else {
          buffer.writeln('    ${field.dartType} ${field.name},');
        }
        continue;
      }

      // Handle scalar defaults (skip Prisma runtime functions)
      if (field.defaultValue != null &&
          !field.isRelation &&
          !_isPrismaRuntimeDefault(field.defaultValue!)) {
        buffer.writeln('    @Default(${field.defaultValue})');
      }

      // Get proper Dart type
      final dartType = _toDartType(field.type);

      // Regular fields - use correct required/optional logic
      if (field.isRequired && !field.isList) {
        // Required non-list fields
        buffer.writeln('    required $dartType ${field.name},');
      } else if (!field.isRequired && !field.isList) {
        // Optional non-list fields
        buffer.writeln('    $dartType? ${field.name},');
      } else if (field.isList && field.isRequired) {
        // Required list fields
        buffer.writeln('    required List<$dartType> ${field.name},');
      } else {
        // Optional list fields
        buffer.writeln('    List<$dartType>? ${field.name},');
      }
    }

    buffer.writeln('  }) = _${model.name};');
    buffer.writeln();
    buffer.writeln(
        '  factory ${model.name}.fromJson(Map<String, dynamic> json) =>');
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

  /// Check if a type is a model (defined in the schema)
  bool _isModelType(String typeName) {
    return schema.models.any((m) => m.name == typeName);
  }

  /// Check if a field is a relation (either explicit or implicit)
  bool _isRelationField(PrismaField field) {
    // Explicit @relation attribute
    if (field.isRelation) return true;
    // Implicit relation - type is another model
    if (_isModelType(field.type)) return true;
    return false;
  }

  /// Check if a type is a Prisma primitive type
  bool _isPrimitiveType(String typeName) {
    const primitives = {
      'String',
      'Int',
      'BigInt',
      'Float',
      'Decimal',
      'Boolean',
      'DateTime',
      'Json',
      'Bytes',
    };
    return primitives.contains(typeName);
  }

  /// Convert Prisma type to Dart type
  String _toDartType(String prismaType) {
    switch (prismaType) {
      case 'String':
        return 'String';
      case 'Int':
        return 'int';
      case 'BigInt':
        return 'BigInt';
      case 'Float':
      case 'Decimal':
        return 'double';
      case 'Boolean':
        return 'bool';
      case 'DateTime':
        return 'DateTime';
      case 'Json':
        return 'Map<String, dynamic>';
      case 'Bytes':
        return 'List<int>';
      default:
        // Enum or relation type - keep as-is
        return prismaType;
    }
  }

  /// Check if a default value is a Prisma runtime function (not a compile-time constant)
  /// These cannot be used with Freezed @Default() annotation
  bool _isPrismaRuntimeDefault(String defaultValue) {
    const runtimeFunctions = {
      'uuid()',
      'cuid()',
      'now()',
      'autoincrement()',
    };

    // Check exact matches (O(1) lookup with Set)
    if (runtimeFunctions.contains(defaultValue)) {
      return true;
    }

    // Check for dbgenerated(...) which is always runtime
    if (defaultValue.startsWith('dbgenerated(')) {
      return true;
    }

    return false;
  }

  /// Generate Create input type
  String _generateInputTypes(PrismaModel model) {
    final buffer = StringBuffer();

    // CreateInput
    buffer.writeln('/// Input for creating a new ${model.name}');
    buffer.writeln('@freezed');
    buffer.writeln(
        'class Create${model.name}Input with _\$Create${model.name}Input {');
    buffer.writeln('  const factory Create${model.name}Input({');

    for (final field in model.fields) {
      // Skip auto-generated fields and relations (explicit or implicit)
      if (field.isId ||
          field.isCreatedAt ||
          field.isUpdatedAt ||
          _isRelationField(field)) {
        continue;
      }

      final dartType = _toDartType(field.type);

      // Handle list fields with empty default
      if (field.hasEmptyListDefault && field.isList) {
        buffer.writeln('    @Default(<$dartType>[])');
        buffer.writeln('    List<$dartType>? ${field.name},');
        continue;
      }

      // Handle enum defaults
      if (field.defaultValue != null && _isEnumType(field.type)) {
        final enumValue = toCamelCase(field.defaultValue!);
        buffer.writeln('    @Default($dartType.$enumValue)');
        if (field.isRequired) {
          buffer.writeln('    required $dartType ${field.name},');
        } else {
          buffer.writeln('    $dartType? ${field.name},');
        }
        continue;
      }

      // Handle other defaults (skip Prisma runtime functions)
      if (field.isRequired && field.defaultValue == null) {
        if (field.isList) {
          buffer.writeln('    required List<$dartType> ${field.name},');
        } else {
          buffer.writeln('    required $dartType ${field.name},');
        }
      } else if (field.defaultValue != null &&
          !_isPrismaRuntimeDefault(field.defaultValue!)) {
        buffer.writeln('    @Default(${field.defaultValue})');
        if (field.isList) {
          buffer.writeln('    List<$dartType>? ${field.name},');
        } else {
          buffer.writeln('    $dartType? ${field.name},');
        }
      } else {
        if (field.isList) {
          buffer.writeln('    List<$dartType>? ${field.name},');
        } else {
          buffer.writeln('    $dartType? ${field.name},');
        }
      }
    }

    buffer.writeln('  }) = _Create${model.name}Input;');
    buffer.writeln();
    buffer.writeln(
        '  factory Create${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$Create${model.name}InputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    // UpdateInput
    buffer.writeln('/// Input for updating an existing ${model.name}');
    buffer.writeln('@freezed');
    buffer.writeln(
        'class Update${model.name}Input with _\$Update${model.name}Input {');
    buffer.writeln('  const factory Update${model.name}Input({');

    for (final field in model.fields) {
      // Skip auto-generated, ID fields, and relations (explicit or implicit)
      if (field.isId ||
          field.isCreatedAt ||
          field.isUpdatedAt ||
          _isRelationField(field)) {
        continue;
      }

      final dartType = _toDartType(field.type);

      // All update fields are optional
      if (field.isList) {
        buffer.writeln('    List<$dartType>? ${field.name},');
      } else {
        buffer.writeln('    $dartType? ${field.name},');
      }
    }

    buffer.writeln('  }) = _Update${model.name}Input;');
    buffer.writeln();
    buffer.writeln(
        '  factory Update${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$Update${model.name}InputFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate WhereUniqueInput type for unique lookups
  String _generateWhereUniqueInput(PrismaModel model) {
    final buffer = StringBuffer();

    // Find unique fields (id or @unique)
    final uniqueFields = model.fields
        .where((f) => (f.isId || f.isUnique) && !f.isRelation)
        .toList();

    if (uniqueFields.isEmpty) {
      return ''; // No unique fields, skip generation
    }

    buffer.writeln('/// Unique where input for ${model.name}');
    buffer.writeln('/// At least one field must be provided');
    buffer.writeln('@freezed');
    buffer.writeln(
        'class ${model.name}WhereUniqueInput with _\$${model.name}WhereUniqueInput {');
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
    buffer.writeln(
        '  factory ${model.name}WhereUniqueInput.fromJson(Map<String, dynamic> json) =>');
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
    buffer.writeln(
        'class ${model.name}WhereInput with _\$${model.name}WhereInput {');
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
    buffer.writeln(
        '  factory ${model.name}WhereInput.fromJson(Map<String, dynamic> json) =>');
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
    buffer.writeln(
        'class ${model.name}OrderByInput with _\$${model.name}OrderByInput {');
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
    buffer.writeln(
        '  factory ${model.name}OrderByInput.fromJson(Map<String, dynamic> json) =>');
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
    // Handle list fields - only String and Int lists have generated filters
    if (field.isList) {
      switch (field.type) {
        case 'String':
          return 'StringListFilter';
        case 'Int':
          return 'IntListFilter';
        default:
          // No filter for other list types (models, enums, etc.)
          return null;
      }
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
        // Unknown type (model types, etc.), skip filter
        return null;
    }
  }

  /// Generate enum class
  String generateEnum(PrismaEnum enumDef) {
    final buffer = StringBuffer();

    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();
    buffer.writeln('enum ${enumDef.name} {');

    for (final value in enumDef.values) {
      buffer.writeln("  @JsonValue('$value')");
      // Handle reserved keywords in enum values
      var dartValue = toCamelCase(value);
      if (_isDartReservedKeyword(dartValue)) {
        dartValue = '${dartValue}Value';
      }
      buffer.writeln('  $dartValue,');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Check if a name is a Dart reserved keyword
  /// Uses dartReservedKeywords from prisma_parser.dart
  bool _isDartReservedKeyword(String name) {
    return dartReservedKeywords.contains(name.toLowerCase());
  }

  /// Generate all model files
  Map<String, String> generateAll() {
    final files = <String, String>{};

    // Generate models
    for (final model in schema.models) {
      final fileName = '${toSnakeCase(model.name)}.dart';
      files[fileName] = generateModel(model);
    }

    // Generate enums
    for (final enumDef in schema.enums) {
      final fileName = '${toSnakeCase(enumDef.name)}.dart';
      files[fileName] = generateEnum(enumDef);
    }

    return files;
  }
}
