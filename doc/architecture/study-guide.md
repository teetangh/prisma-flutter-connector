# Prisma Flutter Connector - Study Guide

A step-by-step learning path to understand the entire codebase from scratch.

---

## Prerequisites

Before diving in, you should be comfortable with:
- Dart async/await and Futures
- Basic SQL (SELECT, INSERT, UPDATE, DELETE, JOINs)
- The concept of ORMs (Object-Relational Mapping)

---

## Phase 1: Foundation (Start Here)

### File: `lib/src/runtime/adapters/types.dart`

**What you'll learn:**
- The core interfaces that define how the connector talks to databases
- The contract that every database adapter must implement

**Key types to understand:**

```dart
/// The raw SQL query with parameters
class SqlQuery {
  final String sql;           // "SELECT * FROM users WHERE id = $1"
  final List<dynamic> args;   // [123]
  final List<ArgType> argTypes; // [ArgType.int_]
}

/// The result from a SQL query
class SqlResultSet {
  final List<String> columns; // ["id", "name", "email"]
  final List<List<dynamic>> rows; // [[1, "John", "john@example.com"]]
}

/// The interface every adapter must implement
abstract class SqlDriverAdapter {
  String get provider;  // "postgresql", "mysql", "sqlite"
  Future<SqlResultSet> queryRaw(SqlQuery query);
  Future<int> executeRaw(SqlQuery query);
  Future<TransactionAdapter> beginTransaction();
}
```

**Why this matters:** Everything else depends on these types. The adapter is just "give me SQL, I'll give you rows."

---

## Phase 2: Database Adapters

### File: `lib/src/runtime/adapters/postgres_adapter.dart`

**What you'll learn:**
- How to implement the `SqlDriverAdapter` interface
- Type conversion between PostgreSQL and Dart
- Transaction handling

**Key sections:**

```dart
class PostgresAdapter implements SqlDriverAdapter {
  final pg.Connection _connection;

  @override
  String get provider => 'postgresql';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    // 1. Execute SQL on the actual database
    final result = await _connection.execute(
      pg.Sql.named(query.sql),
      parameters: _buildParameters(query),
    );

    // 2. Convert PostgreSQL result to our SqlResultSet
    return SqlResultSet(
      columns: result.schema.columns.map((c) => c.columnName).toList(),
      rows: result.map((row) => row.toList()).toList(),
    );
  }
}
```

**Focus on:**
- `_convertValue()` - How PostgreSQL types become Dart types
- `_buildParameters()` - How Dart values become SQL parameters
- `PostgresTransaction` - How transactions maintain atomicity

### Optional: `lib/src/runtime/adapters/sqlite_adapter.dart`

See how the same interface works differently for SQLite (local file database).

---

## Phase 3: Query Protocol

### File: `lib/src/runtime/query/json_protocol.dart`

**What you'll learn:**
- How queries are represented as data structures (not strings)
- The fluent builder pattern for constructing queries
- Filter operators (equals, contains, gt, lt, etc.)

**Key classes:**

```dart
/// The fluent builder for creating queries
class JsonQueryBuilder {
  JsonQueryBuilder model(String name);      // Target table
  JsonQueryBuilder action(QueryAction act); // findMany, create, update, delete
  JsonQueryBuilder where(Map<String, dynamic> conditions);
  JsonQueryBuilder data(Map<String, dynamic> values);
  JsonQueryBuilder orderBy(Map<String, String> order);
  JsonQueryBuilder take(int limit);
  JsonQueryBuilder skip(int offset);
  JsonQueryBuilder include(Map<String, dynamic> relations);
  JsonQuery build();  // Finalize and return the query
}

/// Available query actions
enum QueryAction {
  findUnique,
  findFirst,
  findMany,
  create,
  createMany,
  update,
  updateMany,
  upsert,
  delete,
  deleteMany,
  count,
  aggregate,
}

/// Filter operators for WHERE clauses
class FilterOperators {
  static Map<String, dynamic> equals(dynamic value);
  static Map<String, dynamic> not(dynamic value);
  static Map<String, dynamic> in_(List values);
  static Map<String, dynamic> contains(String value);
  static Map<String, dynamic> startsWith(String value);
  static Map<String, dynamic> gt(dynamic value);
  static Map<String, dynamic> gte(dynamic value);
  static Map<String, dynamic> lt(dynamic value);
  static Map<String, dynamic> lte(dynamic value);
}
```

**Example usage:**

```dart
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({
      'email': FilterOperators.contains('@gmail.com'),
      'age': FilterOperators.gte(18),
    })
    .orderBy({'createdAt': 'desc'})
    .take(10)
    .build();
```

**Why this matters:** Queries are just data. This decouples "what you want" from "how to get it" (SQL).

---

## Phase 4: SQL Compilation (The Hard Part)

### File: `lib/src/runtime/query/sql_compiler.dart`

