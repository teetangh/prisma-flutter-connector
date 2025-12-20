# Prisma Flutter Connector - Architecture Overview

## Why Building an ORM is Hard

Building an ORM/database connector is essentially building **4 compilers in one system**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        THE ORM PROBLEM                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Schema Definition    →    Code Generator    →    Generated Code   │
│   (Prisma DSL)              (Parser + Writer)      (Dart classes)   │
│                                                                      │
│   Query Builder        →    SQL Compiler      →    Raw SQL          │
│   (JSON Protocol)           (AST → SQL)            (Parameterized)  │
│                                                                      │
│   Raw SQL              →    DB Adapter        →    Result Set       │
│   (Provider-specific)       (Execute)              (Rows/Columns)   │
│                                                                      │
│   Result Set           →    Deserializer      →    Dart Objects     │
│   (Flat rows)               (Type conversion)      (Nested maps)    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### The Hard Parts

| Challenge | Description |
|-----------|-------------|
| **Schema Parsing** | Parse a DSL (Prisma schema) with relations, enums, defaults, attributes |
| **Code Generation** | Generate type-safe Dart code that matches the schema exactly |
| **Query Translation** | Convert high-level queries to provider-specific SQL dialects |
| **Type System Bridging** | Map database types ↔ Dart types (DateTime, enums, JSON, arrays) |
| **Relation Handling** | JOINs, nested writes, eager loading, N+1 query prevention |
| **Error Mapping** | Convert cryptic database errors to meaningful typed exceptions |
| **Multi-DB Support** | PostgreSQL, MySQL, SQLite all have different SQL syntax |

---

## Folder Hierarchy

```
prisma-flutter-connector/
│
├── bin/
│   └── generate.dart              # CLI entry point for code generation
│
├── lib/
│   ├── prisma_flutter_connector.dart  # Package export (generator)
│   ├── runtime.dart                   # Runtime export (Flutter apps)
│   ├── runtime_server.dart            # Runtime export (Dart servers)
│   │
│   └── src/
│       │
│       ├── generator/                 # 🔧 CODE GENERATION (compile-time)
│       │   ├── prisma_parser.dart     #   Parse .prisma schema file
│       │   ├── string_utils.dart      #   Naming utilities (camelCase, snake_case)
│       │   ├── model_generator.dart   #   Generate Freezed model classes
│       │   ├── delegate_generator.dart#   Generate CRUD delegate classes
│       │   ├── filter_generator.dart  #   Generate filter input types
│       │   ├── filter_types_generator.dart # Generate WhereInput classes
│       │   ├── client_generator.dart  #   Generate PrismaClient class
│       │   └── api_generator.dart     #   Generate API layer (legacy)
│       │
│       ├── runtime/                   # ⚡ RUNTIME (execution-time)
│       │   │
│       │   ├── adapters/              # DATABASE ADAPTERS (Layer 1)
│       │   │   ├── types.dart         #   Core interfaces & types
│       │   │   ├── postgres_adapter.dart  # PostgreSQL implementation
│       │   │   ├── supabase_adapter.dart  # Supabase implementation
│       │   │   ├── sqlite_adapter.dart    # SQLite implementation
│       │   │   └── adapters.dart      #   Barrel export
│       │   │
│       │   ├── query/                 # QUERY SYSTEM (Layer 2)
│       │   │   ├── json_protocol.dart #   Query builder (Prisma JSON protocol)
│       │   │   ├── sql_compiler.dart  #   JSON → SQL translation
│       │   │   ├── relation_compiler.dart # JOIN clause generation
│       │   │   └── query_executor.dart#   Execute queries & map results
│       │   │
│       │   ├── schema/                # SCHEMA METADATA (Layer 3)
│       │   │   └── schema_registry.dart # Relation metadata for JOINs
│       │   │
│       │   ├── errors/                # ERROR HANDLING
│       │   │   └── prisma_exceptions.dart # Typed exceptions (P2002, etc.)
│       │   │
│       │   └── logging/               # OBSERVABILITY
│       │       └── query_logger.dart  #   Query logging & metrics
│       │
│       ├── client/                    # CLIENT (legacy GraphQL)
│       │   └── ...                    #   (Not used in direct DB mode)
│       │
│       └── exceptions/                # EXCEPTIONS (legacy)
│           └── ...                    #   (Superseded by runtime/errors/)
```

---

## Data Flow Diagram

### Compile Time (Code Generation)

