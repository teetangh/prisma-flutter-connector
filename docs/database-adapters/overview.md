# Database Adapters

The connector uses an adapter pattern to support multiple databases through a unified interface.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SqlDriverAdapter (Interface)                  │
├─────────────────────────────────────────────────────────────────────┤
│  + queryRaw(SqlQuery) → SqlResultSet                                │
│  + executeRaw(SqlQuery) → int                                       │
│  + transaction(queries) → List<SqlResultSet>                        │
│  + connect() → Future<void>                                         │
│  + close() → Future<void>                                           │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ implements
          ┌───────────────────┼───────────────────┐
          │                   │                   │
┌─────────┴─────────┐ ┌───────┴───────┐ ┌────────┴────────┐
│  PostgresAdapter  │ │SupabaseAdapter│ │  SQLiteAdapter  │
└───────────────────┘ └───────────────┘ └─────────────────┘
```

## Core Types

### SqlQuery

A SQL statement with parameters:

```dart
class SqlQuery {
  final String sql;          // "SELECT * FROM users WHERE id = $1"
  final List<dynamic> args;  // ['abc123']
  final List<ArgType> argTypes;
}
```

### SqlResultSet

Query results:

```dart
class SqlResultSet {
  final List<String> columnNames;
  final List<ColumnType> columnTypes;
  final List<List<dynamic>> rows;
  final String? lastInsertId;
}
```

### ArgType

Parameter types for proper serialization:

```dart
enum ArgType {
  int32, int64, float, double, decimal,
  boolean, string, dateTime, json, bytes, uuid, bigInt
}
```

## Available Adapters

| Adapter | Package | Use Case |
|---------|---------|----------|
| [PostgresAdapter](./postgresql.md) | `postgres` | Production PostgreSQL |
| [SupabaseAdapter](./supabase.md) | `supabase_flutter` | Supabase projects |
| [SQLiteAdapter](./sqlite.md) | `sqflite` | Mobile offline-first |

## Usage

```dart
// Create adapter
final adapter = PostgresAdapter(
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  username: 'user',
  password: 'pass',
);

// Connect
await adapter.connect();

// Execute raw query
final result = await adapter.queryRaw(SqlQuery(
  sql: 'SELECT * FROM users WHERE id = \$1',
  args: ['abc123'],
  argTypes: [ArgType.string],
));

// Close
await adapter.close();
```

## Implementing a Custom Adapter

```dart
class MyAdapter implements SqlDriverAdapter {
  @override
  Future<void> connect() async {
    // Initialize connection
  }

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    // Execute query and return results
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    // Execute and return affected rows
  }

  @override
  Future<List<SqlResultSet>> transaction(
    List<SqlQuery> queries, {
    IsolationLevel? isolationLevel,
  }) async {
    // Execute queries in transaction
  }

  @override
  Future<void> close() async {
    // Close connection
  }
}
```