**What you'll learn:**
- How JSON queries become parameterized SQL
- Provider-specific SQL syntax (PostgreSQL vs MySQL vs SQLite)
- Complex WHERE clause generation

**Key methods:**

```dart
class SqlCompiler {
  /// Compile any query to SQL
  CompiledQuery compile(JsonQuery query) {
    return switch (query.action) {
      QueryAction.findUnique ||
      QueryAction.findFirst ||
      QueryAction.findMany => _compileFindQuery(query),
      QueryAction.create => _compileCreateQuery(query),
      QueryAction.update => _compileUpdateQuery(query),
      QueryAction.delete => _compileDeleteQuery(query),
      QueryAction.upsert => _compileUpsertQuery(query),
      QueryAction.count => _compileCountQuery(query),
      // ...
    };
  }
}
```

**Study these methods in order:**

1. **`_compileFindQuery()`** - SELECT with WHERE, ORDER BY, LIMIT
   ```sql
   SELECT * FROM "User" WHERE "email" = $1 ORDER BY "createdAt" DESC LIMIT 10
   ```

2. **`_compileCreateQuery()`** - INSERT with RETURNING
   ```sql
   INSERT INTO "User" ("name", "email") VALUES ($1, $2) RETURNING *
   ```

3. **`_compileUpdateQuery()`** - UPDATE with WHERE
   ```sql
   UPDATE "User" SET "name" = $1 WHERE "id" = $2 RETURNING *
   ```

4. **`_compileUpsertQuery()`** - ON CONFLICT DO UPDATE
   ```sql
   INSERT INTO "User" ("email", "name") VALUES ($1, $2)
   ON CONFLICT ("email") DO UPDATE SET "name" = $3
   RETURNING *
   ```

5. **`_buildWhereClause()`** - Complex filters (AND/OR/NOT)
   ```sql
   WHERE ("age" >= $1 AND "status" = $2) OR "role" = $3
   ```

**Provider differences:**

| Feature | PostgreSQL | MySQL | SQLite |
|---------|------------|-------|--------|
| Quoting | `"column"` | `` `column` `` | `"column"` |
| Placeholders | `$1, $2` | `?, ?` | `?, ?` |
| RETURNING | `RETURNING *` | Not supported | `RETURNING *` (3.35+) |
| UPSERT | `ON CONFLICT DO UPDATE` | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT DO UPDATE` |

---

## Phase 5: Query Execution

### File: `lib/src/runtime/query/query_executor.dart`

**What you'll learn:**
- How everything ties together
- Result mapping (rows → Dart maps)
- Transaction management
- Error handling

**Key methods:**

```dart
class QueryExecutor {
  final SqlDriverAdapter adapter;
  final SqlCompiler _compiler;
  final QueryLogger? logger;

  /// Execute query, return list of maps
  Future<List<Map<String, dynamic>>> executeQueryAsMaps(JsonQuery query) async {
    // 1. Compile JSON query to SQL
    final compiled = _compiler.compile(query);

    // 2. Execute via adapter
    final result = await _executeWithLogging(
      sql: compiled.sql,
      parameters: compiled.args,
      execute: () => adapter.queryRaw(compiled.toSqlQuery()),
    );

    // 3. Convert SqlResultSet to List<Map>
    return _resultSetToMaps(result);
  }

  /// Execute in a transaction
  Future<T> executeInTransaction<T>(
    Future<T> Function(TransactionExecutor) callback,
  ) async {
    final txn = await adapter.beginTransaction();
    try {
      final result = await callback(TransactionExecutor(txn, _compiler));
      await txn.commit();
      return result;
    } catch (e) {
      await txn.rollback();
      rethrow;
    }
  }
}
```

**The execution flow:**

```
JsonQuery → SqlCompiler → SqlQuery → Adapter → SqlResultSet → List<Map>
```

---

## Phase 6: Relations & JOINs

### File: `lib/src/runtime/schema/schema_registry.dart`

**What you'll learn:**
- How relation metadata is stored
- The structure of model schemas

```dart
class SchemaRegistry {
  final Map<String, ModelSchema> _models = {};

  void registerModel(ModelSchema schema);
  ModelSchema? getModel(String name);
  RelationInfo? getRelation(String model, String field);
}

class RelationInfo {
  final String type;        // 'one-to-one', 'one-to-many', 'many-to-many'
  final String targetModel; // Related model name
  final String foreignKey;  // FK column
  final String? joinTable;  // For many-to-many
}
```

### File: `lib/src/runtime/query/relation_compiler.dart`

**What you'll learn:**
- How `include: {posts: true}` generates JOINs
- Nesting flat rows into objects

```dart
class RelationCompiler {
  /// Generate JOIN clause for a relation
  String compileJoin(String baseTable, String relationName, RelationInfo info) {
    return switch (info.type) {
      'one-to-many' =>
        'LEFT JOIN "${info.targetModel}" ON "${info.targetModel}"."${info.foreignKey}" = "$baseTable"."id"',
      'many-to-many' =>
        'LEFT JOIN "${info.joinTable}" ON ... LEFT JOIN "${info.targetModel}" ON ...',
      _ => '',
    };
  }

