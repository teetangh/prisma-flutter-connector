# Changelog

All notable changes to the Prisma Flutter Connector.

## [Unreleased]

## [0.2.6] - 2025-12-19

### Added
- **Computed Fields (Correlated Subqueries)** - Add computed fields via correlated subqueries in SELECT
  - `ComputedField.min()` - MIN aggregate subquery
  - `ComputedField.max()` - MAX aggregate subquery
  - `ComputedField.avg()` - AVG aggregate subquery
  - `ComputedField.sum()` - SUM aggregate subquery
  - `ComputedField.count()` - COUNT aggregate subquery
  - `ComputedField.first()` - Fetch first matching value with ORDER BY
  - `FieldRef` class for referencing parent table columns in subqueries

### Example Usage
```dart
// Computed fields for inline aggregations
final query = JsonQueryBuilder()
    .model('ConsultantProfile')
    .action(QueryAction.findMany)
    .computed({
      'minPrice': ComputedField.min('price',
        from: 'ConsultationPlan',
        where: {'consultantProfileId': FieldRef('id')}),
      'priceCurrency': ComputedField.first('priceCurrency',
        from: 'ConsultationPlan',
        where: {'consultantProfileId': FieldRef('id')},
        orderBy: {'price': 'asc'}),
    })
    .where({'isVerified': true})
    .orderBy({'rating': 'desc'})
    .build();

// Generates:
// SELECT "t0".*,
//   (SELECT MIN("price") FROM "ConsultationPlan"
//    WHERE "consultantProfileId" = "t0"."id") AS "minPrice",
//   (SELECT "priceCurrency" FROM "ConsultationPlan"
//    WHERE "consultantProfileId" = "t0"."id"
//    ORDER BY "price" ASC LIMIT 1) AS "priceCurrency"
// FROM "ConsultantProfile" "t0"
// WHERE "isVerified" = $1
// ORDER BY "rating" DESC
```

### Fixed
- **Alias conflict with include + computed** - Fixed "table name 't0' specified more than once" error by adding `startingCounter` parameter to RelationCompiler
- **Missing relation columns in SELECT** - Relations now correctly included in query results when using `include()` with computed fields
- **Ambiguous column names with JOINs** - Added table alias prefix to WHERE and ORDER BY clauses when JOINs are present
- **Aggregate FILTER parameter numbering** - Fixed "could not determine data type of parameter" error by using sequential parameter numbering instead of hardcoded offset
- **Computed field WHERE clause parameterization** - Values in computed field subqueries now use parameterized queries instead of direct interpolation for improved security
- **selectFields respects dot notation** - When using `selectFields(['user.name'])`, only explicitly requested relation columns are fetched instead of all columns

### Backward Compatibility
- All existing query features remain unchanged
- Computed fields are optional - queries without `.computed()` work exactly as before
- Works with `selectFields()`, `where()`, `orderBy()`, and pagination

---

## [0.2.5] - 2025-12-19

### Added
- **Select Specific Fields** - New `selectFields()` method to select specific columns instead of `SELECT *`
  - Reduces network overhead by fetching only needed columns
  - Supports dot notation for related fields (e.g., `category.name`) when used with `include()`
  - Works with all query types: `findMany`, `findFirst`, `findUnique`
  - Compatible with WHERE, ORDER BY, and pagination

- **FILTER Clause for Aggregations** (PostgreSQL/Supabase only)
  - New `_countFiltered` aggregation for conditional COUNT
  - Enables rating distributions, conditional stats in single query
  - Falls back gracefully for MySQL/SQLite (not supported)

- **Include with Select** - Select specific fields from included relations
  - `include: {'user': {'select': {'name': true, 'image': true}}}`
  - Only fetches requested columns from related tables
  - Reduces data transfer for large relations

### Example Usage
```dart
// Select specific scalar fields
final query = JsonQueryBuilder()
    .model('Product')
    .action(QueryAction.findMany)
    .selectFields(['id', 'name', 'price', 'rating'])
    .where({'isActive': true})
    .orderBy({'price': 'asc'})
    .take(10)
    .build();

// Generates: SELECT "id", "name", "price", "rating" FROM "Product"
//            WHERE "isActive" = $1 ORDER BY "price" ASC LIMIT 10

// Aggregation with FILTER clause (rating distribution)
final statsQuery = JsonQueryBuilder()
    .model('ConsultantReview')
    .action(QueryAction.aggregate)
    .aggregation({
      '_count': true,
      '_avg': {'rating': true},
      '_countFiltered': [
        {'alias': 'fiveStar', 'filter': {'rating': 5}},
        {'alias': 'fourStar', 'filter': {'rating': 4}},
        {'alias': 'threeStar', 'filter': {'rating': 3}},
      ],
    })
    .where({'consultantProfileId': 'consultant-123'})
    .build();

// Generates: SELECT COUNT(*) AS "_count", AVG("rating") AS "_avg_rating",
//   COUNT(*) FILTER (WHERE "rating" = $1) AS "fiveStar",
//   COUNT(*) FILTER (WHERE "rating" = $2) AS "fourStar", ...
```

