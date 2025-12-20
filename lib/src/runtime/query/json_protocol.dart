/// JSON Protocol for Prisma queries.
///
/// This implements Prisma's JSON protocol, which is the intermediate format
/// between the client API and the query compiler. All Prisma queries are first
/// converted to this JSON format before being compiled to SQL.
///
/// Based on Prisma's internal JSON protocol from:
/// packages/client/src/runtime/core/jsonProtocol/
library;

import 'dart:convert';

import 'computed_field.dart';

/// Represents a complete JSON query in Prisma's format.
class JsonQuery {
  final String modelName;
  final String action;
  final JsonQueryArgs args;

  const JsonQuery({
    required this.modelName,
    required this.action,
    required this.args,
  });

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'action': action,
        'query': args.toJson(),
      };

  @override
  String toString() => jsonEncode(toJson());
}

/// Arguments for a JSON query.
class JsonQueryArgs {
  final Map<String, dynamic>? arguments;
  final JsonSelection? selection;

  const JsonQueryArgs({
    this.arguments,
    this.selection,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (arguments != null) result['arguments'] = arguments;
    if (selection != null) result['selection'] = selection!.toJson();
    return result;
  }
}

/// Field selection in a query.
class JsonSelection {
  final bool? scalars;
  final bool? composites;
  final Map<String, JsonFieldSelection>? fields;

  const JsonSelection({
    this.scalars,
    this.composites,
    this.fields,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (scalars != null) result['\$scalars'] = scalars;
    if (composites != null) result['\$composites'] = composites;
    if (fields != null) {
      for (final entry in fields!.entries) {
        result[entry.key] = entry.value.toJson();
      }
    }
    return result;
  }
}

/// Selection for a specific field.
class JsonFieldSelection {
  final Map<String, dynamic>? arguments;
  final JsonSelection? selection;

  const JsonFieldSelection({
    this.arguments,
    this.selection,
  });

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{};
    if (arguments != null) result['arguments'] = arguments;
    if (selection != null) result['selection'] = selection!.toJson();
    return result;
  }
}

/// Query action types (matching Prisma's actions).
enum QueryAction {
  findUnique('findUnique'),
  findUniqueOrThrow('findUniqueOrThrow'),
  findFirst('findFirst'),
  findFirstOrThrow('findFirstOrThrow'),
  findMany('findMany'),
  create('create'),
  createMany('createMany'),
  update('update'),
  updateMany('updateMany'),
  upsert('upsert'),
  delete('delete'),
  deleteMany('deleteMany'),
  aggregate('aggregate'),
  groupBy('groupBy'),
  count('count');

  final String value;
  const QueryAction(this.value);
}

/// Builder for constructing JSON queries.
class JsonQueryBuilder {
  String? _modelName;
  String? _action;
  Map<String, dynamic>? _where;
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _select;
  List<String>? _selectFields;
  Map<String, dynamic>? _include;
  Map<String, dynamic>? _orderBy;
  Map<String, dynamic>? _aggregate;
  List<String>? _groupBy;
  Map<String, ComputedField>? _computed;
  int? _take;
  int? _skip;
  final bool _selectScalars = true;

  JsonQueryBuilder model(String name) {
    _modelName = name;
    return this;
  }

  JsonQueryBuilder action(QueryAction action) {
    _action = action.value;
    return this;
  }

  JsonQueryBuilder where(Map<String, dynamic> conditions) {
    _where = conditions;
    return this;
  }

  JsonQueryBuilder data(Map<String, dynamic> data) {
    _data = data;
    return this;
  }

  JsonQueryBuilder select(Map<String, dynamic> fields) {
    _select = fields;
    return this;
  }

  /// Select specific fields by name.
  ///
  /// This is the preferred way to select specific columns instead of SELECT *.
  /// Supports dot notation for related fields when used with include().
  ///
  /// Example:
  /// ```dart
  /// // Select specific scalar fields
  /// .selectFields(['id', 'name', 'price'])
  ///
  /// // Select fields from relations (requires include)
  /// .selectFields(['id', 'name', 'category.name', 'category.id'])
  /// .include({'category': true})
  /// ```
  ///
  /// Generates: SELECT "id", "name", "price" FROM "Model"
  /// Or with relations: SELECT t0."id", t0."name", t1."name" AS "category_name"
  JsonQueryBuilder selectFields(List<String> fields) {
    _selectFields = fields;
    return this;
  }

  JsonQueryBuilder include(Map<String, dynamic> relations) {
    _include = relations;
    return this;
  }

  JsonQueryBuilder orderBy(Map<String, dynamic> order) {
    _orderBy = order;
    return this;
  }

