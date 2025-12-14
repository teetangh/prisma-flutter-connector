# Changelog

All notable changes to the Prisma Flutter Connector.

## [Unreleased]

## [0.1.1] - 2025-12-14

### Added
- Automated publishing via GitHub Actions (OIDC authentication)
- pub.dev package metadata (topics, homepage, repository)

### Changed
- Renamed `docs/` to `doc/` (pub.dev convention)
- Renamed `examples/` to `example/` (pub.dev convention)
- Renamed `Readme.md` to `README.md` (pub.dev convention)

### Removed
- Removed prisma-submodule (not needed for package users)

---

## [0.1.0] - 2025-12-14

### 🎉 MAJOR: Architecture Transformation - True Prisma-Style ORM for Dart

This release represents a **revolutionary transformation** from a GraphQL client generator to a **true Prisma-style ORM** for Dart/Flutter - enabling direct database access similar to how Prisma works in TypeScript/Next.js!

### ✨ Added - Direct Database Access

#### Database Adapter System
- **`SqlDriverAdapter`** interface - Database-agnostic query execution
- **`PostgresAdapter`** - Direct PostgreSQL connection (`postgres` package)
- **`SupabaseAdapter`** - Direct Supabase connection (no backend!)
- **`SQLiteAdapter`** - Mobile offline-first support (`sqflite`)
- Full transaction support with ACID guarantees
- Connection pooling and type conversion

#### Query System
- **JSON Protocol** - Prisma's query protocol in pure Dart
- **SQL Compiler** - Converts JSON queries → Parameterized SQL
- **Query Executor** - Runtime execution with type-safe results
- **Filter Operators** - WHERE clauses (equals, in, contains, lt, gt, etc.)

### ✅ Validated with Real Database

All CRUD operations tested and working with Supabase:
- ✅ **CREATE** - Insert with UUID generation
- ✅ **READ** - findMany, findUnique with complex filters
- ✅ **UPDATE** - Modify records
- ✅ **DELETE** - Remove records
- ✅ **COUNT** - Aggregate queries
- ✅ **FILTER** - Complex WHERE with AND/OR/NOT
- ✅ **Transactions** - Atomic operations with rollback

### 🚀 Key Benefits

1. **No Backend Required** - Connect directly from Dart to databases
2. **Offline-First** - SQLite adapter for mobile apps
3. **Type-Safe** - Parameterized queries with full type conversion
4. **Database-Agnostic** - Swap adapters without code changes
5. **Better Performance** - No HTTP/GraphQL overhead
6. **Familiar DX** - Same API as Prisma in TypeScript

### 📦 New Dependencies

```yaml
dependencies:
  postgres: ^3.0.0          # PostgreSQL support
  sqflite: ^2.3.0           # Mobile SQLite support
  supabase_flutter: ^2.5.0  # Supabase integration
```

### 📁 New Files

Runtime Library:
- `lib/runtime.dart` - Main runtime export
- `lib/src/runtime/adapters/types.dart` - Core types
- `lib/src/runtime/adapters/postgres_adapter.dart`
- `lib/src/runtime/adapters/supabase_adapter.dart`
- `lib/src/runtime/adapters/sqlite_adapter.dart`
- `lib/src/runtime/query/json_protocol.dart`
- `lib/src/runtime/query/sql_compiler.dart`
- `lib/src/runtime/query/query_executor.dart`

Examples & Tests:
- `test/validation/crud_validation.dart` - Full CRUD validation
- `example/adapter_example.dart` - Usage examples

### 💻 Usage Example

```dart
import 'package:prisma_flutter_connector/runtime.dart';
import 'package:postgres/postgres.dart' as pg;

// Connect to database
final connection = await pg.Connection.open(
  pg.Endpoint(host: 'localhost', database: 'mydb'),
);

final adapter = PostgresAdapter(connection);
final executor = QueryExecutor(adapter: adapter);

// Build query
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({'email': FilterOperators.contains('@example.com')})
    .orderBy({'createdAt': 'desc'})
    .build();

// Execute
final users = await executor.executeQueryAsMaps(query);
print('Found ${users.length} users');
```

### 🗺️ Roadmap

**Phase 3: Code Generation** (Next)
- Update generator to produce adapter-based client
- Type-safe generated client from Prisma schema
- Auto-generated CRUD methods per model

**Phase 4: Advanced Features**
- Relation loading (include, select)
- Nested writes
- Aggregations (avg, sum, min, max)
- Raw SQL queries

**Phase 5: Publication**
- pub.dev release
- Comprehensive documentation
- Example applications

---

## 0.1.0 - 2025-11-01

### Added
- Initial release of Prisma Flutter Connector
- GraphQL client integration using Ferry
- Type-safe models with Freezed
- E-commerce example (Product, Order, User models)
- Basic CRUD operations (queries and mutations)
- Error handling with custom exceptions
- Backend example using Prisma + Pothos + Apollo Server
- Comprehensive documentation

### Architecture
- GraphQL API protocol (chosen over REST for better Prisma integration)
- Pothos for GraphQL schema generation from Prisma
- Ferry for type-safe Dart code generation
- No offline caching in v0.1.0 (planned for v0.2.0)