### Backward Compatibility
- Existing `.select(Map)` syntax continues to work
- Default behavior (no selectFields) remains `SELECT *`
- FILTER clause silently ignored on unsupported providers

---

## [0.2.4] - 2025-12-19

### Added
- **Relation Filtering SQL Compilation** - Compile `some`/`every`/`none` operators to EXISTS subqueries
  - **One-to-Many**: `EXISTS (SELECT 1 FROM related WHERE related.fk = parent.id AND ...)`
  - **Many-to-Many**: `EXISTS (SELECT 1 FROM junction INNER JOIN target ON ... WHERE junction.A = parent.id AND ...)`
  - **One-to-One**: Handles both owner and non-owner sides correctly
  - All providers supported (PostgreSQL, Supabase, MySQL, SQLite)

- **Relation Filter Operators**
  - `some` → `EXISTS (...)` - At least one match
  - `none` → `NOT EXISTS (...)` - No matches
  - `every` → `NOT EXISTS (... AND NOT condition)` - All match
  - `isEmpty()` → `NOT EXISTS (...)` with no condition
  - `isNotEmpty()` → `EXISTS (...)` with no condition

### Example Usage
```dart
// Register schema with relation metadata
final schema = SchemaRegistry();
schema.registerModel(ModelSchema(
  name: 'Product',
  tableName: 'Product',
  fields: {...},
  relations: {
    'reviews': RelationInfo(
      name: 'reviews',
      type: RelationType.oneToMany,
      targetModel: 'Review',
      foreignKey: 'productId',
      references: ['id'],
    ),
    'categories': RelationInfo(
      name: 'categories',
      type: RelationType.manyToMany,
      targetModel: 'Category',
      joinTable: '_ProductToCategory',
      joinColumn: 'A',
      inverseJoinColumn: 'B',
      foreignKey: '',
      references: ['id'],
    ),
  },
));

// Query with relation filters
final query = JsonQueryBuilder()
    .model('Product')
    .action(QueryAction.findMany)
    .where({
      'isActive': true,
      'reviews': FilterOperators.some({
        'rating': FilterOperators.gte(4),
      }),
      'categories': FilterOperators.some({
        'id': 'category-electronics',
      }),
    })
    .orderBy({
      'price': {'sort': 'asc', 'nulls': 'last'},
    })
    .build();

final compiler = SqlCompiler(provider: 'postgresql', schema: schema);
final sql = compiler.compile(query);
// Generates:
// SELECT * FROM "Product" WHERE "isActive" = $1
// AND EXISTS (SELECT 1 FROM "Review" WHERE "Review"."productId" = "Product"."id" AND "rating" >= $2)
// AND EXISTS (SELECT 1 FROM "_ProductToCategory" INNER JOIN "Category" ON "Category"."id" = "_ProductToCategory"."B" WHERE "_ProductToCategory"."A" = "Product"."id" AND "id" = $3)
// ORDER BY "price" ASC NULLS LAST
```

### Why This Matters
Previously, filtering on relations required raw SQL with manual EXISTS subqueries. Now you can:
- Use the same type-safe `FilterOperators` API for relation filters
- Automatically generate correct JOIN patterns for M:N relations
- Combine scalar filters with relation filters in a single query
- Support all relation types (1:N, N:1, 1:1, M:N)

## [0.2.3] - 2025-12-19

### Added
- **NULLS LAST/FIRST Ordering** - Extended `orderBy` syntax for null positioning
  - PostgreSQL and Supabase: Full support for `NULLS LAST` and `NULLS FIRST`
  - MySQL/SQLite: Gracefully ignored (not supported by these databases)
  - Backward compatible - simple `{'field': 'desc'}` syntax still works

- **Relation Filter Helpers** - New `FilterOperators` for filtering on relations
  - `FilterOperators.some(where)` - At least one related record matches
  - `FilterOperators.every(where)` - All related records match
  - `FilterOperators.noneMatch(where)` - No related records match
  - `FilterOperators.isEmpty()` - Relation has no records
  - `FilterOperators.isNotEmpty()` - Relation has at least one record
  - *Note: These helpers generate the correct JSON structure. SQL compilation added in v0.2.4.*

