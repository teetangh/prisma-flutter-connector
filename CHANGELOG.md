# Changelog

All notable changes to the Prisma Flutter Connector.

## [Unreleased]

## [0.3.0] - 2025-12-25

### Added

#### Many-to-Many Relation Mutations (Connect/Disconnect)
- **`compileWithRelations()`** - Compile mutations with M2M relation operations
  - Automatically extracts `connect` and `disconnect` from data
  - Generates junction table INSERT/DELETE statements
  - Works with `create` and `update` operations

- **`executeMutationWithRelations()`** - Execute mutations with M2M support
  - Executes main mutation first, then relation mutations
  - Supports non-atomic execution for performance

- **`executeMutationWithRelationsAtomic()`** - Atomic M2M mutations
  - Wraps all operations in a transaction
  - Rolls back if any mutation fails

#### CompiledMutation Type
- New `CompiledMutation` class for structured mutation results
  - `mainQuery` - The primary INSERT/UPDATE query
  - `relationMutations` - List of junction table operations
  - `hasRelationMutations` - Helper to check if M2M operations exist

#### Provider-Specific Connect Syntax
- PostgreSQL/Supabase: `INSERT ... ON CONFLICT DO NOTHING`
- MySQL: `INSERT IGNORE INTO ...`
- SQLite: `INSERT OR IGNORE INTO ...`

### Example Usage

```dart
// Create with M2M connect
final result = await executor.executeMutationWithRelations(
  JsonQueryBuilder()
      .model('SlotOfAppointment')
      .action(QueryAction.create)
      .data({
        'id': 'slot-123',
        'startsAt': DateTime.now(),
        'users': {
          'connect': [{'id': 'user-1'}, {'id': 'user-2'}],
        },
      })
      .build(),
);

// Update with connect/disconnect
final result = await executor.executeMutationWithRelationsAtomic(
  JsonQueryBuilder()
      .model('SlotOfAppointment')
      .action(QueryAction.update)
      .where({'id': 'slot-123'})
      .data({
        'users': {
          'connect': [{'id': 'user-new'}],
          'disconnect': [{'id': 'user-old'}],
        },
      })
      .build(),
);
```

## [0.2.9] - 2025-12-23

### Added

#### DISTINCT Support
- **`distinct()`** - Select unique rows with `SELECT DISTINCT`
  - Standard DISTINCT: `.distinct()` → `SELECT DISTINCT *`
  - PostgreSQL DISTINCT ON: `.distinct(['email'])` → `SELECT DISTINCT ON ("email") *`
  - Works with `selectFields()` for specific column deduplication

#### NULL-Coalescing Filter Operators
New operators for handling NULL values in complex queries (especially with LEFT JOINs):

- **`FilterOperators.isNull()`** - Check if column is NULL
- **`FilterOperators.isNotNull()`** - Check if column is NOT NULL
- **`FilterOperators.notInOrNull(values)`** - `NOT IN (...) OR IS NULL` pattern
- **`FilterOperators.inOrNull(values)`** - `IN (...) OR IS NULL` pattern
- **`FilterOperators.equalsOrNull(value)`** - `= value OR IS NULL` pattern

#### Deep Relation Path Filtering
- **`FilterOperators.relationPath(path, where)`** - Filter through nested relations
  - Generates efficient EXISTS subqueries with chained JOINs
  - Supports arbitrary nesting depth (e.g., `appointment.consultation.consultationPlan`)
  - Works with OR conditions for multiple relation paths

```dart
.where({
  'OR': [
    FilterOperators.relationPath(
      'appointment.consultation.consultationPlan',
      {'consultantProfileId': profileId},
    ),
    FilterOperators.relationPath(
      'appointment.subscription.subscriptionPlan',
      {'consultantProfileId': profileId},
    ),
  ],
})
```

#### Explicit JOIN Type Control
- **`includeRequired()`** - Use INNER JOIN instead of LEFT JOIN for required relations
- **`_joinType: 'inner'`** - Inline JOIN type specification in `include()`

```dart
// Method 1: Separate method
.includeRequired({'appointment': true})  // INNER JOIN
.include({'consultation': true})          // LEFT JOIN (default)

// Method 2: Inline specification
.include({
  'appointment': {'_joinType': 'inner'},
  'consultation': {'_joinType': 'left'},
})
```

### Use Case

These features enable complex multi-table queries that previously required raw SQL:

