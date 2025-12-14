# Prisma Flutter Connector

A type-safe Dart/Flutter ORM with direct database access, inspired by Prisma Client.

## Overview

The Prisma Flutter Connector parses Prisma schema files and generates type-safe Dart code for database operations. Unlike traditional approaches that require a separate backend, this connector talks directly to your database.

## Features

- **Type-Safe Code Generation** - Freezed models with JSON serialization
- **Direct Database Access** - No backend required
- **Multiple Databases** - PostgreSQL, Supabase, SQLite
- **Prisma Schema Compatibility** - Use your existing `.prisma` files

## Quick Start

### 1. Add dependency

```yaml
dependencies:
  prisma_flutter_connector:
    git:
      url: https://github.com/teetangh/prisma-flutter-connector.git
```

### 2. Create a Prisma schema

```prisma
// schema.prisma
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
}

model Post {
  id        String   @id @default(uuid())
  title     String
  content   String?
  author    User     @relation(fields: [authorId], references: [id])
  authorId  String
}
```

### 3. Generate Dart code

```bash
dart run prisma_flutter_connector:generate \
  --schema path/to/schema.prisma \
  --output lib/generated/
```

### 4. Use the generated client

```dart
import 'package:your_app/generated/prisma_client.dart';

final prisma = PrismaClient(
  adapter: PostgresAdapter(
    host: 'localhost',
    port: 5432,
    database: 'mydb',
    username: 'user',
    password: 'pass',
  ),
);

// Find all users
final users = await prisma.user.findMany();

// Create a user
final user = await prisma.user.create(
  data: CreateUserInput(
    email: 'test@example.com',
    name: 'Test User',
  ),
);

// Find with filters
final activeUsers = await prisma.user.findMany(
  where: UserWhereInput(
    email: StringFilter(contains: '@company.com'),
  ),
);
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      CODE GENERATION (Build Time)                    │
│                                                                      │
│   schema.prisma ──→ PrismaParser ──→ Generators ──→ Generated Code  │
└─────────────────────────────────────────────────────────────────────┘
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                     RUNTIME (Query Execution)                        │
│                                                                      │
│   PrismaClient ──→ JsonQuery ──→ SqlCompiler ──→ DatabaseAdapter    │
└─────────────────────────────────────────────────────────────────────┘
```

## Documentation

- [Code Generation](./code-generation/) - Schema parsing and code generation
- [Database Adapters](./database-adapters/) - PostgreSQL, Supabase, SQLite
- [Query System](./query-system/) - SQL compilation and filters
- [Roadmap](./roadmap.md) - Future plans

## Supported Operations

| Operation | Status |
|-----------|--------|
| findMany | ✅ |
| findUnique | ✅ |
| findFirst | ✅ |
| create | ✅ |
| createMany | ✅ |
| update | ✅ |
| updateMany | ✅ |
| delete | ✅ |
| deleteMany | ✅ |
| count | ✅ |
| include (relations) | 🚧 Planned |
| aggregate | 🚧 Planned |

## License

MIT
