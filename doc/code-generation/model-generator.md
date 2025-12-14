# Model Generator

Generates Freezed model classes and input types from parsed Prisma schema.

## Location

`lib/src/generator/model_generator.dart`

## Generated Types

For each model in the schema, the generator creates:

### 1. Main Model Class

```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    String? name,
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

### 2. CreateInput

For creating new records:

```dart
@freezed
class CreateUserInput with _$CreateUserInput {
  const factory CreateUserInput({
    String? id,           // Optional if @default(uuid())
    required String email,
    String? name,
  }) = _CreateUserInput;

  factory CreateUserInput.fromJson(Map<String, dynamic> json) =>
      _$CreateUserInputFromJson(json);
}
```

### 3. UpdateInput

For updating existing records (all fields optional):

```dart
@freezed
class UpdateUserInput with _$UpdateUserInput {
  const factory UpdateUserInput({
    String? email,
    String? name,
  }) = _UpdateUserInput;

  factory UpdateUserInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateUserInputFromJson(json);
}
```

### 4. WhereInput

For filtering queries:

```dart
@freezed
class UserWhereInput with _$UserWhereInput {
  const factory UserWhereInput({
    StringFilter? id,
    StringFilter? email,
    StringNullableFilter? name,
    DateTimeFilter? createdAt,
  }) = _UserWhereInput;

  factory UserWhereInput.fromJson(Map<String, dynamic> json) =>
      _$UserWhereInputFromJson(json);
}
```

### 5. WhereUniqueInput

For finding unique records:

```dart
@freezed
class UserWhereUniqueInput with _$UserWhereUniqueInput {
  const factory UserWhereUniqueInput({
    String? id,
    String? email,  // Fields with @unique
  }) = _UserWhereUniqueInput;

  factory UserWhereUniqueInput.fromJson(Map<String, dynamic> json) =>
      _$UserWhereUniqueInputFromJson(json);
}
```

### 6. OrderByInput

For sorting results:

```dart
@freezed
class UserOrderByInput with _$UserOrderByInput {
  const factory UserOrderByInput({
    SortOrder? id,
    SortOrder? email,
    SortOrder? name,
    SortOrder? createdAt,
  }) = _UserOrderByInput;

  factory UserOrderByInput.fromJson(Map<String, dynamic> json) =>
      _$UserOrderByInputFromJson(json);
}
```

## Type Mappings

| Prisma Type | Dart Type |
|-------------|-----------|
| `String` | `String` |
| `Int` | `int` |
| `Float` | `double` |
| `Boolean` | `bool` |
| `DateTime` | `DateTime` |
| `Json` | `Map<String, dynamic>` |
| `BigInt` | `BigInt` |
| `Bytes` | `Uint8List` |
| `Decimal` | `Decimal` |

## Reserved Keyword Handling

When a field uses a Dart reserved keyword, the generator adds `@JsonKey`:

```dart
@freezed
class MyModel with _$MyModel {
  const factory MyModel({
    @JsonKey(name: 'class') String? classRef,  // 'class' is reserved
    @JsonKey(name: 'type') String? typeValue,  // 'type' is reserved
  }) = _MyModel;
}
```
