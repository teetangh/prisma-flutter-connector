/// Filter types generator for field-level filters
///
/// Generates filter classes for each Prisma type (StringFilter, IntFilter, etc.)
/// These filters provide type-safe query building for WHERE clauses.
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Generates field-level filter type classes
class FilterTypesGenerator {
  final PrismaSchema schema;

  const FilterTypesGenerator(this.schema);

  /// Generate all filter types
  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('/// Generated filter types for type-safe queries');
    buffer.writeln('///');
    buffer
        .writeln('/// These filter classes provide compile-time type checking');
    buffer.writeln('/// for WHERE clause operations.');
    buffer.writeln('library;');
    buffer.writeln();
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();

    // Import all enums that are used in filter types
    for (final enumDef in schema.enums) {
      buffer.writeln("import 'models/${_toSnakeCase(enumDef.name)}.dart';");
    }
    if (schema.enums.isNotEmpty) {
      buffer.writeln();
    }

    buffer.writeln("part 'filters.freezed.dart';");
    buffer.writeln("part 'filters.g.dart';");
    buffer.writeln();

    // Generate core filter types
    buffer.write(_generateStringFilter());
    buffer.write(_generateIntFilter());
    buffer.write(_generateFloatFilter());
    buffer.write(_generateBooleanFilter());
    buffer.write(_generateDateTimeFilter());

    // Generate enum filters for each enum in the schema
    for (final enumDef in schema.enums) {
      buffer.write(_generateEnumFilter(enumDef));
    }

    // Generate list filters
    buffer.write(_generateStringListFilter());
    buffer.write(_generateIntListFilter());