### Example Usage
```dart
// NULLS LAST/FIRST ordering
final query = JsonQueryBuilder()
    .model('Product')
    .action(QueryAction.findMany)
    .orderBy({
      'price': {'sort': 'asc', 'nulls': 'last'},  // Extended syntax
      'createdAt': 'desc',  // Simple syntax still works
    })
    .build();

// Relation filter helpers (SQL compilation added in v0.2.4)
final where = {
  'reviews': FilterOperators.some({
    'rating': FilterOperators.gte(4),
    'verified': true,
  }),
  'tags': FilterOperators.isEmpty(),
};
```

## [0.2.2] - 2025-12-19

### Added
- **Case-Insensitive Search** - New `mode: 'insensitive'` option for string filters
  - `FilterOperators.containsInsensitive(value)` - Case-insensitive LIKE search
  - `FilterOperators.startsWithInsensitive(value)` - Case-insensitive prefix search
  - `FilterOperators.endsWithInsensitive(value)` - Case-insensitive suffix search
  - Generates `ILIKE` for PostgreSQL/Supabase (case-insensitive)
  - Falls back to `LIKE` for MySQL/SQLite (they are already case-insensitive by default)
  - Backward compatible - existing `contains()`, `startsWith()`, `endsWith()` unchanged

### Example Usage
```dart
// Case-insensitive search
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({
      'name': FilterOperators.containsInsensitive('john'),  // Matches "John", "JOHN", "john"
    })
    .build();
```

## [0.2.1] - 2025-12-19

### Fixed
- **`createMany` type cast error** - Fixed bug where `_compileCreateManyQuery` failed with `type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>?'`. The SQL compiler now properly unwraps nested `{'data': [...]}` format generated by delegate methods.

## [0.2.0] - 2025-12-19

### Added - Production-Grade Features

#### Exception System
- **`PrismaException`** - Base sealed class for all connector exceptions
- **`UniqueConstraintException`** - Duplicate key violations (code: P2002)
- **`ForeignKeyException`** - Reference constraint violations (code: P2003)
- **`RecordNotFoundException`** - Record not found (code: P2025)
- **`QueryTimeoutException`** - Query execution timeout (code: P5008)
- **`InternalException`** - General database errors (code: P5000)

#### Query Logging
- **`QueryLogger`** - Abstract interface for query logging
- **`ConsoleQueryLogger`** - Simple console output logger
- **`MetricsQueryLogger`** - Tracks query metrics (count, avg/min/max duration)
- Events: `onQueryStart`, `onQueryEnd`, `onQueryError`

#### Raw SQL API
- **`executeRaw(sql, params)`** - Execute raw SELECT queries
- **`executeMutationRaw(sql, params)`** - Execute raw INSERT/UPDATE/DELETE
- Parameterized queries with type inference
- Full logging integration

#### Aggregations
- **`QueryAction.count`** - Count records matching filter
- **`QueryAction.aggregate`** - Planned for future (_avg, _sum, _min, _max)

#### Upsert Operation
- **`QueryAction.upsert`** - Insert or update based on conflict
- PostgreSQL: `ON CONFLICT DO UPDATE ... RETURNING *`
- SQLite: `ON CONFLICT DO UPDATE ... RETURNING *` (requires SQLite 3.35.0+)
- MySQL: `ON DUPLICATE KEY UPDATE` (see Known Limitations)

#### Relations with JOINs
- **`include`** option for eager loading related data
- **`SchemaRegistry`** - Stores relation metadata from Prisma schema
- **`RelationCompiler`** - Generates LEFT JOIN clauses
- Automatic result nesting (flat rows → nested objects)
- Falls back to N+1 queries if relations not configured

### Known Limitations

#### MySQL Upsert
MySQL's `ON DUPLICATE KEY UPDATE` does not support the `RETURNING` clause. Unlike PostgreSQL and SQLite 3.35+, MySQL upsert operations return the affected row count instead of the actual record. If you need the upserted record, perform a follow-up SELECT query:

```dart
// MySQL workaround for upsert
final result = await executor.executeQueryAsSingleMap(upsertQuery);
if (result == null || result.isEmpty) {
  // Fetch the record manually
  final selectQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.findUnique)
      .where({'email': email})
      .build();
  return executor.executeQueryAsSingleMap(selectQuery);
}
return result;
```

### Breaking Changes
- None - fully backward compatible with v0.1.x

## [0.1.8] - 2025-12-18

### Fixed
- **UPDATE/CREATE RETURNING Clause** - PostgreSQL and Supabase queries now include `RETURNING *`
  - UPDATE queries previously returned no data, causing "Failed to update" errors
  - Both CREATE and UPDATE now return the affected row for PostgreSQL/Supabase providers
  - Enables proper response handling in upsert and update operations

- **DateTime Type Inference** - Strict ISO 8601 date detection prevents misidentification
  - Previously, phone numbers like "9876543210" were incorrectly detected as dates
  - Now requires: dash separator, 4-digit year prefix, and reasonable year range (1000-9999)
  - Fixes data corruption where phone numbers were stored as garbage date values

