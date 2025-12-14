# Filter Types

Type-safe filter classes for query conditions.

## Location

`lib/src/generator/filter_types_generator.dart`

## Overview

Filter types provide compile-time type safety for query conditions. Each Prisma type has a corresponding filter class.

## String Filters

### StringFilter

For required String fields:

```dart
@freezed
class StringFilter with _$StringFilter {
  const factory StringFilter({
    String? equals,
    String? not,
    List<String>? in_,
    List<String>? notIn,
    String? contains,
    String? startsWith,
    String? endsWith,
    StringFilter? not_,
  }) = _StringFilter;
}
```

Usage:

```dart
UserWhereInput(
  email: StringFilter(
    contains: '@company.com',
    endsWith: '.com',
  ),
)
```

### StringNullableFilter

For optional String? fields - adds `isNull`:

```dart
StringNullableFilter(
  isNull: true,  // WHERE name IS NULL
)
```

## Numeric Filters

### IntFilter

```dart
@freezed
class IntFilter with _$IntFilter {
  const factory IntFilter({
    int? equals,
    int? not,
    List<int>? in_,
    List<int>? notIn,
    int? lt,
    int? lte,
    int? gt,
    int? gte,
  }) = _IntFilter;
}
```

Usage:

```dart
UserWhereInput(
  age: IntFilter(
    gte: 18,
    lt: 65,
  ),
)
// WHERE age >= 18 AND age < 65
```

### FloatFilter / DoubleFilter

Same operators as IntFilter but for floating-point numbers.

## Boolean Filter

```dart
@freezed
class BoolFilter with _$BoolFilter {
  const factory BoolFilter({
    bool? equals,
    bool? not,
  }) = _BoolFilter;
}
```

Usage:

```dart
UserWhereInput(
  isActive: BoolFilter(equals: true),
)
```

## DateTime Filters

### DateTimeFilter

```dart
@freezed
class DateTimeFilter with _$DateTimeFilter {
  const factory DateTimeFilter({
    DateTime? equals,
    DateTime? not,
    List<DateTime>? in_,
    List<DateTime>? notIn,
    DateTime? lt,
    DateTime? lte,
    DateTime? gt,
    DateTime? gte,
  }) = _DateTimeFilter;
}
```

Usage:

```dart
UserWhereInput(
  createdAt: DateTimeFilter(
    gte: DateTime.now().subtract(Duration(days: 7)),
  ),
)
// WHERE createdAt >= (7 days ago)
```

## List Filters

For array fields:

```dart
@freezed
class StringListFilter with _$StringListFilter {
  const factory StringListFilter({
    List<String>? equals,
    String? has,
    List<String>? hasEvery,
    List<String>? hasSome,
    bool? isEmpty,
  }) = _StringListFilter;
}
```

Usage:

```dart
PostWhereInput(
  tags: StringListFilter(
    hasSome: ['dart', 'flutter'],
  ),
)
// WHERE tags && ARRAY['dart', 'flutter']
```

## Sort Order

```dart
enum SortOrder {
  asc,
  desc,
}
```

Usage:

```dart
UserOrderByInput(
  createdAt: SortOrder.desc,
)
```

## Combining Filters

Multiple conditions are ANDed:

```dart
UserWhereInput(
  email: StringFilter(endsWith: '@company.com'),
  age: IntFilter(gte: 18),
  isActive: BoolFilter(equals: true),
)
// WHERE email LIKE '%@company.com' AND age >= 18 AND isActive = true
```

For OR conditions, use the `OR` field:

```dart
UserWhereInput(
  OR: [
    UserWhereInput(role: StringFilter(equals: 'admin')),
    UserWhereInput(role: StringFilter(equals: 'moderator')),
  ],
)
// WHERE (role = 'admin' OR role = 'moderator')
```
