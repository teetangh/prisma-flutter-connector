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
  Map<String, dynamic>? _include;
  Map<String, dynamic>? _orderBy;
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

  static Map<String, dynamic> and(List<Map<String, dynamic>> conditions) =>
      {'AND': conditions};
  static Map<String, dynamic> or(List<Map<String, dynamic>> conditions) =>
      {'OR': conditions};
  static Map<String, dynamic> none(Map<String, dynamic> condition) =>
      {'NOT': condition};
}
