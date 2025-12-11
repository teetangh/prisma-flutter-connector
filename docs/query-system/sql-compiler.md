# SQL Compiler

Compiles Prisma JSON queries into SQL statements.

## Location

`lib/src/runtime/query/sql_compiler.dart`

## Overview

The SQL compiler transforms Prisma's JSON query protocol into executable SQL. It handles different SQL dialects (PostgreSQL, SQLite) and properly escapes identifiers and parameters.

## Usage

```dart
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';

final compiler = SqlCompiler(
  provider: 'postgresql',
  schemaName: 'public',
);

final query = JsonQuery(
  modelName: 'User',
  action: 'findMany',
  args: JsonQueryArgs(
    arguments: {
      'where': {'email': {'contains': '@example.com'}},
      'orderBy': {'createdAt': 'desc'},
      'take': 10,
    },
  ),
);

final sqlQuery = compiler.compile(query);
// SqlQuery(
//   sql: 'SELECT * FROM "User" WHERE "email" LIKE $1 ORDER BY "createdAt" DESC LIMIT 10',
//   args: ['%@example.com%'],
//   argTypes: [ArgType.string],
// )
```

## Supported Actions

| Action | SQL |
|--------|-----|
| `findMany` | SELECT |
| `findUnique` | SELECT ... LIMIT 1 |
| `findFirst` | SELECT ... LIMIT 1 |
| `create` | INSERT |
| `createMany` | INSERT (batch) |
| `update` | UPDATE |
| `updateMany` | UPDATE |
| `delete` | DELETE |
| `deleteMany` | DELETE |
| `count` | SELECT COUNT(*) |

## Query Arguments

### where

Filter conditions:

```dart
{
  'where': {
    'email': {'contains': '@company.com'},
    'age': {'gte': 18},
    'OR': [
      {'status': 'active'},
      {'status': 'pending'},
    ],
  },
}
```

Generated SQL:
```sql
WHERE "email" LIKE '%@company.com%' AND "age" >= 18 AND ("status" = 'active' OR "status" = 'pending')
```

### orderBy

Sort results:

```dart
{'orderBy': {'createdAt': 'desc'}}
```

Generated SQL:
```sql
ORDER BY "createdAt" DESC
```

### take / skip

Pagination:

```dart
{'take': 10, 'skip': 20}
```

Generated SQL:
```sql
LIMIT 10 OFFSET 20
```

### data

For create/update:

```dart
{
  'data': {
    'email': 'new@example.com',
    'name': 'New User',
  },
}
```

Generated SQL:
```sql
INSERT INTO "User" ("email", "name") VALUES ($1, $2)
-- or
UPDATE "User" SET "email" = $1, "name" = $2 WHERE ...
```

## Dialect Differences

### PostgreSQL

- Identifiers quoted with `"double quotes"`
- Parameters use `$1, $2, $3...`
- Full JSON/JSONB support

### SQLite

- Identifiers quoted with `"double quotes"` or \`backticks\`
- Parameters use `?, ?, ?...`
- JSON stored as TEXT

## Identifier Quoting

The compiler properly quotes identifiers to handle:

- Reserved words
- Case sensitivity
- Special characters

```dart
_quoteIdentifier('User')     // "User"
_quoteIdentifier('order')    // "order" (reserved word)
_quoteIdentifier('my-table') // "my-table" (special char)
```

## Parameter Types

The compiler tracks parameter types for proper serialization:

```dart
SqlQuery(
  sql: 'SELECT * FROM "User" WHERE "age" > $1 AND "active" = $2',
  args: [18, true],
  argTypes: [ArgType.int32, ArgType.boolean],
)
```
