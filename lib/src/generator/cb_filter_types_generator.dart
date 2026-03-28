/// Filter types generator using code_builder for auto-formatted output.
// ignore_for_file: prefer_const_constructors
library;

import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates filter type classes (StringFilter, IntFilter, etc.)
/// using dart_style for auto-formatting.
class CbFilterTypesGenerator {
  final PrismaSchema schema;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  CbFilterTypesGenerator(this.schema);

  String generate() {
    final buf = StringBuffer();

    buf.writeln('/// Generated filter types for type-safe queries');
    buf.writeln('library;');
    buf.writeln();
    buf.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buf.writeln();

    for (final enumDef in schema.enums) {
      buf.writeln("import 'models/${toSnakeCase(enumDef.name)}.dart';");
    }
    if (schema.enums.isNotEmpty) buf.writeln();

    buf.writeln("part 'filters.freezed.dart';");
    buf.writeln("part 'filters.g.dart';");
    buf.writeln();

    // Core filters
    buf.write(_freezedFilter('StringFilter', 'String', [
      'String? equals',
      'String? not',
      "@JsonKey(name: 'in') List<String>? in_",
      'List<String>? notIn',
      'String? contains',
      'String? startsWith',
      'String? endsWith',
      'String? lt',
      'String? lte',
      'String? gt',
      'String? gte',
    ]));

    buf.write(_freezedFilter('IntFilter', 'Int', [
      'int? equals',
      'int? not',
      "@JsonKey(name: 'in') List<int>? in_",
      'List<int>? notIn',
      'int? lt',
      'int? lte',
      'int? gt',
      'int? gte',
    ]));

    buf.write(_freezedFilter('FloatFilter', 'Float/Decimal', [
      'double? equals',
      'double? not',
      "@JsonKey(name: 'in') List<double>? in_",
      'List<double>? notIn',
      'double? lt',
      'double? lte',
      'double? gt',
      'double? gte',
    ]));

    buf.write(_freezedFilter('BooleanFilter', 'Boolean', [
      'bool? equals',
      'bool? not',
    ]));

    buf.write(_freezedFilter('DateTimeFilter', 'DateTime', [
      'DateTime? equals',
      'DateTime? not',
      "@JsonKey(name: 'in') List<DateTime>? in_",
      'List<DateTime>? notIn',
      'DateTime? lt',
      'DateTime? lte',
      'DateTime? gt',
      'DateTime? gte',
    ]));

    // Enum filters
    for (final enumDef in schema.enums) {
      buf.write(_freezedFilter('${enumDef.name}Filter', enumDef.name, [
        '${enumDef.name}? equals',
        '${enumDef.name}? not',
        "@JsonKey(name: 'in') List<${enumDef.name}>? in_",
        'List<${enumDef.name}>? notIn',
      ]));
    }

    // List filters
    buf.write(_freezedFilter('StringListFilter', 'String list', [
      'String? has',
      'List<String>? hasEvery',
      'List<String>? hasSome',
      'bool? isEmpty',
    ]));

    buf.write(_freezedFilter('IntListFilter', 'Int list', [
      'int? has',
      'List<int>? hasEvery',
      'List<int>? hasSome',
      'bool? isEmpty',
    ]));

    // SortOrder enum
    buf.writeln('/// Sort order for ordering results');
    buf.writeln('enum SortOrder {');
    buf.writeln("  @JsonValue('asc')");
    buf.writeln('  asc,');
    buf.writeln("  @JsonValue('desc')");
    buf.writeln('  desc,');
    buf.writeln('}');

    return _formatter.format(buf.toString());
  }

  String _freezedFilter(String name, String doc, List<String> fields) {
    final buf = StringBuffer();
    buf.writeln('/// Filter for $doc fields');
    buf.writeln('@freezed');
    buf.writeln('class $name with _\$$name {');
    buf.writeln('  const factory $name({');
    for (final field in fields) {
      buf.writeln('    $field,');
    }
    buf.writeln('  }) = _$name;');
    buf.writeln();
    buf.writeln('  factory $name.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      _\$${name}FromJson(json);');
    buf.writeln('}');
    buf.writeln();
    return buf.toString();
  }
}