```
┌────────────────────────────────────────────────────────────────────────┐
│                         COMPILE TIME                                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   schema.prisma  ──►  prisma_parser.dart  ──►  model_generator.dart    │
│                              │                        │                 │
│                              │                        ▼                 │
│                              │               generated/models/*.dart    │
│                              │                        │                 │
│                              └──►  delegate_generator.dart              │
│                                           │                             │
│                                           ▼                             │
│                                  generated/delegates/*.dart             │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

### Runtime (Query Execution)

```
┌────────────────────────────────────────────────────────────────────────┐
│                          RUNTIME                                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Your Code                                                             │
│      │                                                                  │
│      ▼                                                                  │
│   JsonQueryBuilder  ──►  json_protocol.dart  ──►  JsonQuery            │
│      │                                               │                  │
│      │                                               ▼                  │
│      │                                        sql_compiler.dart         │
│      │                                               │                  │
│      │                                               ▼                  │
│      │                                        SqlQuery (parameterized)  │
│      │                                               │                  │
│      ▼                                               ▼                  │
│   query_executor.dart  ◄─────────────────►  postgres_adapter.dart      │
│      │                                               │                  │
│      │                                               ▼                  │
│      │                                        PostgreSQL Database       │
│      │                                               │                  │
│      ▼                                               │                  │
│   List<Map<String, dynamic>>  ◄──────────────────────┘                 │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## File Responsibility Reference

| File | One-Line Summary |
|------|------------------|
| `types.dart` | Core interfaces every adapter must implement |
| `postgres_adapter.dart` | Execute SQL on PostgreSQL, handle type conversion |
| `supabase_adapter.dart` | Execute SQL on Supabase (PostgreSQL-based) |
| `sqlite_adapter.dart` | Execute SQL on SQLite for mobile offline-first |
| `json_protocol.dart` | Build queries as JSON objects (Prisma protocol) |
| `sql_compiler.dart` | Convert JSON queries to parameterized SQL strings |
| `relation_compiler.dart` | Generate LEFT JOIN clauses for relations |
| `query_executor.dart` | Orchestrate: compile → execute → map results |
| `schema_registry.dart` | Store relation metadata from Prisma schema |
| `prisma_exceptions.dart` | Typed errors (UniqueConstraint, ForeignKey, etc.) |
| `query_logger.dart` | Log queries for debugging and metrics |
| `prisma_parser.dart` | Parse .prisma schema files into AST |
| `model_generator.dart` | Generate Freezed model classes from AST |
| `delegate_generator.dart` | Generate CRUD operations for each model |
| `string_utils.dart` | Naming conventions (camelCase, snake_case, etc.) |

---

## Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      YOUR APPLICATION                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Generated PrismaClient                   │  │
│   │  (Type-safe API: prisma.user.findMany(), etc.)       │  │
│   └──────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Query Executor Layer                     │  │
│   │  (Compiles queries, executes, maps results)          │  │
│   └──────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Database Adapter Layer                   │  │
│   │  (PostgreSQL | Supabase | SQLite)                    │  │
│   └──────────────────────────────────────────────────────┘  │
│                            │                                 │
│                            ▼                                 │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                   Database                            │  │
│   │  (PostgreSQL Server | Supabase Cloud | SQLite File)  │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

### 1. JSON Protocol (Prisma's Query Language)

Queries are represented as JSON objects, not SQL strings:

```dart
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({'email': FilterOperators.contains('@example.com')})
    .orderBy({'createdAt': 'desc'})
    .take(10)
    .build();
```

### 2. SQL Compilation

The JSON query is compiled to provider-specific SQL:

```sql
-- PostgreSQL
SELECT * FROM "User" WHERE "email" LIKE '%@example.com%'
ORDER BY "createdAt" DESC LIMIT 10

-- MySQL
SELECT * FROM `User` WHERE `email` LIKE '%@example.com%'
ORDER BY `createdAt` DESC LIMIT 10

-- SQLite
SELECT * FROM "User" WHERE "email" LIKE '%@example.com%'
ORDER BY "createdAt" DESC LIMIT 10
```

### 3. Type Conversion

Database types are mapped to Dart types:

| Database Type | Dart Type |
|---------------|-----------|
| `VARCHAR`, `TEXT` | `String` |
| `INTEGER`, `BIGINT` | `int` |
| `DECIMAL`, `FLOAT` | `double` |
| `BOOLEAN` | `bool` |
| `TIMESTAMP` | `DateTime` |
| `JSON`, `JSONB` | `Map<String, dynamic>` |
| `ARRAY` | `List<T>` |
| `ENUM` | Generated Dart enum |

### 4. Error Codes

Database errors are mapped to typed exceptions:

| Code | Exception | Meaning |
|------|-----------|---------|
| P2002 | `UniqueConstraintException` | Duplicate key violation |
| P2003 | `ForeignKeyException` | Invalid foreign key reference |
| P2025 | `RecordNotFoundException` | Record not found |
| P5008 | `QueryTimeoutException` | Query execution timeout |
| P5000 | `InternalException` | General database error |

---

## Next Steps

See [study-guide.md](./study-guide.md) for a recommended learning path through the codebase.
