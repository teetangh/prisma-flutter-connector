/// Filter types generator using code_builder — zero StringBuffer usage.
// ignore_for_file: prefer_const_constructors
library;

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates filter type classes using code_builder AST.
class CbFilterTypesGenerator {
  final PrismaSchema schema;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
  final _emitter = DartEmitter(useNullSafetySyntax: true);

  CbFilterTypesGenerator(this.schema);

  String generate() {
    final directives = <Directive>[
      Directive.import('package:freezed_annotation/freezed_annotation.dart'),
      ...schema.enums
          .map((e) => Directive.import('models/${toSnakeCase(e.name)}.dart')),
      Directive.part('filters.freezed.dart'),
      Directive.part('filters.g.dart'),
    ];

    final body = <Spec>[
      _filter('StringFilter', 'String', [
        _p('String?', 'equals'),
        _p('String?', 'not'),
        _pJsonKey('List<String>?', 'in_', 'in'),
        _p('List<String>?', 'notIn'),
        _p('String?', 'contains'),
        _p('String?', 'startsWith'),
        _p('String?', 'endsWith'),
        _p('String?', 'lt'),
        _p('String?', 'lte'),
        _p('String?', 'gt'),
        _p('String?', 'gte'),
      ]),
      _filter('IntFilter', 'Int', [
        _p('int?', 'equals'),
        _p('int?', 'not'),
        _pJsonKey('List<int>?', 'in_', 'in'),
        _p('List<int>?', 'notIn'),
        _p('int?', 'lt'),
        _p('int?', 'lte'),
        _p('int?', 'gt'),
        _p('int?', 'gte'),
      ]),
      _filter('FloatFilter', 'Float/Decimal', [
        _p('double?', 'equals'),
        _p('double?', 'not'),
        _pJsonKey('List<double>?', 'in_', 'in'),
        _p('List<double>?', 'notIn'),
        _p('double?', 'lt'),
        _p('double?', 'lte'),
        _p('double?', 'gt'),
        _p('double?', 'gte'),
      ]),
      _filter('BooleanFilter', 'Boolean', [
        _p('bool?', 'equals'),
        _p('bool?', 'not'),
      ]),
      _filter('DateTimeFilter', 'DateTime', [
        _p('DateTime?', 'equals'),
        _p('DateTime?', 'not'),
        _pJsonKey('List<DateTime>?', 'in_', 'in'),
        _p('List<DateTime>?', 'notIn'),
        _p('DateTime?', 'lt'),
        _p('DateTime?', 'lte'),
        _p('DateTime?', 'gt'),
        _p('DateTime?', 'gte'),
      ]),
      ...schema.enums.map((e) => _filter('${e.name}Filter', e.name, [
            _p('${e.name}?', 'equals'),
            _p('${e.name}?', 'not'),
            _pJsonKey('List<${e.name}>?', 'in_', 'in'),
            _p('List<${e.name}>?', 'notIn'),
          ])),
      _filter('StringListFilter', 'String list', [
        _p('String?', 'has'),
        _p('List<String>?', 'hasEvery'),
        _p('List<String>?', 'hasSome'),
        _p('bool?', 'isEmpty'),
      ]),
      _filter('IntListFilter', 'Int list', [
        _p('int?', 'has'),
        _p('List<int>?', 'hasEvery'),
        _p('List<int>?', 'hasSome'),
        _p('bool?', 'isEmpty'),
      ]),
      Enum((b) => b
        ..name = 'SortOrder'
        ..docs.add('/// Sort order for ordering results')
        ..values.addAll([
          EnumValue((v) => v
            ..name = 'asc'
            ..annotations.add(CodeExpression(Code("JsonValue('asc')")))),
          EnumValue((v) => v
            ..name = 'desc'
            ..annotations.add(CodeExpression(Code("JsonValue('desc')")))),
        ])),
    ];

    final library = Library((b) => b
      ..comments.add('/// Generated filter types for type-safe queries')
      ..directives.addAll(directives)
      ..body.addAll(body));

    return _formatter.format('${library.accept(_emitter)}');
  }

  Class _filter(String name, String doc, List<Parameter> params) {
    return Class((b) => b
      ..name = name
      ..docs.add('/// Filter for $doc fields')
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
      ]));
  }

  Parameter _p(String type, String name) => Parameter((p) => p
    ..name = name
    ..named = true
    ..type = refer(type));

  Parameter _pJsonKey(String type, String name, String jsonName) =>
      Parameter((p) => p
        ..name = name
        ..named = true
        ..type = refer(type)
        ..annotations.add(CodeExpression(Code("JsonKey(name: '$jsonName')"))));
}