  JsonQueryBuilder take(int count) {
    _take = count;
    return this;
  }

  JsonQueryBuilder skip(int count) {
    _skip = count;
    return this;
  }

  /// Set aggregation functions for aggregate queries.
  ///
  /// Example:
  /// ```dart
  /// .aggregation({
  ///   '_count': true,
  ///   '_avg': {'price': true, 'rating': true},
  ///   '_sum': {'quantity': true},
  ///   '_min': {'price': true},
  ///   '_max': {'price': true},
  /// })
  /// ```
  JsonQueryBuilder aggregation(Map<String, dynamic> agg) {
    _aggregate = agg;
    return this;
  }

  /// Set fields to group by for groupBy queries.
  ///
  /// Example:
  /// ```dart
  /// .groupBy(['status', 'category'])
  /// ```
  JsonQueryBuilder groupByFields(List<String> fields) {
    _groupBy = fields;
    return this;
  }

  /// Add computed fields (correlated subqueries) to the query.
  ///
  /// Computed fields generate subqueries in the SELECT clause that reference
  /// the parent row. This is useful for aggregating related data inline.
  ///
  /// Example:
  /// ```dart
  /// .computed({
  ///   'minPrice': ComputedField.min('price',
  ///     from: 'ConsultationPlan',
  ///     where: {'consultantProfileId': FieldRef('id')}),
  ///   'priceCurrency': ComputedField.first('priceCurrency',
  ///     from: 'ConsultationPlan',
  ///     where: {'consultantProfileId': FieldRef('id')},
  ///     orderBy: {'price': 'asc'}),
  /// })
  /// ```
  ///
  /// Generates SQL like:
  /// ```sql
  /// SELECT *,
  ///   (SELECT MIN("price") FROM "ConsultationPlan"
  ///    WHERE "consultantProfileId" = t0."id") AS "minPrice",
  ///   (SELECT "priceCurrency" FROM "ConsultationPlan"
  ///    WHERE "consultantProfileId" = t0."id"
  ///    ORDER BY "price" ASC LIMIT 1) AS "priceCurrency"
  /// FROM "ConsultantProfile" t0
  /// ```
  JsonQueryBuilder computed(Map<String, ComputedField> fields) {
    _computed = fields;
    return this;
  }

  JsonQuery build() {
    if (_modelName == null) {
      throw StateError('Model name is required');
    }
    if (_action == null) {
      throw StateError('Action is required');
    }

    final arguments = <String, dynamic>{};

    if (_where != null) arguments['where'] = _where;
    if (_data != null) arguments['data'] = _data;
    if (_orderBy != null) arguments['orderBy'] = _orderBy;
    if (_take != null) arguments['take'] = _take;
    if (_skip != null) arguments['skip'] = _skip;
    if (_aggregate != null) arguments['_aggregate'] = _aggregate;
    if (_groupBy != null) arguments['by'] = _groupBy;
    if (_selectFields != null) arguments['selectFields'] = _selectFields;
    if (_computed != null) {
      arguments['_computed'] = _computed!.map(
        (key, value) => MapEntry(key, value.toJson()),
      );
    }

    // Build selection
    JsonSelection? selection;
    if (_select != null || _include != null) {
      final fields = <String, JsonFieldSelection>{};

      if (_select != null) {
        for (final entry in _select!.entries) {
          if (entry.value == true) {
            fields[entry.key] = const JsonFieldSelection();
          }
        }
      }

      if (_include != null) {
        for (final entry in _include!.entries) {
          if (entry.value == true) {
            fields[entry.key] = const JsonFieldSelection(
              selection: JsonSelection(scalars: true),
            );
          } else if (entry.value is Map) {
            fields[entry.key] = JsonFieldSelection(
              arguments: entry.value as Map<String, dynamic>,
              selection: const JsonSelection(scalars: true),
            );
          }
        }
      }

      selection = JsonSelection(
        scalars: _selectScalars,
        fields: fields.isNotEmpty ? fields : null,
      );
    } else {
      selection = JsonSelection(scalars: _selectScalars);
    }

    return JsonQuery(
      modelName: _modelName!,
      action: _action!,
      args: JsonQueryArgs(
        arguments: arguments.isNotEmpty ? arguments : null,
        selection: selection,
      ),
    );
  }
}

/// Special Prisma value types (DateTime, Json, Bytes, etc.).
class PrismaValue {
  final String type;
  final dynamic value;

  const PrismaValue(this.type, this.value);

  factory PrismaValue.dateTime(DateTime value) =>
      PrismaValue('\$type', {'DateTime': value.toIso8601String()});

  factory PrismaValue.json(Map<String, dynamic> value) =>
      PrismaValue('\$type', {'Json': jsonEncode(value)});

