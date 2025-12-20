# Prisma Flutter Connector - How It Works

## The Simple Answer

**Prisma Flutter Connector does NOT use Prisma's TypeScript engine.** It only uses Prisma's `.prisma` schema file format as a source of truth to generate Dart code.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    WHAT YOU MIGHT THINK                             │
│                                                                     │
│   Flutter App  ──→  Prisma (Node.js)  ──→  Database                │
│                         ❌ WRONG!                                   │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    WHAT ACTUALLY HAPPENS                            │
│                                                                     │
│   schema.prisma  ──→  Code Generator  ──→  Pure Dart Code          │
│       (text)           (Dart tool)          (runs natively)        │
│                                                  │                  │
│                                                  ▼                  │
│                               Flutter App  ──→  Database           │
│                                        (directly!)                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## The Two Phases

### Phase 1: Code Generation (One-time, at build time)

```
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  schema.prisma   │      │  Dart Generator  │      │  Generated Code  │
│                  │  ──→ │                  │  ──→ │                  │
│  model User {    │      │  Parses text     │      │  class User {}   │
│    id String     │      │  Generates code  │      │  UserDelegate    │
│    email String  │      │                  │      │  PrismaClient    │
│  }               │      │                  │      │  Filters, etc.   │
└──────────────────┘      └──────────────────┘      └──────────────────┘
     TEXT FILE              DART PROGRAM              DART FILES
```

**The generator is pure Dart** - it reads your schema.prisma file as plain text, parses it, and outputs Dart code. No Node.js, no Prisma engine, no TypeScript involved!

### Phase 2: Runtime (Every query)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         YOUR FLUTTER APP                            │
│                                                                     │
│   final users = await prisma.user.findMany(                        │
│     where: UserWhereInput(email: StringFilter(contains: '@gmail')) │
│   );                                                                │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│              GENERATED PRISMA CLIENT (Pure Dart)                    │
│                                                                     │
│   UserDelegate.findMany() {                                        │
│     1. Build JSON query object                                     │
│     2. Call QueryExecutor                                          │
│   }                                                                 │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    SQL COMPILER (Pure Dart)                         │
│                                                                     │
│   JSON: {model: "User", where: {email: {contains: "@gmail"}}}      │
│                           ↓                                         │
│   SQL:  SELECT * FROM "User" WHERE "email" LIKE '%@gmail%'         │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    DATABASE ADAPTER                                 │
│                                                                     │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                     │
│   │ Postgres │    │ SQLite   │    │ Supabase │                     │
│   └────┬─────┘    └────┬─────┘    └────┬─────┘                     │
│        │               │               │                            │
│        └───────────────┴───────────────┘                            │
│                        │                                            │
└────────────────────────┼────────────────────────────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │      DATABASE       │
              │   PostgreSQL/SQLite │
              └─────────────────────┘
```

---

## Why Use Prisma Schema at All?

Prisma's `.prisma` schema format is excellent because:

1. **Human-readable** - Easy to understand
2. **Well-documented** - Lots of resources
3. **IDE support** - Syntax highlighting, autocomplete
4. **Feature-rich** - Relations, enums, defaults, indexes

```prisma
// This is just a text format - no Prisma engine needed to parse it!

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  posts     Post[]   // Relation
  createdAt DateTime @default(now())
}

