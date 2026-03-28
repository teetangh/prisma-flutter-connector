/// Model generator using code_builder for type-safe AST generation.
///
/// Generates Freezed model files, input types, filter types, and enums
/// from Prisma schema definitions. All classes built with code_builder
/// Class/Constructor/Parameter builders — zero StringBuffer usage.
// ignore_for_file: prefer_const_constructors
library;

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates Freezed model files from Prisma models using code_builder.
class CbModelGenerator {
  final PrismaSchema schema;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
  final _emitter = DartEmitter(useNullSafetySyntax: true);

  CbModelGenerator(this.schema);

  String generateModel(PrismaModel model) {
    final sn = toSnakeCase(model.name);

    // Collect non-primitive type imports
    final typeImports = <String>{};
    for (final f in model.fields) {
      if (!_isPrimitiveType(f.type)) typeImports.add(f.type);
    }

    final directives = <Directive>[
      Directive.import('package:freezed_annotation/freezed_annotation.dart'),
      Directive.import('../filters.dart'),
      ...typeImports.map((t) => Directive.import('${toSnakeCase(t)}.dart')),
      Directive.part('$sn.freezed.dart'),
      Directive.part('$sn.g.dart'),
    ];

    final library = Library((b) => b
      ..directives.addAll(directives)
      ..body.addAll([
        _buildMainClass(model),
        _buildCreateInput(model),
        _buildUpdateInput(model),
        ..._buildWhereUniqueInput(model),
        _buildWhereInput(model),
        _buildListRelationFilter(model),
        _buildRelationFilter(model),
        _buildOrderByInput(model),
      ]));

    return _formatter.format('${library.accept(_emitter)}');
  }

  // === Main model class ===

