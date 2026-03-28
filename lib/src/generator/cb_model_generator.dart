/// Model generator using code_builder for type-safe AST generation.
///
/// Generates Freezed model files, input types, filter types, and enums
/// from Prisma schema definitions.
// ignore_for_file: prefer_const_constructors
library;

import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates Freezed model files from Prisma models using code_builder.
class CbModelGenerator {
  final PrismaSchema schema;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  CbModelGenerator(this.schema);

  /// Generate Dart code for a single model.
  ///
  /// Because Freezed models require specific annotation patterns (`@freezed`,
  /// `part` directives, `_$` prefixed mixins) that code_builder doesn't
  /// natively support, we use a hybrid approach: code_builder for imports and
  /// structure, but Code() blocks for the Freezed-specific class bodies.
  String generateModel(PrismaModel model) {
    // Freezed models have very specific syntax requirements that are easier
    // to handle with targeted string generation inside code_builder Code blocks.
    // The key benefit of code_builder here is auto-formatting and structured imports.
    final buf = StringBuffer();

    // Imports
    buf.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buf.writeln();
    buf.writeln("import '../filters.dart';");
    buf.writeln();

    // Model/enum type imports
    final imports = <String>{};
    for (final field in model.fields) {
      if (!_isPrimitiveType(field.type)) imports.add(field.type);
    }
    for (final imp in imports) {
      buf.writeln("import '${toSnakeCase(imp)}.dart';");
    }
    if (imports.isNotEmpty) buf.writeln();

    // Part files
    buf.writeln("part '${toSnakeCase(model.name)}.freezed.dart';");
    buf.writeln("part '${toSnakeCase(model.name)}.g.dart';");
    buf.writeln();

    // Main model class
    buf.writeln('@freezed');
    buf.writeln('class ${model.name} with _\$${model.name} {');
    buf.writeln('  const factory ${model.name}({');
    for (final field in model.fields) {
      buf.write(_generateModelField(field));
    }
    buf.writeln('  }) = _${model.name};');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}FromJson(json);');
    buf.writeln('}');
    buf.writeln();

    // Input types
    buf.write(_generateCreateInput(model));
    buf.write(_generateUpdateInput(model));
    buf.write(_generateWhereUniqueInput(model));
    buf.write(_generateWhereInput(model));
    buf.write(_generateRelationFilters(model));
    buf.write(_generateOrderByInput(model));