    return buffer.toString();
  }

  /// Generate StringFilter for String field filtering
  String _generateStringFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for String fields');
    buffer.writeln('@freezed');
    buffer.writeln('class StringFilter with _\$StringFilter {');
    buffer.writeln('  const factory StringFilter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    String? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    String? not,');
    buffer.writeln('    /// In list of values');
    buffer.writeln('    @JsonKey(name: \'in\') List<String>? in_,');
    buffer.writeln('    /// Not in list of values');
    buffer.writeln('    List<String>? notIn,');
    buffer.writeln('    /// Contains substring (case-sensitive)');
    buffer.writeln('    String? contains,');
    buffer.writeln('    /// Starts with prefix (case-sensitive)');
    buffer.writeln('    String? startsWith,');
    buffer.writeln('    /// Ends with suffix (case-sensitive)');
    buffer.writeln('    String? endsWith,');
    buffer.writeln('    /// Less than');
    buffer.writeln('    String? lt,');
    buffer.writeln('    /// Less than or equal');
    buffer.writeln('    String? lte,');
    buffer.writeln('    /// Greater than');
    buffer.writeln('    String? gt,');
    buffer.writeln('    /// Greater than or equal');
    buffer.writeln('    String? gte,');
    buffer.writeln('  }) = _StringFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory StringFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$StringFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate IntFilter for Int field filtering
  String _generateIntFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for Int fields');
    buffer.writeln('@freezed');
    buffer.writeln('class IntFilter with _\$IntFilter {');
    buffer.writeln('  const factory IntFilter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    int? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    int? not,');
    buffer.writeln('    /// In list of values');
    buffer.writeln('    @JsonKey(name: \'in\') List<int>? in_,');
    buffer.writeln('    /// Not in list of values');
    buffer.writeln('    List<int>? notIn,');
    buffer.writeln('    /// Less than');
    buffer.writeln('    int? lt,');
    buffer.writeln('    /// Less than or equal');
    buffer.writeln('    int? lte,');
    buffer.writeln('    /// Greater than');
    buffer.writeln('    int? gt,');
    buffer.writeln('    /// Greater than or equal');
    buffer.writeln('    int? gte,');
    buffer.writeln('  }) = _IntFilter;');
    buffer.writeln();
    buffer
        .writeln('  factory IntFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$IntFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate FloatFilter for Float/Decimal field filtering
  String _generateFloatFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for Float/Decimal fields');
    buffer.writeln('@freezed');
    buffer.writeln('class FloatFilter with _\$FloatFilter {');
    buffer.writeln('  const factory FloatFilter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    double? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    double? not,');
    buffer.writeln('    /// In list of values');
    buffer.writeln('    @JsonKey(name: \'in\') List<double>? in_,');
    buffer.writeln('    /// Not in list of values');
    buffer.writeln('    List<double>? notIn,');
    buffer.writeln('    /// Less than');
    buffer.writeln('    double? lt,');
    buffer.writeln('    /// Less than or equal');
    buffer.writeln('    double? lte,');
    buffer.writeln('    /// Greater than');
    buffer.writeln('    double? gt,');
    buffer.writeln('    /// Greater than or equal');
    buffer.writeln('    double? gte,');
    buffer.writeln('  }) = _FloatFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory FloatFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$FloatFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate BooleanFilter for Boolean field filtering
  String _generateBooleanFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for Boolean fields');
    buffer.writeln('@freezed');
    buffer.writeln('class BooleanFilter with _\$BooleanFilter {');
    buffer.writeln('  const factory BooleanFilter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    bool? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    bool? not,');
    buffer.writeln('  }) = _BooleanFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory BooleanFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$BooleanFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate DateTimeFilter for DateTime field filtering
  String _generateDateTimeFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for DateTime fields');
    buffer.writeln('@freezed');
    buffer.writeln('class DateTimeFilter with _\$DateTimeFilter {');
    buffer.writeln('  const factory DateTimeFilter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    DateTime? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    DateTime? not,');
    buffer.writeln('    /// In list of values');
    buffer.writeln('    @JsonKey(name: \'in\') List<DateTime>? in_,');
    buffer.writeln('    /// Not in list of values');
    buffer.writeln('    List<DateTime>? notIn,');
    buffer.writeln('    /// Less than (before)');
    buffer.writeln('    DateTime? lt,');
    buffer.writeln('    /// Less than or equal');
    buffer.writeln('    DateTime? lte,');
    buffer.writeln('    /// Greater than (after)');
    buffer.writeln('    DateTime? gt,');
    buffer.writeln('    /// Greater than or equal');
    buffer.writeln('    DateTime? gte,');
    buffer.writeln('  }) = _DateTimeFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory DateTimeFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$DateTimeFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate enum filter for a specific enum type
  String _generateEnumFilter(PrismaEnum enumDef) {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for ${enumDef.name} enum fields');
    buffer.writeln('@freezed');
    buffer
        .writeln('class ${enumDef.name}Filter with _\$${enumDef.name}Filter {');
    buffer.writeln('  const factory ${enumDef.name}Filter({');
    buffer.writeln('    /// Exact match');
    buffer.writeln('    ${enumDef.name}? equals,');
    buffer.writeln('    /// Not equal to');
    buffer.writeln('    ${enumDef.name}? not,');
    buffer.writeln('    /// In list of values');
    buffer.writeln('    @JsonKey(name: \'in\') List<${enumDef.name}>? in_,');
    buffer.writeln('    /// Not in list of values');
    buffer.writeln('    List<${enumDef.name}>? notIn,');
    buffer.writeln('  }) = _${enumDef.name}Filter;');
    buffer.writeln();
    buffer.writeln(
        '  factory ${enumDef.name}Filter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$${enumDef.name}FilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate StringListFilter for String[] field filtering
  String _generateStringListFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for String list fields');
    buffer.writeln('@freezed');
    buffer.writeln('class StringListFilter with _\$StringListFilter {');
    buffer.writeln('  const factory StringListFilter({');
    buffer.writeln('    /// Has specific value');
    buffer.writeln('    String? has,');
    buffer.writeln('    /// Has every value in list');
    buffer.writeln('    List<String>? hasEvery,');
    buffer.writeln('    /// Has some value in list');
    buffer.writeln('    List<String>? hasSome,');
    buffer.writeln('    /// Is empty list');
    buffer.writeln('    bool? isEmpty,');
    buffer.writeln('  }) = _StringListFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory StringListFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$StringListFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate IntListFilter for Int[] field filtering
  String _generateIntListFilter() {
    final buffer = StringBuffer();

    buffer.writeln('/// Filter for Int list fields');
    buffer.writeln('@freezed');
    buffer.writeln('class IntListFilter with _\$IntListFilter {');
    buffer.writeln('  const factory IntListFilter({');
    buffer.writeln('    /// Has specific value');
    buffer.writeln('    int? has,');
    buffer.writeln('    /// Has every value in list');
    buffer.writeln('    List<int>? hasEvery,');
    buffer.writeln('    /// Has some value in list');
    buffer.writeln('    List<int>? hasSome,');
    buffer.writeln('    /// Is empty list');
    buffer.writeln('    bool? isEmpty,');
    buffer.writeln('  }) = _IntListFilter;');
    buffer.writeln();
    buffer.writeln(
        '  factory IntListFilter.fromJson(Map<String, dynamic> json) =>');
    buffer.writeln('      _\$IntListFilterFromJson(json);');
    buffer.writeln('}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Convert PascalCase to snake_case
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .substring(1); // Remove leading underscore
  }
}
