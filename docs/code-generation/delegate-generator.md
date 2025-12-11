# Delegate Generator

Generates CRUD delegate classes for each model, providing the Prisma-like API.

## Location

`lib/src/generator/delegate_generator.dart`

## Generated API

For each model, a delegate class is generated with all CRUD operations:

```dart
class UserDelegate {
  final QueryExecutor _executor;

  UserDelegate(this._executor);

  /// Find multiple records
  Future<List<User>> findMany({
    UserWhereInput? where,
    UserOrderByInput? orderBy,
    int? take,
    int? skip,
  });

  /// Find unique record by ID or unique field
  Future<User?> findUnique({
    required UserWhereUniqueInput where,
  });

  /// Find first matching record
  Future<User?> findFirst({
    UserWhereInput? where,
    UserOrderByInput? orderBy,
  });

  /// Create a new record
  Future<User> create({
    required CreateUserInput data,
  });

  /// Create multiple records
  Future<int> createMany({
    required List<CreateUserInput> data,
  });

  /// Update a record
  Future<User?> update({
    required UserWhereUniqueInput where,
    required UpdateUserInput data,
  });

  /// Update multiple records
  Future<int> updateMany({
    required UserWhereInput where,
    required UpdateUserInput data,
  });

  /// Delete a record
  Future<User?> delete({
    required UserWhereUniqueInput where,
  });

  /// Delete multiple records
  Future<int> deleteMany({
    UserWhereInput? where,
  });

  /// Count records
  Future<int> count({
    UserWhereInput? where,
  });
}
```

## Usage Examples

### Find Many

```dart
// Find all users
final users = await prisma.user.findMany();

// With filters
final activeUsers = await prisma.user.findMany(
  where: UserWhereInput(
    email: StringFilter(endsWith: '@company.com'),
  ),
  orderBy: UserOrderByInput(createdAt: SortOrder.desc),
  take: 10,
);
```

### Find Unique

```dart
final user = await prisma.user.findUnique(
  where: UserWhereUniqueInput(id: 'abc123'),
);

// Or by unique field
final user = await prisma.user.findUnique(
  where: UserWhereUniqueInput(email: 'test@example.com'),
);
```

### Create

```dart
final user = await prisma.user.create(
  data: CreateUserInput(
    email: 'new@example.com',
    name: 'New User',
  ),
);
```

### Update

```dart
final updated = await prisma.user.update(
  where: UserWhereUniqueInput(id: 'abc123'),
  data: UpdateUserInput(name: 'Updated Name'),
);
```

### Delete

```dart
final deleted = await prisma.user.delete(
  where: UserWhereUniqueInput(id: 'abc123'),
);
```

### Count

```dart
final count = await prisma.user.count(
  where: UserWhereInput(
    email: StringFilter(contains: '@company.com'),
  ),
);
```

## Query Building

Internally, delegates use `JsonQueryBuilder` to construct queries:

```dart
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({'email': {'contains': '@company.com'}})
    .orderBy({'createdAt': 'desc'})
    .take(10)
    .build();
```

The query is then compiled to SQL by `SqlCompiler` and executed via the database adapter.