### Verified
- Comprehensive end-to-end testing with complex consultant onboarding:
  - ✅ String fields (name, bio, description, URLs)
  - ✅ Numeric fields (experience: 15.5 as double)
  - ✅ DateTime fields (dateOfBirth)
  - ✅ Enum fields (gender, scheduleType, sessionTypes)
  - ✅ Array fields (languages with 4 items, toolsAndTechnologies with 20 items)
  - ✅ Foreign key relations (Domain)
  - ✅ Many-to-many relations (SubDomains via join table)
  - ✅ Transaction support (atomic operations)

## [0.1.7] - 2025-12-18

### Added
- **Server Mode** - New `--server` flag for code generation
  - Use `--server` when generating for pure Dart servers (Dart Frog, Shelf, etc.)
  - Imports `runtime_server.dart` instead of `runtime.dart` (no Flutter/sqflite dependencies)
  - Example: `dart run prisma_flutter_connector:generate --server --schema=... --output=...`

## [0.1.6] - 2025-12-18

### Fixed
- **SortOrder Enum Duplication** - Moved `SortOrder` enum to shared `filters.dart` instead of generating it in every model file
  - Previously caused "ambiguous export" errors when re-exporting all models from index.dart
  - Now defined once in filters.dart and imported by all model files
- **@Default + required Conflict** - Fields with `@Default` annotation are no longer marked as `required`
  - Fixes "Required named parameters can't have a default value" errors in Freezed-generated code
  - Applies to both main model classes and CreateInput types
- **Transaction Executor Type Mismatch** - Added `BaseExecutor` abstract interface
  - Allows delegates to work with both `QueryExecutor` (normal ops) and `TransactionExecutor` (transactions)
  - Fixes "argument type not assignable" errors when using `$transaction`

## [0.1.5] - 2025-12-18

### Fixed
- **Enum Comment Stripping** - Parser now correctly strips inline comments from enum values
- **Prisma Type Conversion** - Fixed `Int` → `int`, `Float`/`Decimal` → `double`, `Json` → `Map<String, dynamic>`, `Bytes` → `List<int>`
- **Runtime Defaults** - Skip `uuid()`, `now()`, `autoincrement()`, `dbgenerated()` for `@Default` annotation
- **Reserved Keywords** - Enum values like `class` are renamed to `classValue` to avoid Dart conflicts
- **Relation Fields** - Excluded from `Create`/`Update` input types (handled separately)
- **Enum Imports** - Filter types now properly import all enum definitions
- **toSnakeCase Bug** - Use `replaceFirst` instead of `substring(1)` to safely handle edge cases
- **Const Constructor** - Added `const` to `ConnectionSettings` in Supabase adapter

### Changed
- **DRY Refactor** - Extracted `toSnakeCase`, `toCamelCase`, `toLowerCamelCase` to shared `string_utils.dart`
- **Performance** - Use `const Set` instead of `List` for `runtimeFunctions` lookup (O(1) vs O(n))

## [0.1.4] - 2025-12-16

### Fixed
- **PostgreSQL Enum Type Handling** - Fixed `UndecodedBytes` error when querying tables with enum columns
  - PostgreSQL custom types (enums like `UserRole`, `Gender`, etc.) are now properly decoded to strings
  - Added `_convertValue` helper in PostgresAdapter to handle `UndecodedBytes` from the postgres package

---

## [0.1.3] - 2025-12-16

### Added
- **Server Runtime Support** - New `runtime_server.dart` entry point for pure Dart server environments
  - Use `import 'package:prisma_flutter_connector/runtime_server.dart'` in Dart Frog, Shelf, or other server frameworks
  - Exports only PostgreSQL and Supabase adapters (no Flutter/sqflite dependencies)
  - Fixes "dart:ui not available" errors when using the package in server environments

### Why This Matters
The main `runtime.dart` exports the SQLite adapter which depends on `sqflite` (a Flutter plugin).
When imported in pure Dart servers, this caused compilation errors because `sqflite` imports `dart:ui`.

Now you can:
- Use `runtime_server.dart` for Dart servers (Dart Frog, Shelf, etc.)
- Use `runtime.dart` for Flutter apps (includes SQLite for offline-first mobile)

### Usage

```dart
// In Dart Frog backend:
import 'package:prisma_flutter_connector/runtime_server.dart';

// In Flutter app:
import 'package:prisma_flutter_connector/runtime.dart';
```

---

## [0.1.2] - 2025-12-14

### Fixed
- Fixed const constructor compatibility issue in SupabaseAdapter for dependency downgrade testing
- Updated dependency version constraints to allow latest versions (freezed_annotation, web_socket_channel)

### Improved
- Added comprehensive dartdoc comments to public APIs

---

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
