import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}

/// Input for creating a new user
@freezed
class CreateUserInput with _$CreateUserInput {
  const factory CreateUserInput({
    required String email,
    required String name,
  }) = _CreateUserInput;

  factory CreateUserInput.fromJson(Map<String, dynamic> json) =>
      _$CreateUserInputFromJson(json);
}

/// Input for updating an existing user
@freezed
class UpdateUserInput with _$UpdateUserInput {
  const factory UpdateUserInput({
    String? email,
    String? name,
  }) = _UpdateUserInput;

  factory UpdateUserInput.fromJson(Map<String, dynamic> json) =>
      _$UpdateUserInputFromJson(json);
}

/// Filter options for querying users
@freezed
class UserFilter with _$UserFilter {
  const factory UserFilter({
    String? emailContains,
    String? nameContains,
  }) = _UserFilter;

  factory UserFilter.fromJson(Map<String, dynamic> json) =>
      _$UserFilterFromJson(json);
}

/// Sort options for users
enum UserOrderBy {
  @JsonValue('email_ASC')
  emailAsc,
  @JsonValue('email_DESC')
  emailDesc,
  @JsonValue('name_ASC')
  nameAsc,
  @JsonValue('name_DESC')
  nameDesc,
  @JsonValue('createdAt_ASC')
  createdAtAsc,
  @JsonValue('createdAt_DESC')
  createdAtDesc,
}
