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

    // Collect non-primitive type imports (excluding the model's own type,
    // which would be a redundant self-import for self-relations).
    final typeImports = <String>{};
    for (final f in model.fields) {
      if (!_isPrimitiveType(f.type) && f.type != model.name) {
        typeImports.add(f.type);
      }
    }

    final directives = <Directive>[
      Directive.import('package:freezed_annotation/freezed_annotation.dart'),
      Directive.import('../filters.dart'),
      ...typeImports.map((t) => Directive.import('${toSnakeCase(t)}.dart')),
      Directive.part('$sn.freezed.dart'),
    ];

    final library = Library((b) => b
      ..comments.add(
        // @JsonKey on freezed constructor params (@map columns, relation
        // fields) is a valid pattern that trips this lint; suppress file-wide.
        'ignore_for_file: invalid_annotation_target',
      )
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
        _buildInclude(model),
        ..._buildRelationWriteInputs(model),
        ..._buildEnumConverters(model),
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
          ..constant = true
          ..name = '_'),
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
          ..body = Code(_generateFromJsonBody(model))),
      ])
      ..methods.add(Method((m) => m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code(_generateToJsonBody(model)))));
  }

  // === Manual fromJson ===

  /// Generate manual fromJson body for the main model class.
  ///
  /// Relation fields ARE hydrated when present in the JSON (produced by an
  /// `include`): the RelationDeserializer nests related rows under the
  /// relation key, and here we deserialize them into the typed relation
  /// model. Absent keys (no include) leave the relation null / empty.
  String _generateFromJsonBody(PrismaModel model) {
    final args = <String>[];
    for (final f in model.fields) {
      if (f.isRelation) {
        args.add('${f.name}: ${_relationFromJsonExpr(f)}');
        continue;
      }
      final dartType = _toDartType(f.type);
      final key = f.dbName ?? f.name;
      args.add('${f.name}: ${_fromJsonExpr(f, key, dartType)}');
    }
    return 'return ${model.name}(${args.join(', ')},);';
  }

  /// fromJson expression for a relation field (nested typed model / list).
  String _relationFromJsonExpr(PrismaField f) {
    final key = f.name; // relation keys are not @map-ed
    if (f.isList) {
      return "(json['$key'] as List?)"
          "?.map((e) => ${f.type}.fromJson(e as Map<String, dynamic>))"
          ".toList() ?? const []";
    }
    return "json['$key'] != null "
        "? ${f.type}.fromJson(json['$key'] as Map<String, dynamic>) "
        ": null";
  }

  /// Generate a fromJson expression for a single field.
  String _fromJsonExpr(PrismaField f, String key, String dartType) {
    // Fields with @Default values may be absent in JSON — treat as optional with fallback
    final hasDefault = f.defaultValue != null &&
        !_isPrismaRuntimeDefault(f.defaultValue!) &&
        !_isEnumType(f.type);
    final effectiveRequired = f.isRequired && !hasDefault;
    if (f.isList) {
      if (_isEnumType(f.type)) {
        return effectiveRequired
            ? "(json['$key'] as List).map((e) => _\$${f.type}FromJson(e as String)).toList()"
            : "(json['$key'] as List?)?.map((e) => _\$${f.type}FromJson(e as String)).toList()";
      }
      final defaultSuffix = hasDefault ? ' ?? ${f.defaultValue}' : '';
      return effectiveRequired
          ? "(json['$key'] as List).cast<$dartType>()"
          : "(json['$key'] as List?)?.cast<$dartType>()$defaultSuffix";
    }

    if (_isEnumType(f.type)) {
      // Use _fromJsonEnum helper that matches DB values (SCREAMING_CASE) to Dart values
      final enumName = f.type;
      if (f.defaultValue != null) {
        var dartDefault = toCamelCase(f.defaultValue!);
        if (_isDartReservedKeyword(dartDefault)) {
          dartDefault = '${dartDefault}Value';
        }
        final def = '$enumName.$dartDefault';
        return "json['$key'] != null ? _\$${enumName}FromJson(json['$key'] as String) : $def";
      }
      return effectiveRequired
          ? "_\$${enumName}FromJson(json['$key'] as String)"
          : "json['$key'] != null ? _\$${enumName}FromJson(json['$key'] as String) : null";
    }

    // BigInt cannot use @Default (no const constructor), so fields with a
    // literal default are required in the Dart class and fromJson supplies
    // the fallback. BigInt.parse on a string literal is precision-safe on
    // all platforms (BigInt.from would round through a JS double on web).
    if (dartType == 'BigInt') {
      final parse = "BigInt.parse(json['$key'].toString())";
      if (hasDefault) {
        return "json['$key'] != null ? $parse : BigInt.parse('${f.defaultValue}')";
      }
      return f.isRequired ? parse : "json['$key'] != null ? $parse : null";
    }

    final defaultSuffix = hasDefault ? ' ?? ${f.defaultValue}' : '';
    return switch (dartType) {
      'String' => effectiveRequired
          ? "json['$key'] as String"
          : "(json['$key'] as String?)$defaultSuffix",
      'int' => effectiveRequired
          ? "(json['$key'] as num).toInt()"
          : "(json['$key'] as num?)?.toInt()$defaultSuffix",
      'double' => effectiveRequired
          ? "(json['$key'] as num).toDouble()"
          : "(json['$key'] as num?)?.toDouble()$defaultSuffix",
      'bool' => effectiveRequired
          ? "json['$key'] as bool"
          : "(json['$key'] as bool?)$defaultSuffix",
      'DateTime' => effectiveRequired
          ? "json['$key'] is DateTime ? json['$key'] as DateTime : DateTime.parse(json['$key'] as String)"
          : "json['$key'] != null ? (json['$key'] is DateTime ? json['$key'] as DateTime : DateTime.parse(json['$key'] as String)) : null",
      'Map<String, dynamic>' => f.isRequired
          ? "json['$key'] as Map<String, dynamic>"
          : "json['$key'] as Map<String, dynamic>?",
      _ => "json['$key'] as $dartType${f.isRequired ? '' : '?'}",
    };
  }

  // === Manual toJson ===

  /// Generate manual toJson body for the main model class.
  String _generateToJsonBody(PrismaModel model) {
    final entries = <String>[];
    for (final f in model.fields) {
      if (f.isRelation) continue;
      final key = f.dbName ?? f.name;
      entries.add("'$key': ${_toJsonExpr(f)}");
    }
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  /// Generate a toJson expression for a single model field.
  String _toJsonExpr(PrismaField f) {
    final dartType = _toDartType(f.type);
    final name = f.name;
    final nullable = _isFieldNullableInModel(f);
    final q = nullable ? '?' : '';

    if (f.isList) {
      if (_isEnumType(f.type)) {
        return '$name$q.map((e) => _\$${f.type}ToJson(e)).toList()';
      }
      return name;
    }

    if (_isEnumType(f.type)) {
      return '_\$${f.type}ToJson($name)';
    }

    return switch (dartType) {
      'DateTime' => '$name$q.toIso8601String()',
      'BigInt' => '$name$q.toString()',
      _ => name,
    };
  }

  /// Whether a model field is nullable in the generated Dart class.
  bool _isFieldNullableInModel(PrismaField f) {
    if (f.isRelation) return true;
    if (f.hasEmptyListDefault && f.isList) return true;
    // Enum with default but not required → type is still nullable (UserRole?)
    if (f.defaultValue != null && _isEnumType(f.type)) return !f.isRequired;
    final hasScalarDefault = f.defaultValue != null &&
        !f.isRelation &&
        !_isPrismaRuntimeDefault(f.defaultValue!);
    if (hasScalarDefault) return false;
    if (f.isRequired) return false;
    return true;
  }

  /// Generate toJson body for CreateInput or UpdateInput.
  String _generateInputToJsonBody(PrismaModel model,
      {required bool allNullable}) {
    final entries = <String>[];
    for (final f in model.fields) {
      if (f.isId || f.isCreatedAt || f.isUpdatedAt || _isRelationField(f)) {
        continue;
      }
      final name = f.name;
      final dartType = _toDartType(f.type);
      final nullable = allNullable || _isCreateInputFieldNullable(f);
      final q = nullable ? '?' : '';

      String expr;
      if (f.isList && _isEnumType(f.type)) {
        expr = '$name$q.map((e) => _\$${f.type}ToJson(e)).toList()';
      } else if (_isEnumType(f.type)) {
        expr = '_\$${f.type}ToJson($name)';
      } else if (dartType == 'DateTime') {
        expr = '$name$q.toIso8601String()';
      } else if (dartType == 'BigInt') {
        expr = '$name$q.toString()';
      } else {
        expr = name;
      }

      if (nullable) {
        entries.add("if ($name != null) '$name': $expr");
      } else {
        entries.add("'$name': $expr");
      }
    }
    // Nested relation writes (create/connect/disconnect) are always optional.
    for (final f in model.fields.where((f) => f.isRelation)) {
      entries.add("if (${f.name} != null) '${f.name}': ${f.name}!.toJson()");
    }
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  /// Whether a CreateInput field is nullable in the generated Dart class.
  bool _isCreateInputFieldNullable(PrismaField f) {
    if (f.hasEmptyListDefault && f.isList) return true;
    if (f.defaultValue != null && _isEnumType(f.type)) return false;
    if (f.isRequired && f.defaultValue == null) return false;
    return true;
  }

  /// Generate toJson body for WhereUniqueInput.
  ///
  /// Compound keys are FLATTENED into their individual field equalities, so
  /// the SQL compiler needs no compound-key awareness: findUnique/update/
  /// delete get `col_a = ? AND col_b = ?` and upsert gets the right
  /// `ON CONFLICT (col_a, col_b)`.
  String _generateWhereUniqueToJsonBody(PrismaModel model) {
    final uniqueFields =
        model.fields.where((f) => (f.isId || f.isUnique) && !f.isRelation);
    final entries = <String>[];
    for (final f in uniqueFields) {
      entries.add("if (${f.name} != null) '${f.name}': ${f.name}");
    }
    for (final key in model.compositeUniques) {
      final fieldName = key.join('_');
      entries.add('if ($fieldName != null) ...$fieldName!.toJson()');
    }
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  /// The generated compound-unique input type name, e.g.
  /// `OrgInvoiceCounterOrganizationIdFiscalYearCompoundUnique`.
  String _compoundTypeName(PrismaModel model, List<String> key) =>
      '${model.name}${key.map((k) => k[0].toUpperCase() + k.substring(1)).join()}CompoundUnique';

  /// Generate toJson body for WhereInput.
  String _generateWhereInputToJsonBody(PrismaModel model) {
    final entries = <String>[];
    for (final f in model.fields) {
      if (f.isRelation) {
        entries.add("if (${f.name} != null) '${f.name}': ${f.name}!.toJson()");
        continue;
      }
      if (_getFilterType(f) != null) {
        entries.add("if (${f.name} != null) '${f.name}': ${f.name}!.toJson()");
      }
    }
    entries.add("if (AND != null) 'AND': AND!.map((e) => e.toJson()).toList()");
    entries.add("if (OR != null) 'OR': OR!.map((e) => e.toJson()).toList()");
    entries.add("if (NOT != null) 'NOT': NOT!.toJson()");
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  /// Generate toJson body for OrderByInput.
  String _generateOrderByToJsonBody(PrismaModel model) {
    final sortableFields = model.fields.where((f) =>
        !f.isRelation &&
        (f.type == 'String' ||
            f.type == 'Int' ||
            f.type == 'Float' ||
            f.type == 'DateTime' ||
            f.type == 'Boolean' ||
            f.isCreatedAt ||
            f.isUpdatedAt));
    final entries = <String>[];
    for (final f in sortableFields) {
      entries.add("if (${f.name} != null) '${f.name}': ${f.name}!.name");
    }
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  // === Field parameter builders ===

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
      var enumVal = toCamelCase(f.defaultValue!);
      if (_isDartReservedKeyword(enumVal)) enumVal = '${enumVal}Value';
      annotations.add(CodeExpression(Code('Default(${f.type}.$enumVal)')));
      type = f.dartType;
    } else {
      final hasScalarDefault = f.defaultValue != null &&
          !f.isRelation &&
          !_isPrismaRuntimeDefault(f.defaultValue!);
      if (hasScalarDefault && dartType == 'BigInt') {
        // BigInt has no const constructor → @Default is impossible; the
        // fromJson fallback (BigInt.from) supplies the schema default
        type = dartType;
        isRequired = true;
      } else if (hasScalarDefault) {
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
    _addRelationWriteParams(model, params);

    return _freezedClass('Create${model.name}Input', params,
        doc: '/// Input for creating a new ${model.name}',
        toJsonBody: _generateInputToJsonBody(model, allNullable: false));
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
      var enumVal = toCamelCase(f.defaultValue!);
      if (_isDartReservedKeyword(enumVal)) enumVal = '${enumVal}Value';
      annotations.add(CodeExpression(Code('Default($dartType.$enumVal)')));
      type = dartType;
    } else if (f.isRequired && f.defaultValue == null) {
      type = f.isList ? 'List<$dartType>' : dartType;
      isRequired = true;
    } else if (f.defaultValue != null &&
        !_isPrismaRuntimeDefault(f.defaultValue!)) {
      if (dartType != 'BigInt') {
        // BigInt has no const constructor → no @Default; leave the field
        // nullable and let the database apply the schema default
        annotations.add(CodeExpression(Code('Default(${f.defaultValue})')));
      }
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
    _addRelationWriteParams(model, params);

    return _freezedClass('Update${model.name}Input', params,
        doc: '/// Input for updating an existing ${model.name}',
        toJsonBody: _generateInputToJsonBody(model, allNullable: true));
  }

  // === WhereUniqueInput ===

  List<Spec> _buildWhereUniqueInput(PrismaModel model) {
    final uniqueFields = model.fields
        .where((f) => (f.isId || f.isUnique) && !f.isRelation)
        .toList();
    final composites = model.compositeUniques;
    if (uniqueFields.isEmpty && composites.isEmpty) return [];

    final specs = <Spec>[];
    final params = <Parameter>[];

    for (final f in uniqueFields) {
      params.add(Parameter((p) => p
        ..name = f.name
        ..named = true
        ..type = refer(f.isList ? 'List<${f.type}>?' : '${f.type}?')));
    }

    // One compound-unique input class per @@id/@@unique composite key.
    for (final key in composites) {
      final typeName = _compoundTypeName(model, key);
      params.add(Parameter((p) => p
        ..name = key.join('_')
        ..named = true
        ..type = refer('$typeName?')));

      final compoundParams = <Parameter>[];
      final entries = <String>[];
      for (final fieldName in key) {
        final f = model.fields.firstWhere((mf) => mf.name == fieldName,
            orElse: () => throw StateError(
                'Composite key field "$fieldName" not found on ${model.name}'));
        compoundParams.add(Parameter((p) => p
          ..name = fieldName
          ..named = true
          ..required = true
          ..type = refer(_toDartType(f.type))));
        entries.add("'$fieldName': $fieldName");
      }
      specs.add(_freezedClass(typeName, compoundParams,
          doc: '/// Compound unique key ($key) for ${model.name}',
          toJsonBody: 'return <String, dynamic>{${entries.join(', ')},};'));
    }

    specs.add(_freezedClass('${model.name}WhereUniqueInput', params,
        toJsonBody: _generateWhereUniqueToJsonBody(model)));
    return specs;
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
          ..constant = true
          ..name = '_'),
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
          ..body =
              Code("throw UnimplementedError('$name.fromJson not needed');")),
      ])
      ..methods.add(Method((m) => m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>')
        ..body = Code(_generateWhereInputToJsonBody(model)))));
  }

  // === Relation filters ===

  Class _buildListRelationFilter(PrismaModel model) {
    final name = '${model.name}ListRelationFilter';
    final wt = '${model.name}WhereInput?';
    return _freezedClass(
        name,
        [
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
        ],
        toJsonBody: "return <String, dynamic>{"
            "if (some != null) 'some': some!.toJson(), "
            "if (every != null) 'every': every!.toJson(), "
            "if (none != null) 'none': none!.toJson(),"
            "};");
  }

  Class _buildRelationFilter(PrismaModel model) {
    final name = '${model.name}RelationFilter';
    final wt = '${model.name}WhereInput?';
    return _freezedClass(
        name,
        [
          Parameter((p) => p
            ..name = 'is_'
            ..named = true
            ..annotations.add(CodeExpression(Code("JsonKey(name: 'is')")))
            ..type = refer(wt)),
          Parameter((p) => p
            ..name = 'isNot'
            ..named = true
            ..type = refer(wt)),
        ],
        toJsonBody: "return <String, dynamic>{"
            "if (is_ != null) 'is': is_!.toJson(), "
            "if (isNot != null) 'isNot': isNot!.toJson(),"
            "};");
  }

  // === Nested relation write inputs (create/connect/disconnect) ===

  String _relationWriteTypeName(PrismaModel model, PrismaField f) =>
      '${model.name}${f.name[0].toUpperCase()}${f.name.substring(1)}WriteInput';

  /// Append one optional nested-write param per relation to a Create/Update
  /// input's param list, typed to the relation's `${...}WriteInput` class.
  void _addRelationWriteParams(PrismaModel model, List<Parameter> params) {
    for (final f in model.fields.where((f) => f.isRelation)) {
      params.add(Parameter((p) => p
        ..name = f.name
        ..named = true
        ..type = refer('${_relationWriteTypeName(model, f)}?')));
    }
  }

  /// Whether the related model exposes a WhereUniqueInput (field-level unique
  /// or a composite key) — required for connect/disconnect.
  bool _relatedHasWhereUnique(String relatedModel) {
    final m = schema.models.where((m) => m.name == relatedModel).firstOrNull;
    if (m == null) return false;
    return m.fields.any((f) => (f.isId || f.isUnique) && !f.isRelation) ||
        m.compositeUniques.isNotEmpty;
  }

  /// One nested-write input per relation: `connect`/`disconnect` (when the
  /// related model has a unique key) and `create`. toJson yields the shape the
  /// relation-mutation compiler consumes.
  List<Spec> _buildRelationWriteInputs(PrismaModel model) {
    final specs = <Spec>[];
    for (final f in model.fields.where((f) => f.isRelation)) {
      final related = f.type;
      final canConnect = _relatedHasWhereUnique(related);
      final params = <Parameter>[];
      final entries = <String>[];

      if (f.isList) {
        if (canConnect) {
          params.add(Parameter((p) => p
            ..name = 'connect'
            ..named = true
            ..type = refer('List<${related}WhereUniqueInput>?')));
          params.add(Parameter((p) => p
            ..name = 'disconnect'
            ..named = true
            ..type = refer('List<${related}WhereUniqueInput>?')));
          entries.add(
              "if (connect != null) 'connect': connect!.map((e) => e.toJson()).toList()");
          entries.add(
              "if (disconnect != null) 'disconnect': disconnect!.map((e) => e.toJson()).toList()");
        }
        params.add(Parameter((p) => p
          ..name = 'create'
          ..named = true
          ..type = refer('List<Create${related}Input>?')));
        entries.add(
            "if (create != null) 'create': create!.map((e) => e.toJson()).toList()");
      } else {
        if (canConnect) {
          params.add(Parameter((p) => p
            ..name = 'connect'
            ..named = true
            ..type = refer('${related}WhereUniqueInput?')));
          entries.add("if (connect != null) 'connect': connect!.toJson()");
        }
        params.add(Parameter((p) => p
          ..name = 'create'
          ..named = true
          ..type = refer('Create${related}Input?')));
        entries.add("if (create != null) 'create': create!.toJson()");
      }

      specs.add(_freezedClass(_relationWriteTypeName(model, f), params,
          doc: '/// Nested write for ${model.name}.${f.name}',
          toJsonBody: 'return <String, dynamic>{${entries.join(', ')},};'));
    }
    return specs;
  }

  // === Include (typed relation selection) ===

  /// Typed include class: one `${RelatedModel}Include?` field per relation.
  /// A non-null nested include includes that relation (empty = include with no
  /// deeper relations); toJson yields the compiler's include-map shape.
  Class _buildInclude(PrismaModel model) {
    final relations = model.fields.where((f) => f.isRelation).toList();
    final params = <Parameter>[];
    // Statement-style toJson (no runtime helper): an empty nested include
    // serializes to `true` (include, no deeper relations); a non-empty one
    // nests via {'include': ...}, matching the relation compiler's shape.
    final stmts = <String>['final map = <String, dynamic>{};'];
    for (final f in relations) {
      params.add(Parameter((p) => p
        ..name = f.name
        ..named = true
        ..type = refer('${f.type}Include?')));
      stmts.add("if (${f.name} != null) {"
          " final n = ${f.name}!.toJson();"
          " map['${f.name}'] = n.isEmpty ? true : <String, dynamic>{'include': n};"
          " }");
    }
    stmts.add('return map;');
    return _freezedClass('${model.name}Include', params,
        doc: '/// Typed include for ${model.name} relations',
        toJsonBody: stmts.join('\n'));
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

    return _freezedClass('${model.name}OrderByInput', params,
        toJsonBody: _generateOrderByToJsonBody(model));
  }

  // === Shared: build a @freezed class ===

  Class _freezedClass(String name, List<Parameter> params,
      {String? doc, required String toJsonBody}) {
    return Class((b) {
      if (doc != null) b.docs.add(doc);
      b
        ..name = name
        ..annotations.add(refer('freezed'))
        ..mixins.add(refer('_\$$name'))
        ..constructors.addAll([
          Constructor((c) => c
            ..constant = true
            ..name = '_'),
          Constructor((c) => c
            ..factory = true
            ..constant = true
            ..redirect = refer('_$name')
            ..optionalParameters.addAll(params)),
          // Stub fromJson — input/filter types are serialized TO JSON
          // (for queries), rarely FROM JSON.
          Constructor((c) => c
            ..factory = true
            ..name = 'fromJson'
            ..requiredParameters.add(Parameter((p) => p
              ..name = 'json'
              ..type = refer('Map<String, dynamic>')))
            ..body =
                Code("throw UnimplementedError('$name.fromJson not needed');")),
        ])
        ..methods.add(Method((m) => m
          ..name = 'toJson'
          ..returns = refer('Map<String, dynamic>')
          ..body = Code(toJsonBody)));
    });
  }

  // === Enum generation ===

  String generateEnum(PrismaEnum enumDef) {
    final values = <EnumValue>[];
    final switchCases = <String>[];

    for (final v in enumDef.values) {
      var dartValue = toCamelCase(v);
      if (_isDartReservedKeyword(dartValue)) dartValue = '${dartValue}Value';
      values.add(EnumValue((ev) => ev
        ..name = dartValue
        ..annotations.add(CodeExpression(Code("JsonValue('$v')")))));
      switchCases.add("${enumDef.name}.$dartValue => '$v'");
    }

    final lib = Library((b) => b
      ..directives.add(Directive.import(
          'package:freezed_annotation/freezed_annotation.dart'))
      ..body.add(Enum((e) => e
        ..name = enumDef.name
        ..values.addAll(values)
        ..methods.add(Method((m) => m
          ..name = 'toJson'
          ..returns = refer('String')
          ..body =
              Code('return switch (this) {${switchCases.join(', ')},};'))))));

    return _formatter.format('${lib.accept(_emitter)}');
  }

  /// Generate enum converter functions for enums used in this model.
  List<Spec> _buildEnumConverters(PrismaModel model) {
    // Collect unique enum types used in this model
    final enumTypes = <String>{};
    for (final f in model.fields) {
      if (!f.isRelation && _isEnumType(f.type)) {
        enumTypes.add(f.type);
      }
    }

    final specs = <Spec>[];
    for (final enumName in enumTypes) {
      final enumDef = schema.enums.where((e) => e.name == enumName).firstOrNull;
      if (enumDef == null) continue;

      // Build value→dart map entries: 'PENDING' => EnumName.pending
      final fromEntries = <String>[];
      final toEntries = <String>[];
      for (final v in enumDef.values) {
        var dartValue = toCamelCase(v);
        if (_isDartReservedKeyword(dartValue)) dartValue = '${dartValue}Value';
        fromEntries.add("'$v' => $enumName.$dartValue");
        toEntries.add("$enumName.$dartValue => '$v'");
      }

      // _$EnumNameFromJson
      specs.add(Method((m) => m
        ..name = '_\$${enumName}FromJson'
        ..returns = refer(enumName)
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'value'
          ..type = refer('String')))
        ..body = Code(
            'return switch (value) {${fromEntries.join(', ')}, _ => throw ArgumentError(\'Unknown $enumName: \$value\'),};')));

      // _$EnumNameToJson (handles nullable)
      specs.add(Method((m) => m
        ..name = '_\$${enumName}ToJson'
        ..returns = refer('String?')
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'value'
          ..type = refer('$enumName?')))
        ..body = Code(
            'if (value == null) return null; return switch (value) {${toEntries.join(', ')},};')));
    }

    return specs;
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
      'Json' => 'JsonFilter',
      'BigInt' => 'BigIntFilter',
      'Bytes' => 'BytesFilter',
      _ => _isEnumType(f.type) ? '${f.type}Filter' : null,
    };
  }
}