```dart
// Before v0.2.9: Raw SQL required
final sql = '''
  SELECT DISTINCT soa."startsAt", soa."endsAt"
  FROM "SlotOfAppointment" soa
  INNER JOIN "Appointment" a ON soa."appointmentId" = a.id
  LEFT JOIN "Consultation" c ON a."consultationId" = c.id
  LEFT JOIN "ConsultationPlan" cp ON c."consultationPlanId" = cp.id
  WHERE (cp."consultantProfileId" = $1 OR sp."consultantProfileId" = $1)
    AND (c."requestStatus" NOT IN ('CANCELLED', 'REJECTED') OR c."requestStatus" IS NULL)
''';

// After v0.2.9: Full ORM support
final query = JsonQueryBuilder()
    .model('SlotOfAppointment')
    .action(QueryAction.findMany)
    .distinct()
    .selectFields(['startsAt', 'endsAt', 'isTentative'])
    .includeRequired({'appointment': true})
    .where({
      'OR': [
        FilterOperators.relationPath(
          'appointment.consultation.consultationPlan',
          {'consultantProfileId': profileId},
        ),
        FilterOperators.relationPath(
          'appointment.subscription.subscriptionPlan',
          {'consultantProfileId': profileId},
        ),
      ],
      'startsAt': FilterOperators.gte(startDate.toIso8601String()),
    })
    .build();
```

### Known Limitations
- **`relationPath` does not support many-to-many relations** - Paths containing many-to-many relations will be silently ignored. This is because many-to-many relations require joining through a junction table, which adds significant complexity. Many-to-many support is planned for v0.3.0. For now, use the existing `some`/`every`/`none` operators or raw SQL.

### Notes
- All features are backward compatible - no breaking changes
- DISTINCT ON is PostgreSQL/Supabase specific; other databases use standard DISTINCT
- Relation path filtering requires `SchemaRegistry` to resolve relation metadata

## [0.2.8] - 2025-12-21

### Fixed
- **@@map directive support** - Model names now correctly resolve to database table names when using `JsonQueryBuilder` directly
- `SqlCompiler` now consults `SchemaRegistry` to resolve model-to-table mappings via `@@map` directives

### Added
- `SqlCompiler._resolveTableName()` helper method for transparent model-to-table name resolution
- Comprehensive test suite for `@@map` directive support

### Notes
- Backward compatible: If no `SchemaRegistry` is provided or model is not registered, model names are used as-is
- Generated delegates (from code generation) continue to work as before

## [0.2.7] - 2025-12-20

### Fixed
- **Dependency compatibility** - Upgraded `freezed` to ^3.0.6 to resolve version conflicts with `test` and `flutter_test` packages
- **Lint compliance** - Added `const` constructors where applicable and fixed package imports
- **Code formatting** - Applied consistent dart format across all source files

### Notes
- No functional changes from v0.2.6
- This release ensures CI compatibility with Flutter 3.27.x

## [0.2.6] - 2025-12-19

### Added
- **Computed Fields (Correlated Subqueries)** - Add computed fields via correlated subqueries in SELECT
  - `ComputedField.min()` - MIN aggregate subquery
  - `ComputedField.max()` - MAX aggregate subquery
  - `ComputedField.avg()` - AVG aggregate subquery
  - `ComputedField.sum()` - SUM aggregate subquery
  - `ComputedField.count()` - COUNT aggregate subquery (accepts optional `field` parameter)
  - `ComputedField.first()` - Fetch first matching value with ORDER BY
  - `FieldRef` class for referencing parent table columns in subqueries

### Fixed
- **Alias conflict with include + computed** - Fixed "table name 't0' specified more than once" error
- **Missing relation columns in SELECT** - Relations now correctly included when using `include()` with computed fields
- **Ambiguous column names with JOINs** - Added table alias prefix to WHERE and ORDER BY clauses
- **Aggregate FILTER parameter numbering** - Fixed "could not determine data type of parameter" error
- **Computed field WHERE clause parameterization** - Improved security with parameterized queries
- **selectFields respects dot notation** - Only explicitly requested relation columns are fetched

## [0.2.5] - 2025-12-19

### Added
- **Select Specific Fields** - New `selectFields()` method to select specific columns instead of `SELECT *`
- **FILTER Clause for Aggregations** (PostgreSQL/Supabase) - Conditional COUNT with `_countFiltered`
- **Include with Select** - Select specific fields from included relations

## [0.2.4] - 2025-12-19

### Added
- **Relation Filtering SQL Compilation** - Compile `some`/`every`/`none` operators to EXISTS subqueries
- **Relation Filter Operators** - `some`, `none`, `every`, `isEmpty()`, `isNotEmpty()`

## [0.2.3] - 2025-12-19

### Added
- **NULLS LAST/FIRST Ordering** - Extended `orderBy` syntax for null positioning
- **Relation Filter Helpers** - New `FilterOperators` for filtering on relations

## [0.2.2] - 2025-12-19

### Added
- **Case-Insensitive Search** - `containsInsensitive()`, `startsWithInsensitive()`, `endsWithInsensitive()`

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
