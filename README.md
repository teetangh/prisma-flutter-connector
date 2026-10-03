# Prisma Flutter Connector

[![pub package](https://img.shields.io/pub/v/prisma_flutter_connector.svg)](https://pub.dev/packages/prisma_flutter_connector)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/teetangh/prisma-flutter-connector/workflows/Unit%20Tests/badge.svg)](https://github.com/teetangh/prisma-flutter-connector/actions)

A type-safe, 100% pure-Dart Prisma ORM connector and AST code generator for Dart servers (Dart Frog, Shelf) and Flutter apps. Generate Freezed models, typed filters, model delegates, and `PrismaClient` directly from your `schema.prisma` — no GraphQL server required.

## Features

- **100% Pure Dart SDK** — Works in Dart CLI, Dart Frog, Shelf, and Flutter apps without a `dart:ui` or Flutter SDK dependency (`#41`, `#46`, `#62`)
- **Direct Database Access** — Connect directly to PostgreSQL, Supabase (direct or Supavisor/PgBouncer pooler), and SQLite
- **AST Code Generation (`code_builder`)** — Generates Freezed models, inputs, relation/scalar filters, delegates, `PrismaClient`, and `SchemaRegistry` from `schema.prisma`
- **Full Prisma Query Surface** — `findUnique`, `findUniqueOrThrow`, `findFirst`, `findFirstOrThrow`, `findMany`, `findManyProjected`, `create`, `createMany`, `update`, `updateMany`, `upsert`, `delete`, `deleteMany`, `count`, `aggregate`, `groupBy`
- **Interactive Transactions** — `prisma.$transaction((tx) async { ... })` with nested transaction flattening and proper SQLite & pooled PostgreSQL transaction pinning (`#42`)
- **Relations & Nested Writes** — Typed `include`, `select`, `some`/`every`/`none`/`is_`/`isNot` relation filters, and `connect`/`disconnect`/`create`/`set` nested mutations
- **Error Handling & Observability** — Typed Prisma error codes (`P1xxx`–`P2xxx`) and pluggable `QueryLogger` / `SentryQueryLogger`

## Supported Databases

- **PostgreSQL** — Single `pg.Connection` or pooled `pg.Pool` (`PostgresAdapter` / `PostgresAdapter.pooled`)
- **Supabase** — Direct connection (`:5432`) or Supavisor/PgBouncer transaction pooler (`:6543`) (`SupabaseAdapter`)
- **SQLite** — Pure-Dart `SQLiteDatabase` / `SQLiteCallbackDatabase` or Flutter `sqflite` (`SQLiteAdapter`)

## Installation

Add `prisma_flutter_connector` to your `pubspec.yaml`:

```yaml
dependencies:
  prisma_flutter_connector: ^1.0.0
  postgres: ^3.5.9
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.6
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

Install dependencies:

```bash
dart pub get
```

## Quick Start

### 1. Define Your Prisma Schema

```prisma
// prisma/schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model Post {
  id        String   @id @default(uuid())
  title     String
  published Boolean  @default(false)
  authorId  String
  author    User     @relation(fields: [authorId], references: [id])
}
```

### 2. Generate Dart Code

```bash
# 1. Generate models, filters, delegates, client, and schema registry
dart run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated/

# 2. Run build_runner for Freezed & JSON serialization
dart run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/generated/models/` — Freezed models, `Create*Input`, `Update*Input`, `WhereInput`, `WhereUniqueInput`, `OrderByInput`, `Include`, and `*ScalarField` enums
- `lib/generated/filters.dart` — Shared scalar/JSON/list filter types (`StringFilter`, `IntFilter`, `DateTimeFilter`, `JsonFilter`, etc.)
- `lib/generated/delegates/` — Typed `*Delegate` classes per model
- `lib/generated/prisma_client.dart` — `PrismaClient` with model delegates and `$transaction` / `$disconnect`
- `lib/generated/schema_registry.g.dart` — Compile-time `SchemaRegistry` metadata (`@map`, `@@map`, composite keys, relations)
- `lib/generated/index.dart` — Barrel export file

### 3. Connect and Query

```dart
import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';
import 'package:your_app/generated/index.dart';

Future<void> main() async {
  final adapter = await SupabaseAdapter.fromConnectionString(
    'postgresql://postgres.project:password@aws-0-us-east-1.pooler.supabase.com:6543/postgres',
  );

  final prisma = PrismaClient(adapter: adapter);

  // Create a user with nested posts
  final alice = await prisma.user.create(
    data: CreateUserInput(
      email: 'alice@example.com',
      name: 'Alice',
    ),
  );

  // Query with typed filters, ordering, and relation includes
  final users = await prisma.user.findMany(
    where: UserWhereInput(
      email: const StringFilter(contains: '@example.com'),
    ),
    include: const UserInclude(posts: true),
    orderBy: const UserOrderByInput(createdAt: SortOrder.desc),
    take: 10,
  );

  // Interactive transaction
  await prisma.$transaction((tx) async {
    await tx.user.update(
      where: UserWhereUniqueInput(id: alice.id),
      data: const UpdateUserInput(name: 'Alice Updated'),
    );
  });

  await prisma.$disconnect();
}
```

## Database Adapters

### PostgreSQL (Single Connection or Pool)

```dart
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/runtime.dart';

// Single connection
final connection = await pg.Connection.open(
  pg.Endpoint(
    host: 'localhost',
    database: 'mydb',
    username: 'postgres',
    password: 'password',
  ),
);
final adapter = PostgresAdapter(connection);

// Pooled connection
final pool = pg.Pool.withEndpoints(
  [
    pg.Endpoint(
      host: 'localhost',
      database: 'mydb',
      username: 'postgres',
      password: 'password',
    ),
  ],
  settings: const pg.PoolSettings(maxConnectionCount: 10),
);
final pooledAdapter = PostgresAdapter.pooled(pool);
```

### Supabase

```dart
import 'package:prisma_flutter_connector/runtime.dart';

final adapter = await SupabaseAdapter.fromConnectionString(
  'postgresql://postgres.project:password@aws-0-us-east-1.pooler.supabase.com:6543/postgres?pgbouncer=true',
);
```

### SQLite (Pure Dart or Flutter `sqflite`)

`SQLiteAdapter` has zero Flutter SDK dependencies. Pass either a Flutter `sqflite` `Database` instance, a custom `SQLiteDatabase` implementation, or a `SQLiteCallbackDatabase`:

```dart
import 'package:prisma_flutter_connector/runtime.dart';

// Option A: In a Flutter app with sqflite
// final db = await sqflite.openDatabase('app.db');
// final adapter = SQLiteAdapter(db);

// Option B: Pure-Dart callback adapter (e.g. wrapping package:sqlite3)
final adapter = SQLiteAdapter(
  SQLiteCallbackDatabase(
    onQuery: (sql, args) async => const <Map<String, Object?>>[],
    onExecute: (sql, args) async => 0,
  ),
);
```

## Architecture

```
schema.prisma
    ↓
bin/generate.dart (PrismaParser + Cb* code_builder AST generators)
    ↓
Generated Dart Client (PrismaClient + Delegates + Freezed Models + SchemaRegistry)
    ↓
QueryExecutor & SqlCompiler (JSON Protocol → Parameterized SQL + RelationCompiler)
    ↓
SqlDriverAdapter (PostgresAdapter / SupabaseAdapter / SQLiteAdapter)
    ↓
Database (PostgreSQL / Supabase / SQLite)
```

## Testing & MCP Tooling

```bash
# Run pure-Dart unit tests
dart test test/unit/

# Run static analysis
dart analyze
```

> **Note on `.mcp.json` (`dart mcp-server`):** While the `prisma_flutter_connector` package supports Dart SDK `>=3.0.0 <4.0.0`, the optional `.mcp.json` developer configuration uses the built-in `dart mcp-server` command, which requires **Dart 3.9+** (or Flutter 3.35+).

## Documentation & Support

- [Documentation](doc/README.md)
- [Contributing Guide](.github/CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [Issue Tracker](https://github.com/teetangh/prisma-flutter-connector/issues)
- [Discussions](https://github.com/teetangh/prisma-flutter-connector/discussions)

## License

MIT License — see [LICENSE](LICENSE) for details.