model Post {
  id       String @id @default(cuid())
  title    String
  content  String?
  author   User   @relation(fields: [authorId], references: [id])
  authorId String
}
```

---

## The Architecture in Detail

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CODE GENERATION                              │
│                     (runs once via CLI)                             │
│                                                                     │
│  ┌─────────────┐                                                   │
│  │ Prisma      │                                                   │
│  │ Parser      │──→ Reads schema.prisma                            │
│  │             │    Extracts models, fields, relations, enums      │
│  └──────┬──────┘                                                   │
│         │                                                          │
│         ▼                                                          │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    GENERATORS                               │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │   │
│  │  │   Model     │  │  Delegate   │  │   Filter    │         │   │
│  │  │  Generator  │  │  Generator  │  │  Generator  │         │   │
│  │  │             │  │             │  │             │         │   │
│  │  │ User.dart   │  │ UserDeleg.  │  │ StringFilt. │         │   │
│  │  │ Post.dart   │  │ PostDeleg.  │  │ IntFilter   │         │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘         │   │
│  │                                                             │   │
│  │  ┌─────────────┐                                           │   │
│  │  │   Client    │                                           │   │
│  │  │  Generator  │ ──→ PrismaClient class                    │   │
│  │  └─────────────┘                                           │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ Generates
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RUNTIME LIBRARY                                │
│                  (used by your Flutter app)                         │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    PrismaClient                              │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐               │  │
│  │  │ .user      │ │ .post      │ │ .comment   │  Delegates    │  │
│  │  └─────┬──────┘ └─────┬──────┘ └─────┬──────┘               │  │
│  └────────┼──────────────┼──────────────┼───────────────────────┘  │
│           │              │              │                          │
│           └──────────────┼──────────────┘                          │
│                          │                                          │
│                          ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   Query Executor                             │  │
│  │                                                              │  │
│  │  1. Receives typed method calls                              │  │
│  │  2. Builds JSON query representation                         │  │
│  │  3. Compiles JSON ──→ SQL                                    │  │
│  │  4. Sends SQL to adapter                                     │  │
│  │  5. Deserializes results to Dart objects                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    SQL Compiler                              │  │
│  │                                                              │  │
│  │  Converts JSON queries to SQL strings                        │  │
│  │  Handles different SQL dialects (Postgres vs SQLite)         │  │
│  │  Creates parameterized queries (prevents SQL injection)      │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                          │                                          │
│                          ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                  Database Adapters                           │  │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐         │  │
│  │  │   Postgres   │ │    SQLite    │ │   Supabase   │         │  │
│  │  │   Adapter    │ │   Adapter    │ │   Adapter    │         │  │
│  │  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘         │  │
│  └─────────┼────────────────┼────────────────┼──────────────────┘  │
└────────────┼────────────────┼────────────────┼──────────────────────┘
             │                │                │
             ▼                ▼                ▼
        PostgreSQL        SQLite file      Supabase Cloud
```

---

## Comparison: Original Prisma vs This Connector

| Aspect | Original Prisma (TypeScript) | This Connector (Dart) |
|--------|------------------------------|----------------------|
| **Language** | TypeScript/JavaScript | Pure Dart |
| **Engine** | Rust binary (Query Engine) | No engine - pure Dart SQL |
| **Schema** | `.prisma` files | Same `.prisma` files |
| **Code Gen** | `prisma generate` (Node.js) | `dart run generate` |
| **Runtime** | Node.js process | Flutter/Dart native |
| **Query Protocol** | JSON over HTTP to engine | JSON compiled to SQL in-app |
| **Databases** | All SQL + MongoDB | PostgreSQL, SQLite, Supabase |

---

## Possible Limitations

### 1. Feature Parity with Original Prisma
```
Original Prisma Features          This Connector
─────────────────────────────────────────────────
Migrations                        ❌ Not implemented (use Prisma CLI)
Introspection                     ❌ Not implemented
Raw SQL queries                   ✅ Supported
Nested writes                     ⚠️ Partial
Transactions                      ✅ Supported
Aggregations                      ✅ Supported
Group By                          ✅ Supported
Full-text search                  ❌ Not implemented
Middleware                        ❌ Not implemented
Logging/Metrics                   ⚠️ Basic
```

### 2. SQL Dialect Coverage
```
Not all SQL features are equal across databases:

PostgreSQL          SQLite              MySQL
────────────────────────────────────────────────
Arrays ✅           Arrays ❌            Arrays ❌
JSON/JSONB ✅       JSON ⚠️ (limited)   JSON ✅
UUID native ✅      UUID as text        UUID as text
RETURNING ✅        RETURNING ⚠️        No RETURNING
Window functions ✅  Limited             Limited
```