  Class _buildMainClass(PrismaModel model) {
    final params = <Parameter>[];
    for (final f in model.fields) {
      params.add(_modelFieldToParam(f));
    }

    return Class((b) => b
      ..name = model.name
      ..annotations.add(refer('freezed'))
      ..mixins.add(refer('_\$${model.name}'))
      ..constructors.addAll([
        Constructor((c) => c
          ..factory = true
          ..constant = true
          ..redirect = refer('_${model.name}')
          ..optionalParameters.addAll(params)),
        Constructor((c) => c
          ..factory = true
          ..name = 'fromJson'
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'json'
            ..type = refer('Map<String, dynamic>')))
          ..body = Code('return _\$${model.name}FromJson(json);')),
      ]));
  }

  Parameter _modelFieldToParam(PrismaField f) {
    if (f.isRelation) {
      final type = f.isList ? 'List<${f.type}>' : f.type;
      return Parameter((p) => p
        ..name = f.name
        ..named = true
        ..annotations.add(CodeExpression(
            Code("JsonKey(includeFromJson: false, includeToJson: false)")))
        ..type = refer('$type?'));
    }

    final annotations = <Expression>[];
    if (f.dbName != null) {
      annotations.add(CodeExpression(Code("JsonKey(name: '${f.dbName}')")));
    }

    // Determine type and requiredness
    final dartType = _toDartType(f.type);
    String type;
    bool isRequired = false;

    if (f.hasEmptyListDefault && f.isList) {
      annotations.add(CodeExpression(Code('Default(<${f.type}>[])')));
      type = 'List<${f.type}>?';
    } else if (f.defaultValue != null && _isEnumType(f.type)) {
      annotations.add(CodeExpression(
          Code('Default(${f.type}.${toCamelCase(f.defaultValue!)})')));
      type = f.dartType;
    } else {
      final hasScalarDefault = f.defaultValue != null &&
          !f.isRelation &&
          !_isPrismaRuntimeDefault(f.defaultValue!);
      if (hasScalarDefault) {
        annotations.add(CodeExpression(Code('Default(${f.defaultValue})')));
        type = f.isList ? 'List<$dartType>' : dartType;
      } else if (f.isRequired && !f.isList) {
        type = dartType;
        isRequired = true;
      } else if (!f.isRequired && !f.isList) {
        type = '$dartType?';
      } else if (f.isList && f.isRequired) {
        type = 'List<$dartType>';
        isRequired = true;
      } else {
        type = 'List<$dartType>?';
      }
    }

    return Parameter((p) {
      p
        ..name = f.name
        ..named = true
        ..required = isRequired
        ..type = refer(type)
        ..annotations.addAll(annotations);
    });
  }

  // === CreateInput ===

  Class _buildCreateInput(PrismaModel model) {
    final params = <Parameter>[];
    for (final f in model.fields) {
      if (f.isId || f.isCreatedAt || f.isUpdatedAt || _isRelationField(f)) {
        continue;
      }
      params.add(_createInputParam(f));
    }

    return _freezedClass('Create${model.name}Input', params,
        doc: '/// Input for creating a new ${model.name}');
  }

  Parameter _createInputParam(PrismaField f) {
    final dartType = _toDartType(f.type);
    final annotations = <Expression>[];
    String type;
    bool isRequired = false;

    if (f.hasEmptyListDefault && f.isList) {
      annotations.add(CodeExpression(Code('Default(<$dartType>[])')));
      type = 'List<$dartType>?';
    } else if (f.defaultValue != null && _isEnumType(f.type)) {
      annotations.add(CodeExpression(
          Code('Default($dartType.${toCamelCase(f.defaultValue!)})')));
      type = dartType;
    } else if (f.isRequired && f.defaultValue == null) {
      type = f.isList ? 'List<$dartType>' : dartType;
      isRequired = true;
    } else if (f.defaultValue != null &&
        !_isPrismaRuntimeDefault(f.defaultValue!)) {
      annotations.add(CodeExpression(Code('Default(${f.defaultValue})')));
      type = f.isList ? 'List<$dartType>?' : '$dartType?';
    } else {
      type = f.isList ? 'List<$dartType>?' : '$dartType?';
    }

    return Parameter((p) => p
      ..name = f.name
      ..named = true
      ..required = isRequired
      ..type = refer(type)
      ..annotations.addAll(annotations));
  }

  // === UpdateInput ===

  Class _buildUpdateInput(PrismaModel model) {
    final params = <Parameter>[];
    for (final f in model.fields) {
      if (f.isId || f.isCreatedAt || f.isUpdatedAt || _isRelationField(f)) {
        continue;
      }
      final dartType = _toDartType(f.type);
      params.add(Parameter((p) => p
        ..name = f.name
        ..named = true
        ..type = refer(f.isList ? 'List<$dartType>?' : '$dartType?')));
    }

    return _freezedClass('Update${model.name}Input', params,
        doc: '/// Input for updating an existing ${model.name}');
  }

  // === WhereUniqueInput ===

  List<Spec> _buildWhereUniqueInput(PrismaModel model) {
    final uniqueFields =
        model.fields.where((f) => (f.isId || f.isUnique) && !f.isRelation);
    if (uniqueFields.isEmpty) return [];

    final params = uniqueFields.map((f) => Parameter((p) => p
      ..name = f.name
      ..named = true
      ..type = refer(f.isList ? 'List<${f.type}>?' : '${f.type}?')));

    return [_freezedClass('${model.name}WhereUniqueInput', params.toList())];
  }

  // === WhereInput ===

  Class _buildWhereInput(PrismaModel model) {
    final params = <Parameter>[];

    for (final f in model.fields) {
      if (f.isRelation) {
        final relType = f.isList
            ? '${f.type}ListRelationFilter'
            : '${f.type}RelationFilter';
        params.add(Parameter((p) => p
          ..name = f.name
          ..named = true
          ..type = refer('$relType?')));
        continue;
      }
      final filterType = _getFilterType(f);
      if (filterType != null) {
        params.add(Parameter((p) => p
          ..name = f.name
          ..named = true
          ..type = refer('$filterType?')));
      }
    }

    // Logical operators
    params.addAll([
      Parameter((p) => p
        ..name = 'AND'
        ..named = true
        ..type = refer('List<${model.name}WhereInput>?')),
      Parameter((p) => p
        ..name = 'OR'
        ..named = true
        ..type = refer('List<${model.name}WhereInput>?')),
      Parameter((p) => p
        ..name = 'NOT'
        ..named = true
        ..type = refer('${model.name}WhereInput?')),
    ]);

    final name = '${model.name}WhereInput';
    return Class((b) => b
      ..name = name
      ..annotations.add(refer('freezed'))
      ..mixins.add(refer('_\$$name'))
      ..constructors.addAll([
        Constructor((c) => c
          ..factory = true
          ..constant = true
          ..redirect = refer('_$name')
          ..annotations.add(
              CodeExpression(Code('JsonSerializable(explicitToJson: true)')))
          ..optionalParameters.addAll(params)),
        Constructor((c) => c
          ..factory = true
          ..name = 'fromJson'
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'json'
            ..type = refer('Map<String, dynamic>')))
          ..body = Code('return _\$${name}FromJson(json);')),
      ]));
  }

  // === Relation filters ===

  Class _buildListRelationFilter(PrismaModel model) {
    final name = '${model.name}ListRelationFilter';
    final wt = '${model.name}WhereInput?';
    return _freezedClass(name, [
      Parameter((p) => p
        ..name = 'some'
        ..named = true
        ..type = refer(wt)),
      Parameter((p) => p
        ..name = 'every'
        ..named = true
        ..type = refer(wt)),
      Parameter((p) => p
        ..name = 'none'
        ..named = true
        ..type = refer(wt)),
    ]);
  }

  Class _buildRelationFilter(PrismaModel model) {
    final name = '${model.name}RelationFilter';
    final wt = '${model.name}WhereInput?';
    return _freezedClass(name, [
      Parameter((p) => p
        ..name = 'is_'
        ..named = true
        ..annotations.add(CodeExpression(Code("JsonKey(name: 'is')")))
        ..type = refer(wt)),
      Parameter((p) => p
        ..name = 'isNot'
        ..named = true
        ..type = refer(wt)),
    ]);
  }

  // === OrderByInput ===

  Class _buildOrderByInput(PrismaModel model) {
    final sortableFields = model.fields.where((f) =>
        !f.isRelation &&
        (f.type == 'String' ||
            f.type == 'Int' ||
            f.type == 'Float' ||
            f.type == 'DateTime' ||
            f.type == 'Boolean' ||
            f.isCreatedAt ||
            f.isUpdatedAt));

    final params = sortableFields
        .map((f) => Parameter((p) => p
          ..name = f.name
          ..named = true
          ..type = refer('SortOrder?')))
        .toList();

    return _freezedClass('${model.name}OrderByInput', params);
  }

  // === Shared: build a @freezed class ===

  Class _freezedClass(String name, List<Parameter> params, {String? doc}) {
    return Class((b) {
      if (doc != null) b.docs.add(doc);
      b
        ..name = name
        ..annotations.add(refer('freezed'))
        ..mixins.add(refer('_\$$name'))
        ..constructors.addAll([
          Constructor((c) => c
            ..factory = true
            ..constant = true
            ..redirect = refer('_$name')
            ..optionalParameters.addAll(params)),
          Constructor((c) => c
            ..factory = true
            ..name = 'fromJson'
            ..requiredParameters.add(Parameter((p) => p
              ..name = 'json'
              ..type = refer('Map<String, dynamic>')))
            ..body = Code('return _\$${name}FromJson(json);')),
        ]);
    });
  }

  // === Enum generation ===

  String generateEnum(PrismaEnum enumDef) {
    final values = enumDef.values.map((v) {
      var dartValue = toCamelCase(v);
      if (_isDartReservedKeyword(dartValue)) dartValue = '${dartValue}Value';
      return EnumValue((ev) => ev
        ..name = dartValue
        ..annotations.add(CodeExpression(Code("JsonValue('$v')"))));
    });

    final lib = Library((b) => b
      ..directives.add(Directive.import(
          'package:freezed_annotation/freezed_annotation.dart'))
      ..body.add(Enum((e) => e
        ..name = enumDef.name
        ..values.addAll(values))));

    return _formatter.format('${lib.accept(_emitter)}');
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

  // === Helpers ===

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

  String? _getFilterType(PrismaField f) {
    if (f.isList) {
      return switch (f.type) {
        'String' => 'StringListFilter',
        'Int' => 'IntListFilter',
        _ => null,
      };
    }
    return switch (f.type) {
      'String' => 'StringFilter',
      'Int' => 'IntFilter',
      'Float' || 'Decimal' => 'FloatFilter',
      'Boolean' => 'BooleanFilter',
      'DateTime' => 'DateTimeFilter',
      _ => _isEnumType(f.type) ? '${f.type}Filter' : null,
    };
  }
}