  /// Nest flat JOIN results into objects
  List<Map<String, dynamic>> nestResults(
    List<Map<String, dynamic>> flatRows,
    Map<String, dynamic> include,
  );
}
```

---

## Phase 7: Error Handling & Logging

### File: `lib/src/runtime/errors/prisma_exceptions.dart`

**What you'll learn:**
- Typed exception hierarchy
- Mapping database errors to meaningful exceptions

```dart
sealed class PrismaException implements Exception {
  final String message;
  final String? code;
}

class UniqueConstraintException extends PrismaException {
  final String field;   // Which field violated the constraint
  final dynamic value;  // The duplicate value
}

class ForeignKeyException extends PrismaException {
  final String? constraintName;
}

class RecordNotFoundException extends PrismaException {}
```

### File: `lib/src/runtime/logging/query_logger.dart`

**What you'll learn:**
- Query lifecycle events
- Performance metrics collection

```dart
abstract class QueryLogger {
  void onQueryStart(QueryStartEvent event);
  void onQueryEnd(QueryEndEvent event);
  void onQueryError(QueryErrorEvent event);
}

class MetricsQueryLogger implements QueryLogger {
  int get queryCount;
  Duration get totalDuration;
  Duration get averageDuration;
  Duration get minDuration;
  Duration get maxDuration;
}
```

---

## Phase 8: Code Generation

### File: `lib/src/generator/prisma_parser.dart`

**What you'll learn:**
- How to parse the Prisma schema DSL
- Extracting models, fields, relations, enums

**The parser extracts:**

```dart
class ParsedModel {
  final String name;          // "User"
  final String tableName;     // "users" (from @@map)
  final List<ParsedField> fields;
  final List<ParsedRelation> relations;
}

class ParsedField {
  final String name;          // "email"
  final String type;          // "String"
  final bool isRequired;
  final bool isUnique;
  final String? defaultValue; // "uuid()", "now()"
}
```

### File: `lib/src/generator/model_generator.dart`

**What you'll learn:**
- Generating Freezed classes from parsed models

```dart
// Input: ParsedModel
// Output: Dart code

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

### File: `lib/src/generator/delegate_generator.dart`

**What you'll learn:**
- Generating CRUD operations for each model

```dart
// Generated delegate
class UserDelegate {
  Future<User?> findUnique({required UserWhereUniqueInput where});
  Future<List<User>> findMany({UserWhereInput? where, UserOrderByInput? orderBy});
  Future<User> create({required UserCreateInput data});
  Future<User> update({required UserWhereUniqueInput where, required UserUpdateInput data});
  Future<User> delete({required UserWhereUniqueInput where});
}
```

### File: `bin/generate.dart`

**What you'll learn:**
- CLI orchestration
- Putting it all together

```dart
void main(List<String> args) async {
  // 1. Parse arguments (schema path, output path, --server flag)
  // 2. Read and parse schema.prisma
  // 3. Generate models, delegates, filters, client
  // 4. Write files to output directory
}
```

---

## The "Aha!" Moments

As you study the codebase, you'll have these realizations:

| File | Aha! Moment |
|------|-------------|
| `types.dart` | "Oh, the adapter is just `query(sql, params) → rows`" |
| `json_protocol.dart` | "Queries are just JSON objects, not SQL strings" |
| `sql_compiler.dart` | "This is where all the SQL magic happens" |
| `query_executor.dart` | "It's just: compile → execute → convert" |
| `relation_compiler.dart` | "JOINs are generated from schema metadata" |
| `prisma_parser.dart` | "Schema parsing is just regex + state machine" |
| `model_generator.dart` | "Code generation is string concatenation with templates" |

---

## Recommended Reading Order

```
1. types.dart              (30 min) - Foundation
2. postgres_adapter.dart   (45 min) - See a real implementation
3. json_protocol.dart      (30 min) - Understand query representation
4. sql_compiler.dart       (2 hours) - The core logic
5. query_executor.dart     (45 min) - Tying it together
6. prisma_exceptions.dart  (15 min) - Error handling
7. query_logger.dart       (15 min) - Observability
8. schema_registry.dart    (30 min) - Relation metadata
9. relation_compiler.dart  (45 min) - JOIN generation
10. prisma_parser.dart     (1 hour) - Schema parsing
11. model_generator.dart   (45 min) - Code generation
12. delegate_generator.dart (45 min) - CRUD generation
```

**Total: ~8 hours for deep understanding**

---

## Next Steps

After understanding the architecture:

1. **Run the tests** - `dart test` to see the system in action
2. **Add a feature** - Try adding a new filter operator
3. **Debug a query** - Add `ConsoleQueryLogger` and trace a query
4. **Generate code** - Run the generator on a real Prisma schema

Good luck! The codebase is complex but logical once you understand the data flow.
