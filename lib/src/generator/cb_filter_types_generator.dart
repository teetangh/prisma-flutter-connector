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
    ];

    final body = <Spec>[
      _filter(
        'StringFilter',
        'String',
        [
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
          // 'insensitive' → case-insensitive contains/startsWith/endsWith.
          _p('String?', 'mode'),
        ],
        // When mode is set, wrap the string-search operators as
        // {value, mode} so the compiler emits ILIKE (matches Prisma).
        toJsonBodyOverride: '''
          String? m = mode;
          Object? wrap(String? v) =>
              (v != null && m != null) ? <String, dynamic>{'value': v, 'mode': m} : v;
          return <String, dynamic>{
            if (equals != null) 'equals': equals,
            if (not != null) 'not': not,
            if (in_ != null) 'in': in_,
            if (notIn != null) 'notIn': notIn,
            if (contains != null) 'contains': wrap(contains),
            if (startsWith != null) 'startsWith': wrap(startsWith),
            if (endsWith != null) 'endsWith': wrap(endsWith),
            if (lt != null) 'lt': lt,
            if (lte != null) 'lte': lte,
            if (gt != null) 'gt': gt,
            if (gte != null) 'gte': gte,
          };
        ''',
      ),
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
      _filter('BigIntFilter', 'BigInt', [
        _p('BigInt?', 'equals'),
        _p('BigInt?', 'not'),
        _pJsonKey('List<BigInt>?', 'in_', 'in'),
        _p('List<BigInt>?', 'notIn'),
        _p('BigInt?', 'lt'),
        _p('BigInt?', 'lte'),
        _p('BigInt?', 'gt'),
        _p('BigInt?', 'gte'),
      ]),
      _filter('BytesFilter', 'Bytes', [
        _p('List<int>?', 'equals'),
        _p('List<int>?', 'not'),
      ]),
      _filter('JsonFilter', 'Json (PostgreSQL jsonb)', [
        _p('List<String>?', 'path'),
        _p('Object?', 'equals'),
        _pJsonKey('String?', 'stringContains', 'string_contains'),
        _pJsonKey('String?', 'stringStartsWith', 'string_starts_with'),
        _pJsonKey('String?', 'stringEndsWith', 'string_ends_with'),
        _pJsonKey('Object?', 'arrayContains', 'array_contains'),
        _p('Object?', 'lt'),
        _p('Object?', 'lte'),
        _p('Object?', 'gt'),
        _p('Object?', 'gte'),
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
      ..comments.addAll([
        '/// Generated filter types for type-safe queries',
        // @JsonKey on freezed constructor params (e.g. `in`, `string_contains`)
        // is a valid pattern but trips this lint; suppress it file-wide.
        'ignore_for_file: invalid_annotation_target',
      ])
      ..directives.addAll(directives)
      ..body.addAll(body));

    return _formatter.format('${library.accept(_emitter)}');
  }

  Class _filter(String name, String doc, List<Parameter> params,
      {String? toJsonBodyOverride}) {
    final toJsonBody = toJsonBodyOverride ?? _filterToJsonBody(params);
    return Class((b) => b
      ..name = name
      ..docs.add('/// Filter for $doc fields')
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
        ..body = Code(toJsonBody))));
  }

  /// Generate toJson body for a filter class.
  String _filterToJsonBody(List<Parameter> params) {
    final entries = <String>[];
    for (final p in params) {
      final name = p.name;
      final jsonKey = name == 'in_' ? 'in' : name;
      final typeStr = p.type?.symbol ?? '';
      entries.add(
          "if ($name != null) '$jsonKey': ${_filterValueExpr(name, typeStr)}");
    }
    return 'return <String, dynamic>{${entries.join(', ')},};';
  }

  /// Generate the value expression for a filter param in toJson.
  String _filterValueExpr(String name, String typeStr) {
    final cleanType = typeStr.replaceAll('?', '');

    if (cleanType == 'DateTime') return '$name!.toIso8601String()';
    if (cleanType.startsWith('List<DateTime>')) {
      return '$name!.map((e) => e.toIso8601String()).toList()';
    }
    if (cleanType == 'BigInt') return '$name!.toString()';
    if (cleanType.startsWith('List<BigInt>')) {
      return '$name!.map((e) => e.toString()).toList()';
    }

    // Check for enum types
    if (schema.enums.any((e) => e.name == cleanType)) {
      return '$name!.toJson()';
    }
    final listMatch = RegExp(r'List<(\w+)>').firstMatch(cleanType);
    if (listMatch != null &&
        schema.enums.any((e) => e.name == listMatch.group(1))) {
      return '$name!.map((e) => e.toJson()).toList()';
    }

    return name;
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