### 3. Relation Handling Complexity
```
Simple relations (1:1, 1:N)     → ✅ Well supported
Many-to-many explicit           → ✅ Supported
Many-to-many implicit           → ⚠️ May need manual join tables
Self-referential                → ⚠️ Limited testing
Deeply nested includes          → ⚠️ Performance concerns
```

### 4. No Prisma Migrate
```
You CANNOT do this:
  prisma migrate dev  ❌  (This is TypeScript/Node.js)

You MUST use:
  - Prisma CLI separately for migrations (Node.js required)
  - Raw SQL migration files
  - Another Dart migration tool
```

---

## What's the Best You Can Achieve?

### Ideal Use Cases

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PERFECT FIT SCENARIOS                            │
│                                                                     │
│  1. FLUTTER MOBILE APPS WITH OFFLINE SUPPORT                       │
│     ┌─────────┐                                                    │
│     │ Flutter │ ──→ SQLite ──→ Local database, works offline      │
│     │   App   │                                                    │
│     └─────────┘                                                    │
│                                                                     │
│  2. FLUTTER + SUPABASE                                             │
│     ┌─────────┐                                                    │
│     │ Flutter │ ──→ Supabase ──→ Postgres with auth built-in      │
│     │   App   │                                                    │
│     └─────────┘                                                    │
│                                                                     │
│  3. DART BACKEND SERVERS (Dart Frog, Shelf)                        │
│     ┌─────────┐                                                    │
│     │  Dart   │ ──→ PostgreSQL ──→ Production database            │
│     │ Server  │                                                    │
│     └─────────┘                                                    │
│                                                                     │
│  4. SHARED SCHEMA BETWEEN NODE.JS AND DART                         │
│     ┌──────────────────────────────────────────┐                   │
│     │           schema.prisma                  │                   │
│     └────────────────┬─────────────────────────┘                   │
│                      │                                              │
│          ┌───────────┴───────────┐                                 │
│          ▼                       ▼                                 │
│     Node.js Backend         Flutter App                            │
│     (original Prisma)       (this connector)                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Maximum Potential

```
What you CAN achieve:

✅ Type-safe database queries in Dart
✅ IDE autocomplete for all models and fields
✅ Compile-time checking (wrong field names = build error)
✅ Clean separation of concerns (models, queries, adapters)
✅ Multiple database support from same codebase
✅ Offline-first apps with SQLite
✅ Real-time subscriptions via Supabase adapter
✅ Transactions with isolation levels
✅ Complex queries (joins, aggregations, grouping)
✅ Computed fields via correlated subqueries

What you CANNOT achieve (limitations):

❌ Zero configuration (need to run generator)
❌ Schema migrations from Dart (need Node.js Prisma)
❌ 100% Prisma feature parity
❌ MongoDB support (yet)
❌ MySQL support (yet)
❌ Prisma Studio integration
```

---

## Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                         THE KEY INSIGHT                             │
│                                                                     │
│   This project RE-IMPLEMENTS Prisma's concepts in pure Dart.        │
│   It doesn't "connect" to Prisma - it REPLACES the TypeScript       │
│   parts with Dart equivalents.                                      │
│                                                                     │
│   schema.prisma  ─→  Is just a well-designed text format            │
│   Code Generator ─→  Pure Dart, no Node.js                          │
│   Runtime        ─→  Pure Dart, no Prisma engine                    │
│   SQL Compiler   ─→  Dart code that writes SQL strings              │
│   Adapters       ─→  Thin wrappers around DB driver packages        │
│                                                                     │
│   RESULT: A native Dart/Flutter ORM that happens to use             │
│           Prisma's excellent schema format.                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```