    return _formatter.format(buf.toString());
  }

  String _generateModelField(PrismaField field) {
    final buf = StringBuffer();

    if (field.isRelation) {
      buf.writeln('    @JsonKey(includeFromJson: false, includeToJson: false)');
      final type = field.isList ? 'List<${field.type}>' : field.type;
      buf.writeln('    $type? ${field.name},');
      return buf.toString();
    }

    if (field.dbName != null) {
      buf.writeln("    @JsonKey(name: '${field.dbName}')");
    }

    if (field.hasEmptyListDefault && field.isList) {
      buf.writeln('    @Default(<${field.type}>[])');
      buf.writeln('    List<${field.type}>? ${field.name},');
      return buf.toString();
    }

    if (field.defaultValue != null && _isEnumType(field.type)) {
      buf.writeln(
          '    @Default(${field.type}.${toCamelCase(field.defaultValue!)})');
      buf.writeln('    ${field.dartType} ${field.name},');
      return buf.toString();
    }

    final hasScalarDefault = field.defaultValue != null &&
        !field.isRelation &&
        !_isPrismaRuntimeDefault(field.defaultValue!);

    if (hasScalarDefault) {
      buf.writeln('    @Default(${field.defaultValue})');
    }

    final dartType = _toDartType(field.type);

    if (hasScalarDefault) {
      buf.writeln(field.isList
          ? '    List<$dartType> ${field.name},'
          : '    $dartType ${field.name},');
    } else if (field.isRequired && !field.isList) {
      buf.writeln('    required $dartType ${field.name},');
    } else if (!field.isRequired && !field.isList) {
      buf.writeln('    $dartType? ${field.name},');
    } else if (field.isList && field.isRequired) {
      buf.writeln('    required List<$dartType> ${field.name},');
    } else {
      buf.writeln('    List<$dartType>? ${field.name},');
    }

    return buf.toString();
  }

  String _generateCreateInput(PrismaModel model) {
    final buf = StringBuffer();
    buf.writeln('/// Input for creating a new ${model.name}');
    buf.writeln('@freezed');
    buf.writeln(
        'class Create${model.name}Input with _\$Create${model.name}Input {');
    buf.writeln('  const factory Create${model.name}Input({');

    for (final field in model.fields) {
      if (field.isId ||
          field.isCreatedAt ||
          field.isUpdatedAt ||
          _isRelationField(field)) {
        continue;
      }
      final dartType = _toDartType(field.type);

      if (field.hasEmptyListDefault && field.isList) {
        buf.writeln('    @Default(<$dartType>[])');
        buf.writeln('    List<$dartType>? ${field.name},');
        continue;
      }

      if (field.defaultValue != null && _isEnumType(field.type)) {
        buf.writeln(
            '    @Default($dartType.${toCamelCase(field.defaultValue!)})');
        buf.writeln('    $dartType ${field.name},');
        continue;
      }

      if (field.isRequired && field.defaultValue == null) {
        buf.writeln(field.isList
            ? '    required List<$dartType> ${field.name},'
            : '    required $dartType ${field.name},');
      } else if (field.defaultValue != null &&
          !_isPrismaRuntimeDefault(field.defaultValue!)) {
        buf.writeln('    @Default(${field.defaultValue})');
        buf.writeln(field.isList
            ? '    List<$dartType>? ${field.name},'
            : '    $dartType? ${field.name},');
      } else {
        buf.writeln(field.isList
            ? '    List<$dartType>? ${field.name},'
            : '    $dartType? ${field.name},');
      }
    }

    buf.writeln('  }) = _Create${model.name}Input;');
    buf.writeln();
    buf.writeln(
        '  factory Create${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$Create${model.name}InputFromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }

  String _generateUpdateInput(PrismaModel model) {
    final buf = StringBuffer();
    buf.writeln('/// Input for updating an existing ${model.name}');
    buf.writeln('@freezed');
    buf.writeln(
        'class Update${model.name}Input with _\$Update${model.name}Input {');
    buf.writeln('  const factory Update${model.name}Input({');

    for (final field in model.fields) {
      if (field.isId ||
          field.isCreatedAt ||
          field.isUpdatedAt ||
          _isRelationField(field)) {
        continue;
      }
      final dartType = _toDartType(field.type);
      buf.writeln(field.isList
          ? '    List<$dartType>? ${field.name},'
          : '    $dartType? ${field.name},');
    }

    buf.writeln('  }) = _Update${model.name}Input;');
    buf.writeln();
    buf.writeln(
        '  factory Update${model.name}Input.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$Update${model.name}InputFromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }

  String _generateWhereUniqueInput(PrismaModel model) {
    final uniqueFields = model.fields
        .where((f) => (f.isId || f.isUnique) && !f.isRelation)
        .toList();
    if (uniqueFields.isEmpty) return '';

    final buf = StringBuffer();
    buf.writeln('@freezed');
    buf.writeln(
        'class ${model.name}WhereUniqueInput with _\$${model.name}WhereUniqueInput {');
    buf.writeln('  const factory ${model.name}WhereUniqueInput({');
    for (final field in uniqueFields) {
      buf.writeln(field.isList
          ? '    List<${field.type}>? ${field.name},'
          : '    ${field.type}? ${field.name},');
    }
    buf.writeln('  }) = _${model.name}WhereUniqueInput;');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}WhereUniqueInput.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}WhereUniqueInputFromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }

  String _generateWhereInput(PrismaModel model) {
    final buf = StringBuffer();
    buf.writeln('@freezed');
    buf.writeln(
        'class ${model.name}WhereInput with _\$${model.name}WhereInput {');
    buf.writeln('  @JsonSerializable(explicitToJson: true)');
    buf.writeln('  const factory ${model.name}WhereInput({');

    for (final field in model.fields) {
      if (field.isRelation) {
        final relType = field.isList
            ? '${field.type}ListRelationFilter'
            : '${field.type}RelationFilter';
        buf.writeln('    $relType? ${field.name},');
        continue;
      }
      final filterType = _getFilterType(field);
      if (filterType != null) {
        buf.writeln('    $filterType? ${field.name},');
      }
    }

    buf.writeln('    List<${model.name}WhereInput>? AND,');
    buf.writeln('    List<${model.name}WhereInput>? OR,');
    buf.writeln('    ${model.name}WhereInput? NOT,');
    buf.writeln('  }) = _${model.name}WhereInput;');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}WhereInput.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}WhereInputFromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }

  String _generateRelationFilters(PrismaModel model) {
    final buf = StringBuffer();

    // ListRelationFilter
    buf.writeln('@freezed');
    buf.writeln(
        'class ${model.name}ListRelationFilter with _\$${model.name}ListRelationFilter {');
    buf.writeln('  const factory ${model.name}ListRelationFilter({');
    buf.writeln('    ${model.name}WhereInput? some,');
    buf.writeln('    ${model.name}WhereInput? every,');
    buf.writeln('    ${model.name}WhereInput? none,');
    buf.writeln('  }) = _${model.name}ListRelationFilter;');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}ListRelationFilter.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}ListRelationFilterFromJson(json);');
    buf.writeln('}');
    buf.writeln();

    // RelationFilter
    buf.writeln('@freezed');
    buf.writeln(
        'class ${model.name}RelationFilter with _\$${model.name}RelationFilter {');
    buf.writeln('  const factory ${model.name}RelationFilter({');
    buf.writeln("    @JsonKey(name: 'is') ${model.name}WhereInput? is_,");
    buf.writeln('    ${model.name}WhereInput? isNot,');
    buf.writeln('  }) = _${model.name}RelationFilter;');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}RelationFilter.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}RelationFilterFromJson(json);');
    buf.writeln('}');
    buf.writeln();

    return buf.toString();
  }

  String _generateOrderByInput(PrismaModel model) {
    final buf = StringBuffer();
    buf.writeln('@freezed');
    buf.writeln(
        'class ${model.name}OrderByInput with _\$${model.name}OrderByInput {');
    buf.writeln('  const factory ${model.name}OrderByInput({');

    for (final field in model.fields.where((f) =>
        !f.isRelation &&
        (f.type == 'String' ||
            f.type == 'Int' ||
            f.type == 'Float' ||
            f.type == 'DateTime' ||
            f.type == 'Boolean' ||
            f.isCreatedAt ||
            f.isUpdatedAt))) {
      buf.writeln('    SortOrder? ${field.name},');
    }

    buf.writeln('  }) = _${model.name}OrderByInput;');
    buf.writeln();
    buf.writeln(
        '  factory ${model.name}OrderByInput.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${model.name}OrderByInputFromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }

  /// Generate enum class
  String generateEnum(PrismaEnum enumDef) {
    final buf = StringBuffer();
    buf.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buf.writeln();
    buf.writeln('enum ${enumDef.name} {');
    for (final value in enumDef.values) {
      buf.writeln("  @JsonValue('$value')");
      var dartValue = toCamelCase(value);
      if (_isDartReservedKeyword(dartValue)) dartValue = '${dartValue}Value';
      buf.writeln('  $dartValue,');
    }
    buf.writeln('}');
    return _formatter.format(buf.toString());
  }

  /// Generate all model files.
  Map<String, String> generateAll() {
    final files = <String, String>{};
    for (final model in schema.models) {
      files['${toSnakeCase(model.name)}.dart'] = generateModel(model);
    }
    for (final enumDef in schema.enums) {
      files['${toSnakeCase(enumDef.name)}.dart'] = generateEnum(enumDef);
    }
    return files;
  }

  // === Helper methods (same logic as original) ===

  bool _isEnumType(String t) => schema.enums.any((e) => e.name == t);
  bool _isModelType(String t) => schema.models.any((m) => m.name == t);

  bool _isRelationField(PrismaField f) => f.isRelation || _isModelType(f.type);

  bool _isPrimitiveType(String t) => const {
        'String',
        'Int',
        'BigInt',
        'Float',
        'Decimal',
        'Boolean',
        'DateTime',
        'Json',
        'Bytes',
      }.contains(t);

  bool _isPrismaRuntimeDefault(String v) =>
      const {'uuid()', 'cuid()', 'now()', 'autoincrement()'}.contains(v) ||
      v.startsWith('dbgenerated(');

  bool _isDartReservedKeyword(String n) =>
      dartReservedKeywords.contains(n.toLowerCase());

  String _toDartType(String t) => switch (t) {
        'String' => 'String',
        'Int' => 'int',
        'BigInt' => 'BigInt',
        'Float' || 'Decimal' => 'double',
        'Boolean' => 'bool',
        'DateTime' => 'DateTime',
        'Json' => 'Map<String, dynamic>',
        'Bytes' => 'List<int>',
        _ => t,
      };

  String? _getFilterType(PrismaField field) {
    if (field.isList) {
      return switch (field.type) {
        'String' => 'StringListFilter',
        'Int' => 'IntListFilter',
        _ => null,
      };
    }
    return switch (field.type) {
      'String' => 'StringFilter',
      'Int' => 'IntFilter',
      'Float' || 'Decimal' => 'FloatFilter',
      'Boolean' => 'BooleanFilter',
      'DateTime' => 'DateTimeFilter',
      _ => _isEnumType(field.type) ? '${field.type}Filter' : null,
    };
  }
}
