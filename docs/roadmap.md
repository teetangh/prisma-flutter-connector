# Roadmap

Current status and future plans for the Prisma Flutter Connector.

## Current Status

**Version:** 0.1.0
**Maturity:** 60% toward production-ready

### Completed

- [x] Prisma schema parser
- [x] Freezed model generation
- [x] Type-safe input types (WhereInput, CreateInput, etc.)
- [x] Delegate generation with CRUD methods
- [x] PostgreSQL adapter
- [x] Supabase adapter
- [x] SQLite adapter
- [x] SQL compiler (PostgreSQL, SQLite dialects)
- [x] JSON query protocol
- [x] Filter operators
- [x] Transaction support
- [x] Reserved keyword auto-rename

### In Progress

- [ ] Unit test coverage (target: 80%+)
- [ ] Integration tests for all adapters
- [ ] Documentation improvements

## Planned Features

### High Priority

#### Relation Loading (include/select)

Eager loading of related records:

```dart
final user = await prisma.user.findUnique(
  where: UserWhereUniqueInput(id: '123'),
  include: UserInclude(
    posts: true,
    profile: true,
  ),
);
```

#### Nested Writes

Create/update related records in a single operation:

```dart
await prisma.user.create(
  data: CreateUserInput(
    email: 'test@example.com',
    posts: PostCreateNestedInput(
      create: [CreatePostInput(title: 'First Post')],
    ),
  ),
);
```

#### MySQL Adapter

Full MySQL/MariaDB support with the `mysql1` package.

### Medium Priority

#### Aggregations

```dart
final stats = await prisma.order.aggregate(
  where: OrderWhereInput(status: 'completed'),
  _count: true,
  _sum: AggregateSum(amount: true),
  _avg: AggregateAvg(amount: true),
);
```

#### Raw SQL Queries

```dart
final users = await prisma.$queryRaw<List<User>>(
  'SELECT * FROM "User" WHERE created_at > \$1',
  [DateTime.now().subtract(Duration(days: 7))],
);
```

#### Group By

```dart
final grouped = await prisma.order.groupBy(
  by: [OrderGroupBy.status],
  _count: true,
  _sum: AggregateSum(amount: true),
);
```

### Low Priority

- MongoDB adapter
- Migrations system
- Connection pooling improvements
- Result streaming for large datasets

## Database Support

| Database | Status |
|----------|--------|
| PostgreSQL | ✅ Supported |
| Supabase | ✅ Supported |
| SQLite | ✅ Supported |
| MySQL | 🚧 Planned |
| MongoDB | 📋 Backlog |

## Contributing

Contributions are welcome! See the [GitHub repository](https://github.com/teetangh/prisma-flutter-connector) for issues and pull requests.