  factory PrismaValue.bytes(List<int> value) =>
      PrismaValue('\$type', {'Bytes': base64Encode(value)});

  factory PrismaValue.decimal(String value) =>
      PrismaValue('\$type', {'Decimal': value});

  factory PrismaValue.bigInt(BigInt value) =>
      PrismaValue('\$type', {'BigInt': value.toString()});

  Map<String, dynamic> toJson() => {type: value};
}

/// Filter operators for WHERE clauses.
class FilterOperators {
  static Map<String, dynamic> equals(dynamic value) => {'equals': value};
  static Map<String, dynamic> not(dynamic value) => {'not': value};
  static Map<String, dynamic> in_(List<dynamic> values) => {'in': values};
  static Map<String, dynamic> notIn(List<dynamic> values) => {'notIn': values};
  static Map<String, dynamic> lt(dynamic value) => {'lt': value};
  static Map<String, dynamic> lte(dynamic value) => {'lte': value};
  static Map<String, dynamic> gt(dynamic value) => {'gt': value};
  static Map<String, dynamic> gte(dynamic value) => {'gte': value};
  static Map<String, dynamic> contains(String value) => {'contains': value};
  static Map<String, dynamic> startsWith(String value) => {'startsWith': value};
  static Map<String, dynamic> endsWith(String value) => {'endsWith': value};

  /// Case-insensitive contains (uses ILIKE on PostgreSQL/Supabase)
  static Map<String, dynamic> containsInsensitive(String value) =>
      {'contains': {'value': value, 'mode': 'insensitive'}};

  /// Case-insensitive startsWith (uses ILIKE on PostgreSQL/Supabase)
  static Map<String, dynamic> startsWithInsensitive(String value) =>
      {'startsWith': {'value': value, 'mode': 'insensitive'}};

  /// Case-insensitive endsWith (uses ILIKE on PostgreSQL/Supabase)
  static Map<String, dynamic> endsWithInsensitive(String value) =>
      {'endsWith': {'value': value, 'mode': 'insensitive'}};

  static Map<String, dynamic> and(List<Map<String, dynamic>> conditions) =>
      {'AND': conditions};
  static Map<String, dynamic> or(List<Map<String, dynamic>> conditions) =>
      {'OR': conditions};
  static Map<String, dynamic> none(Map<String, dynamic> condition) =>
      {'NOT': condition};

  // ==================== Relation Filters ====================
  // These are used to filter based on related records.
  // Use these on relation fields in WHERE clauses.

  /// Filter where at least one related record matches the condition.
  ///
  /// Example:
  /// ```dart
  /// .where({
  ///   'consultationPlans': FilterOperators.some({
  ///     'price': FilterOperators.lte(5000)
  ///   })
  /// })
  /// ```
  /// Generates: EXISTS (SELECT 1 FROM "ConsultationPlan" WHERE ... AND price <= 5000)
  static Map<String, dynamic> some(Map<String, dynamic> where) =>
      {'some': where};

  /// Filter where all related records match the condition.
  ///
  /// Example:
  /// ```dart
  /// .where({
  ///   'posts': FilterOperators.every({
  ///     'published': true
  ///   })
  /// })
  /// ```
  /// Generates: NOT EXISTS (SELECT 1 FROM "Post" WHERE ... AND NOT (published = true))
  static Map<String, dynamic> every(Map<String, dynamic> where) =>
      {'every': where};

  /// Filter where no related records match the condition.
  ///
  /// Example:
  /// ```dart
  /// .where({
  ///   'comments': FilterOperators.noneMatch({
  ///     'spam': true
  ///   })
  /// })
  /// ```
  /// Generates: NOT EXISTS (SELECT 1 FROM "Comment" WHERE ... AND spam = true)
  static Map<String, dynamic> noneMatch(Map<String, dynamic> where) =>
      {'none': where};

  /// Filter where the relation has no related records at all.
  ///
  /// Example:
  /// ```dart
  /// .where({
  ///   'comments': FilterOperators.isEmpty()
  /// })
  /// ```
  /// Generates: NOT EXISTS (SELECT 1 FROM "Comment" WHERE ...)
  static Map<String, dynamic> isEmpty() => {'none': <String, dynamic>{}};

  /// Filter where the relation has at least one related record.
  ///
  /// Example:
  /// ```dart
  /// .where({
  ///   'posts': FilterOperators.isNotEmpty()
  /// })
  /// ```
  /// Generates: EXISTS (SELECT 1 FROM "Post" WHERE ...)
  static Map<String, dynamic> isNotEmpty() => {'some': <String, dynamic>{}};
}
