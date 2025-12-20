/// Computed field support for correlated subqueries in SELECT.
///
/// This enables queries like:
/// ```sql
/// SELECT *,
///   (SELECT MIN(price) FROM "Plan" WHERE "consultantId" = t0.id) AS "minPrice"
/// FROM "Consultant" t0
/// ```
///
/// Usage:
/// ```dart
/// final query = JsonQueryBuilder()
///     .model('Consultant')
///     .action(QueryAction.findMany)
///     .computed({
///       'minPrice': ComputedField.min('price',
///         from: 'Plan',
///         where: {'consultantId': FieldRef('id')}),
///     })
///     .build();
/// ```
library;

/// Reference to a field from the parent query.
///
/// Used in correlated subqueries to reference the parent table's columns.
/// ```dart
/// where: {'consultantId': FieldRef('id')}
/// // Generates: WHERE "consultantId" = "t0"."id"
/// ```
class FieldRef {
  final String fieldName;

  const FieldRef(this.fieldName);

  Map<String, dynamic> toJson() => {
        '_type': 'fieldRef',
        'field': fieldName,
      };

  @override
  String toString() => 'FieldRef($fieldName)';
}

/// Aggregate operation type for computed fields.
enum AggregateOp {
  min,
  max,
  avg,
  sum,
  count,
  first, // SELECT field ... LIMIT 1
}

/// A computed field definition for correlated subqueries.
///
/// Generates SQL like:
/// ```sql
/// (SELECT MIN("price") FROM "Plan" WHERE "consultantId" = t0.id) AS "minPrice"
/// ```
class ComputedField {
  /// The field to aggregate or select.
  final String field;

  /// The aggregate operation (MIN, MAX, AVG, SUM, COUNT, or FIRST for single value).
  final AggregateOp operation;

  /// The model/table to query from.
  final String from;

  /// WHERE conditions for the subquery.
  /// Can contain FieldRef for correlated references.
  final Map<String, dynamic>? where;

  /// ORDER BY for FIRST operation.
  final Map<String, String>? orderBy;

  const ComputedField._({
    required this.field,
    required this.operation,
    required this.from,
    this.where,
    this.orderBy,
  });

  /// Create a MIN aggregate computed field.
  ///
  /// ```dart
  /// ComputedField.min('price', from: 'Plan', where: {'consultantId': FieldRef('id')})
  /// // Generates: (SELECT MIN("price") FROM "Plan" WHERE "consultantId" = t0."id")
  /// ```
  factory ComputedField.min(
    String field, {
    required String from,
    Map<String, dynamic>? where,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.min,
      from: from,
      where: where,
    );
  }

  /// Create a MAX aggregate computed field.
  factory ComputedField.max(
    String field, {
    required String from,
    Map<String, dynamic>? where,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.max,
      from: from,
      where: where,
    );
  }

  /// Create an AVG aggregate computed field.
  factory ComputedField.avg(
    String field, {
    required String from,
    Map<String, dynamic>? where,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.avg,
      from: from,
      where: where,
    );
  }

  /// Create a SUM aggregate computed field.
  factory ComputedField.sum(
    String field, {
    required String from,
    Map<String, dynamic>? where,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.sum,
      from: from,
      where: where,
    );
  }

  /// Create a COUNT aggregate computed field.
  ///
  /// By default counts all rows (`COUNT(*)`). Optionally specify a [field]
  /// to count non-null values of that field (`COUNT(field)`).
  ///
  /// ```dart
  /// // COUNT(*) - count all rows
  /// ComputedField.count(from: 'Review', where: {...})
  ///
  /// // COUNT(field) - count non-null values
  /// ComputedField.count(field: 'rating', from: 'Review', where: {...})
  /// ```
  factory ComputedField.count({
    String field = '*',
    required String from,
    Map<String, dynamic>? where,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.count,
      from: from,
      where: where,
    );
  }

  /// Create a FIRST (single value) computed field.
  ///
  /// Fetches the first matching value with optional ordering.
  /// ```dart
  /// ComputedField.first('priceCurrency',
  ///   from: 'Plan',
  ///   where: {'consultantId': FieldRef('id')},
  ///   orderBy: {'price': 'asc'})
  /// // Generates: (SELECT "priceCurrency" FROM "Plan" WHERE ... ORDER BY "price" ASC LIMIT 1)
  /// ```
  factory ComputedField.first(
    String field, {
    required String from,
    Map<String, dynamic>? where,
    Map<String, String>? orderBy,
  }) {
    return ComputedField._(
      field: field,
      operation: AggregateOp.first,
      from: from,
      where: where,
      orderBy: orderBy,
    );
  }

  /// Convert to JSON for query builder.
  Map<String, dynamic> toJson() => {
        '_type': 'computedField',
        'field': field,
        'operation': operation.name,
        'from': from,
        if (where != null) 'where': _serializeWhere(where!),
        if (orderBy != null) 'orderBy': orderBy,
      };

  /// Serialize WHERE clause, converting FieldRef to JSON.
  Map<String, dynamic> _serializeWhere(Map<String, dynamic> where) {
    final result = <String, dynamic>{};
    for (final entry in where.entries) {
      if (entry.value is FieldRef) {
        result[entry.key] = (entry.value as FieldRef).toJson();
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  @override
  String toString() =>
      'ComputedField(${operation.name}($field) FROM $from${where != null ? ' WHERE $where' : ''})';
}
