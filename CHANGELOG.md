# Changelog

All notable changes to the Prisma Flutter Connector.

## [Unreleased]

## [0.9.0] - 2026-07-24

The **null-semantics** release — closes the gaps found while migrating the
familiarise backend to a fully typed data layer, and completes the raw-helper
deprecation cycle.

### Added
- **`setNull` on typed updates** — `update`/`updateMany` gain
  `setNull: List<{Model}ScalarField>?`; listed fields are injected as explicit
  `NULL` assignments (typed inputs otherwise drop null fields, making
  null-clears inexpressible).
- **`isNull` on every filter class** — `isNull: true` compiles to `IS NULL`,
  `isNull: false` to `IS NOT NULL` (all scalar/enum/BigInt/Bytes/Json/list
  filters).
- **Nested `set` for many-to-many relations** — to-many relation write inputs
  gain `set: List<{Related}WhereUniqueInput>?`; the engine clears the junction
  rows for the parent and connects exactly the given targets (replace
  semantics). `set` on 1:N/1:1 throws `UnsupportedError` (re-parenting is not
  implemented) instead of silently dropping data.

### Changed
- **Null-tolerant array decode** — required `String[]`-style columns now
  hydrate SQL `NULL` as `const []` instead of crashing `fromJson` (dirty data
  tolerated in favour of the column default).

### Removed
- **`findManyRaw` / `findFirstRaw`** — deprecated in 0.8.0, removed as
  scheduled. Use `findManyProjected` / `findFirstProjected` (typed inputs,
  Map rows) or typed `findMany` + `toJson()`.

## [0.8.0] - 2026-07-03

The **typed-projection** release: the last raw-map surfaces (`select`,
`selectFields`, `distinct`, computed fields, map-based include) now have typed
equivalents, completing the surface needed to retire hand-built
`JsonQueryBuilder` usage entirely.

### Added

#### `{Model}ScalarField` enums
- One plain enum per model (a case per scalar field, carrying the Dart field
  name; the compiler resolves `@map` columns via the registry). Near-zero
  codegen cost — no freezed/part files.

#### Typed per-relation include `select`
- `XInclude` gains `select: List<{Model}ScalarField>?`, applied when the
  include is nested under a parent include:
  `AuthorInclude(posts: PostInclude(select: [PostScalarField.title]))`.
  `toJson` emits `true` | `{'include': ..., 'select': ...}` — the shape the
  relation compiler already consumes. `select` on the root include object is
  ignored (root projection goes through the projected finders).

#### `findManyProjected` / `findFirstProjected`
- Fully-typed projection finders on every delegate: `XWhereInput`,
  `orderBy` (Map | List | `XOrderByInput`), `take`/`skip`/`cursor`,
  `XInclude` (with per-relation select), `select: List<XScalarField>`,
  `computed: Map<String, ComputedField>`, `distinct`/`distinctOn:
  List<XScalarField>` — with `Map<String, dynamic>` rows out (projected or
  computed rows never hydrate typed models). This single surface replaces
  every `.select()`/`.selectFields()`/computed/raw-helper call site.

### Deprecated
- **`findManyRaw` / `findFirstRaw`** — use the projected finders; removal
  planned for 0.9.0.

### Fixed
- **Include-with-select dropped relation rows when the child primary key was
  not selected** — the relation deserializer groups child rows by PK, so a
  narrow `select` silently emptied the relation. PK columns are now always
  carried in the aliased selection.

### Notes
- Nested typed relation filters (`XRelationFilter(is_:)` chains) compile to
  correctly-correlated nested `EXISTS` — semantically equivalent to (and
  better-correlated than) the legacy `FilterOperators.relationPath`, which is
  now redundant. Limitation: repeating the SAME relation name along one chain
  would collide on the `sub_<relation>` alias (not expressible with distinct
  relation names).

## [0.7.1] - 2026-07-03

### Fixed
- **Removed the hardcoded Sentry DSN** that 0.7.0 shipped as a default in
  `PrismaSentry.defaultDsn`. A published library must not embed the
  maintainer's DSN — it would route other consumers' errors into that project
  and is a minor abuse vector. (A DSN is write-only ingestion, not a secret, so
  this is a hygiene fix, not a credential leak.)
- **Removed `PrismaSentry` entirely.** The connector no longer owns Sentry
  configuration or calls `Sentry.init`. Bundled Sentry support is now solely
  `SentryQueryLogger`, which captures failed queries to whatever Sentry the
  **host application** has already initialized (`Sentry.isEnabled`) — no DSN in
  the library. Host apps init Sentry themselves (e.g. via
  `--dart-define=SENTRY_DSN=...`) and add the logger to the executor.

## [0.7.0] - 2026-07-02

The **complete-ORM** release: the typed `PrismaClient` surface now covers
transactions, upsert, aggregate, nested writes, typed include-hydration,
cursor pagination, JSON/scalar-list/BigInt/Bytes filters, connection pooling,
and composite-key addressing — retiring the need for hand-built
`JsonQueryBuilder`/raw queries in application code.

### Added

#### Transactions (#68)
- **`$transaction((tx) async { ... })`** runs through a polymorphic
  `runTransaction` on the executor. Nested `$transaction` calls flatten onto
  the ambient transaction instead of crashing (`_executor as QueryExecutor`
  no longer throws inside a tx). `$disconnect()` now routes through
  `dispose()`.

#### Upsert (#66)
- **`upsert({where, create, update})`** delegate over the existing
  `INSERT ... ON CONFLICT` compiler. `WhereUniqueInput` → conflict columns
  (with `@map` resolution); `@default(uuid/cuid/now)` and `@updatedAt` are
  autofilled on the create arm and `@updatedAt` refreshed on the update arm.
  Guarded on models with a unique key (including composite).

#### Aggregate (#65)
- **`aggregate()`** delegate (`_count`/`_avg`/`_sum`/`_min`/`_max`, `HAVING`)
  with `@map`-resolved aggregate arguments, plus the previously-missing
  **`findFirstOrThrow`** delegate.

#### Composite unique / `@@id` / `@@unique` addressing (#C6)
- Generated **compound `WhereUniqueInput`** classes let
  `findUnique`/`update`/`delete`/`upsert` target composite keys. The compound
  `toJson` flattens into individual field equalities, so the compiler needs no
  compound-key awareness and upsert gets the correct multi-column
  `ON CONFLICT`.

#### Typed include + relation hydration (#67)
- **`fromJson` hydrates nested relations** into typed models (to-one →
  `Related?`, to-many → `List<Related>`), and generated **`XInclude`** classes
  give `findMany/findFirst/findUnique/findFirstOrThrow` a typed `include:`
  argument — retiring `findManyRaw`/`findFirstRaw` for typed results.

#### Full nested writes (#64)
- Create/Update inputs carry an optional **`<Model><Relation>WriteInput`** per
  relation (`connect`/`disconnect`/`create`). Delegate `create`/`update`
  detect relation ops and route to an atomic relations engine; relation
  mutations resolve the parent PK from the main mutation's `RETURNING` row
  (fixes DB-generated-uuid parents). To-one `connect` inlines the FK; to-many
  `create` emits child INSERTs. A belongsTo `create` throws `UnsupportedError`
  (parent-first ordering unsupported — create the parent + `connect`).

#### Filters (#69)
- **Cursor pagination**: `JsonQueryBuilder.cursor()` + typed delegate `cursor:`
  param derive a canonical keyset predicate from the cursor value and
  `orderBy` (inclusive of the cursor row; pair with `skip:1`).
- **Scalar-list (array) filters**: `has`/`hasSome`/`hasEvery`/`isEmpty`
  (`= ANY`/`&&`/`@>`/`cardinality`).
- **JSON(B) filters** (PostgreSQL/Supabase): `path` addressing via `#>`/`#>>`
  with `equals`(`::jsonb`), `string_contains`/`_starts_with`/`_ends_with`
  (`LIKE`), `array_contains` (`@>`), numeric `lt`/`lte`/`gt`/`gte`.
- **`BigIntFilter` + `BytesFilter`**; BigInt/Bytes columns map to them.

#### Sentry error reporting (bundled)
- **`SentryQueryLogger`** (a `QueryLogger`) forwards failed queries to Sentry
  via `captureException` with SQL/operation/model context — a no-op unless the
  host app has already initialized Sentry (`Sentry.isEnabled`), so it's always
  safe to include. Plug it into the executor's `logger` (compose with
  `ConsoleQueryLogger` via `CompositeQueryLogger`).
- **`PrismaSentry.init(...)`** convenience for standalone/tooling use that owns
  Sentry itself (DSN via arg or the `SENTRY_DSN` dart-define). Apps that already
  call `Sentry.init`/`SentryFlutter.init` should skip this and just add the
  logger. New dependency: `sentry: ">=8.0.0 <10.0.0"` (wide range so sentry
  8.x and 9.x consumers both resolve).

#### Connection pooling (#70)
- **`PostgresAdapter.pooled(pg.Pool)`** runs non-transactional statements on
  connections borrowed from the pool; each transaction pins a dedicated pool
  connection for its lifetime (via `withConnection` + a release completer) so
  all statements share one physical connection. `dispose()` closes the pool.

#### Other ORM gaps
- **Atomic numeric updates**: `{increment/decrement/multiply/divide/set: n}`
  compile to `col = col ± ?` (applies to `update` and `updateMany`).
- **`createManyAndReturn`** (`INSERT ... RETURNING *`, typed rows) and
  **`skipDuplicates`** (`ON CONFLICT DO NOTHING`) on `createMany`.
- **Nested-include depth guard**: recursion capped at `maxIncludeDepth` (5),
  throwing on pathological/cyclic include graphs.

### Fixed
- **`@map` resolution in write paths** (#C3): upsert conflict columns, groupBy
  `by`/aggregate fields, and many-to-many connect/disconnect + `EXISTS`
  subqueries now resolve Dart field names to DB columns via the registry.
- **To-one relation filters** (#C2): `is`/`isNot` in `where` now compile
  (EXISTS / NOT EXISTS with null-target semantics) instead of throwing;
  `is`/`isNot` on a to-many relation is rejected.

### Notes
- Batch `$transaction([...])` (array form) is intentionally **not** provided:
  delegate methods execute eagerly (no lazy promises), so the callback form
  `$transaction((tx) async { ... })` is the supported API.
- Soft-delete stays a documented `deletedAt: null` filter pattern; full
  `$extends` middleware remains out of scope.

## [0.6.0] - 2026-06-12

### Added

#### Parser: `@map` / `@@map` support
- **Model-level `@@map("table_name")`** is now parsed into `PrismaModel.dbName`, so generated delegates and the schema registry target the mapped database table (e.g., `model User { ... @@map("users") }` → `FROM "users"`). Explicit `@@map` takes precedence over reserved-keyword renames.
- **Field-level `@map("column_name")`** is now parsed into `PrismaField.dbName`, flowing into generated `@JsonKey` annotations, JSON serialization keys, and schema-registry column names (e.g., `status AppointmentStatus @map("requestStatus")`). Priority: explicit `@map` > reserved-keyword rename > PascalCase normalization.

#### SqlCompiler: field → column translation for `@map`-ed fields
- **WHERE keys, INSERT columns, UPDATE SET keys, and ORDER BY keys now resolve Dart field names to database column names** via the schema registry (`where: {'status': ...}` compiles to `"requestStatus" = $1` when the field carries `@map("requestStatus")`). This makes typed-delegate CRUD correct on mapped columns end-to-end — generated Create/Update/Where inputs emit Dart field names, which the compiler now maps.
- **Pass-through fallback preserved**: keys that are not registered field names (legacy JsonQueryBuilder callers using literal column names) compile unchanged, including inside `AND`/`OR`/`NOT` recursion.

#### SqlCompiler: `@updatedAt` auto-fill
- **`create`/`createMany` now fill `@updatedAt` columns** (NOW() on PostgreSQL/Supabase, ISO-8601 parameter elsewhere) — previously every typed-delegate create on a table with `updatedAt DateTime @updatedAt` failed with a NOT NULL violation.
- **`update`/`updateMany` refresh `@updatedAt`** unless the caller supplied a value (Prisma semantics). New `FieldInfo.isUpdatedAt` flag, emitted by the registry generator.

#### PostgresAdapter: enum[] / custom array decoding
- **Custom enum array columns (e.g. `SessionType[]`) now decode to `List<String?>`** instead of raw PostgreSQL wire-format bytes. Handles both the binary ARRAY wire format and text array literals (`{A,B,"c d",NULL}`), with NULL elements preserved.

#### Registry generator: one-to-one FK on the target model
- **Relations whose foreign key lives on the TARGET model** (e.g. `Program.licensedSeatConfig` where `LicensedSeatConfig.programId` owns the `@relation`) are now emitted as `isOwner: false` with the target's real FK, instead of fabricating a nonexistent `<fieldName>Id` column on the parent — fixes `column tN.id does not exist` on nested includes.

### Fixed

#### Parser: enum block attributes treated as values
- **`@@map("...")` inside an enum body is no longer emitted as an enum value** (previously generated invalid Dart identifiers and broke compilation for schemas using mapped enums, e.g. BetterAuth/Prisma 7 schemas).
- **Value-level attributes on enum values are stripped** — `ACTIVE @map("active")` now parses as `ACTIVE`.

#### Delegate generator: models without unique scalar fields
- **Models whose only identifier is a composite `@@id([a, b])`** (no field-level `@id`/`@unique`) no longer generate delegates referencing a nonexistent `WhereUniqueInput` class. `findUnique`, `findUniqueOrThrow`, `update`, and `delete` are omitted for such models; `findFirst`, `findMany`, `updateMany`, `deleteMany`, `create`, and `count` remain available.

## [0.5.5] - 2026-04-04

### Fixed

#### Parser: Brace-counting for model body extraction
- **Fixed inline comments with `{` or `}` truncating model parsing** — e.g., `preferences Json? // e.g., { preferredDates: [] }` caused everything after the `}` in the comment to be lost (userId, webinarId, classId fields dropped from Waitlist model)
- Replaced `[^}]+` regex with brace-counting `_extractBlocks()` method for both model and enum parsing

#### Parser: Implicit relation detection
- **Fixed fields referencing other models not being marked as relations** when they lack an explicit `@relation` attribute (e.g., `subDomains SubDomain[]` on Domain)
- Parser now checks if `fieldType` is a known model name in addition to checking for `@relation`

#### Schema Registry: Correct FK for multi-relation models
- **Fixed wrong foreign key when a model has multiple relations to the same target** (e.g., ModerationReport has both `reportedBy` and `targetUser` pointing to User)
- Now uses the field's own `@relation(fields: [...])` first instead of picking the first matching relation on the model

## [0.5.4] - 2026-03-28

### Fixed

#### Eliminate .g.dart dependency — manual fromJson + toJson (#52)
- **Root cause**: json_serializable silently skips generated model files containing `StringFilter?`, `IntFilter?` types, producing zero `.g.dart` output. This breaks dart_frog builds with "toJson not defined" errors.
- **Removed** `part '*.g.dart'` directives from all generated model and filter files
- **Added manual `fromJson`** to main model class — handles all field types (String, int, double, bool, DateTime, BigInt, enums, lists, Map) with proper casting and DateTime ISO8601 parsing
- **Added manual `toJson`** to every generated class:
  - **Model**: serializes all fields (DateTime → ISO8601, Enum → `.toJson()`, BigInt → string)
  - **CreateInput / UpdateInput**: conditional entries skipping nulls
  - **WhereUniqueInput**: conditional map of unique/id fields
  - **WhereInput**: calls `.toJson()` on nested filters, relation filters, and logical operators (AND/OR/NOT)
  - **ListRelationFilter / RelationFilter**: calls `.toJson()` on nested WhereInput objects
  - **OrderByInput**: converts SortOrder enum via `.name`
  - **All filter types** (StringFilter, IntFilter, DateTimeFilter, etc.): conditional map with `in_` → `'in'` key mapping, DateTime → ISO8601, enum → `.toJson()`
- **Added `const Model._()` private constructor** to all Freezed classes (required for custom methods)
- **Added `toJson()` method to generated enums** — returns original Prisma value (e.g., `Role.admin.toJson()` → `'ADMIN'`)
- `@freezed` kept for immutability/copyWith/equality — only JSON serialization is now manual

## [0.5.3] - 2026-03-28

### Fixed
- Remove redundant `as` casts after `is` type checks in findMany/findManyRaw orderBy handling
- Add missing `List` orderBy support in `findFirstRaw` (consistent with findManyRaw)

## [0.5.2] - 2026-03-28

### Added

#### include, distinct, selectFields on Delegates
- **`findUnique`, `findFirst` now accept `include: Map<String, dynamic>?`** for eager-loading relations
- **`findMany` now accepts `include`, `includeRequired`, `selectFields`, `distinct`, `distinctFields`** for full query control
- **`orderBy` on `findMany` accepts `dynamic`** — supports `Map<String, dynamic>`, `List<Map>`, or typed `OrderByInput`
- **New `findManyRaw()`** — returns `List<Map<String, dynamic>>` instead of typed models, supports `include`, `selectFields`, `computed`, `distinct`, `includeRequired`
- **New `findFirstRaw()`** — returns `Map<String, dynamic>?`, supports `include`

These methods unlock migration of ~160 more JsonQueryBuilder usages that previously couldn't use typed delegates because they needed relation includes, field selection, or computed fields.

## [0.5.1] - 2026-03-28

### Changed

#### Zero StringBuffer — Full code_builder Migration
- **Rewrote `cb_model_generator` and `cb_filter_types_generator`** to use code_builder Class/Constructor/Parameter/Enum builders
- All 5 generators now have **0 `buf.write` calls** (was 167 in v0.5.0, 917 in v0.4.0)
- Freezed classes generated via code_builder AST: `@freezed`, `with _$Model`, `const factory ... = _Model`, `fromJson`
- Field annotations (`@Default`, `@JsonKey`, `@JsonSerializable`) built as `CodeExpression` nodes

#### Freezed Dependency
- Constrained `freezed` dev dependency to `>=3.0.6 <3.2.0` (3.2.x requires Dart SDK >=3.7.0)

## [0.5.0] - 2026-03-28

### Changed

#### Code Generation Architecture (#35)
- **Migrated ALL 5 generators to `code_builder` + `dart_style`**
  - `CbDelegateGenerator` — fully code_builder (Class/Method/Field AST builders, 0 buffer.write calls)
  - `CbClientGenerator` — fully code_builder (Class/Constructor/Method builders)
  - `CbSchemaRegistryGenerator` — code_builder Library + Code blocks
  - `CbModelGenerator` — dart_style auto-format, hybrid StringBuffer for Freezed-specific syntax
  - `CbFilterTypesGenerator` — dart_style auto-format, hybrid StringBuffer for Freezed syntax
- All generated output is auto-formatted by `DartFormatter`
- Old StringBuffer generators preserved but unused by CLI
- Added `code_builder: ^4.9.0` and `dart_style: ^3.0.1` dependencies

### Fixed

#### JSON Deserialization for String-Based Drivers (#19)
- **JSON columns from MySQL/SQLite are now properly parsed** — `deserializeValue()` attempts `jsonDecode()` on string values for `ColumnType.json` columns
- PostgreSQL behavior unchanged (already returns parsed objects)

### Notes
- Version bump to 0.5.0 signals the architectural shift in code generation
- Freezed 3.x compatibility (#23) — constraint already set to `>=2.4.1 <4.0.0`

## [0.4.0] - 2026-03-28

### Added

#### Auto-Generate SchemaRegistry (Issue #29)
- **New `schema_registry_generator.dart`** - Automatically generates `schema_registry.g.dart` with all models, fields, relations, and M2M junction table metadata from the Prisma schema
- Replaces manual 2500+ line schema registry files with a single `registerAllModels(schemaRegistry)` call
- Exported via the barrel `index.dart` file

#### Nested Writes for 1:N and 1:1 Relations (Issue #30)
- **`compileWithRelations()` now supports `{create: [...]}` for one-to-many relations**
- Child records are created with the parent's FK automatically injected
- UUID/timestamp defaults are auto-generated for child records
- `{connect: {id: ...}}` for one-to-one relations sets FK on parent row

#### groupBy Method in Generated Delegates (Issue #33)
- **Generated model delegates now include `groupBy()` method**
- Accepts `by`, `where`, `count`, `sum`, `avg`, `min`, `max`, `orderBy` parameters
- Delegates to the existing `QueryAction.groupBy` SQL compilation

#### Multi-Column orderBy (Issue #26)
- **`orderBy()` now accepts `List<Map>` for multi-column sorting**
- Single `Map` usage unchanged (backward compatible)
- Example: `.orderBy([{'lastName': 'asc'}, {'firstName': 'asc'}])`

#### Connection Pooler Timeout Recovery (Issue #27)
- **PostgresAdapter now supports automatic reconnection** after pooler/connection timeouts
- Pass a `connectionFactory` callback to enable health checking and auto-reconnect
- Health check runs `SELECT 1` with 5-second timeout before each query
- No-op when `connectionFactory` is not provided (backward compatible)

### Fixed

#### @default(uuid/cuid/now) Auto-Generation (Issue #24)
- **CREATE queries now auto-generate `gen_random_uuid()` and `NOW()` for PostgreSQL/Supabase** when fields have `@default(uuid())`, `@default(cuid())`, or `@default(now())` in the Prisma schema
- Only injects defaults when the field is not explicitly provided in data
- Uses database-native functions (no Dart-side UUID dependency)

#### StringFilter/WhereInput Serialization (Issue #25)
- **Added `@JsonSerializable(explicitToJson: true)` to generated WhereInput classes** so nested filter objects (StringFilter, IntFilter, etc.) are properly serialized to JSON
- Added fallback in delegate `_whereToJson` that tries `.toJson()` on filter objects that aren't already Maps

#### M2M Relations in relationPath Deep Filters (Issue #32)
- **`FilterOperators.relationPath()` now supports many-to-many relations** via junction table JOINs
- Previously returned empty results silently for M2M; now generates proper EXISTS subqueries through junction tables
- Works in both first and subsequent positions in the relation path

#### Nested Include Deserialization in Transactions (Issue #31)
- **Verified**: v0.3.4 + v0.3.8 fixes already resolve this for all code paths
- Both `QueryExecutor` and `TransactionExecutor` use identical `RelationDeserializer` logic
- Stale workarounds in consumer code can be safely removed

### Tests
- Added 10 comprehensive unit tests for all v0.4.0 features
- All 74+ existing tests pass with zero regressions

## [0.3.8] - 2026-01-10

### Fixed

#### Nested Include Deserialization Bug
- **Fixed nested includes returning data under incorrect object keys**
  - When using nested includes like `{'consultantProfile': {'include': {'user': true}}}`, the nested relation data was stored under the full path key (e.g., `'consultantProfile.user'`) instead of the immediate field name (`'user'`)
  - Root cause: `IncludedRelation.name` stored the full dot-separated path, which was then used as the object key during deserialization
  - Fix: Added `fieldName` field to `IncludedRelation` to store the immediate relation name separately from the full path (used for column prefix matching)

#### Impact
- Nested includes now correctly produce nested object structures
- Application code can access nested relations using expected field names

#### Example

```dart
// Query with nested include:
final query = JsonQueryBuilder()
    .model('ConsultationPlan')
    .action(QueryAction.findUnique)
    .where({'id': 'plan-123'})
    .include({
      'consultantProfile': {
        'include': {'user': true}
      }
    })
    .build();

// Before fix (broken):
{
  'id': 'plan-123',
  'consultantProfile': {'id': 'cp-1', 'headline': '...'},
  'consultantProfile.user': {'id': 'u-1', 'name': 'John'}  // WRONG: flat key
}

// After fix (correct):
{
  'id': 'plan-123',
  'consultantProfile': {
    'id': 'cp-1',
    'headline': '...',
    'user': {'id': 'u-1', 'name': 'John'}  // CORRECT: properly nested
  }
}
```

### Changed
- Added `fieldName` field to `IncludedRelation` class
- Updated `_compileRelation()` to set `fieldName` for both top-level and nested relations
- Updated `RelationDeserializer._extractRelation()` to use `fieldName` for object keys

### Tests
- Added comprehensive deserialization test for nested includes

## [0.3.7] - 2026-01-10

### Fixed

#### Nested Relation Filter Bug
- **Fixed "missing FROM-clause entry for table" error when using nested relation filters**
  - When filtering through nested relations like `slots.some({ user.some({ id: '...' }) })`, the generated SQL referenced undefined table aliases
  - Root cause: EXISTS subqueries passed `parentAlias: 'sub_$relationName'` to nested `_buildWhereClause` calls, but the FROM clause never defined this alias
  - Fix: Added `targetAlias` parameter to all EXISTS clause builders (`_buildOneToManyExistsClause`, `_buildManyToOneExistsClause`, `_buildManyToManyExistsClause`) and added `AS $targetAlias` to the FROM/JOIN clauses

#### Example

```dart
// This now works correctly:
final query = JsonQueryBuilder()
    .model('Appointment')
    .action(QueryAction.findMany)
    .where({
      'slots': FilterOperators.some({
        'user': FilterOperators.some({
          'id': userId,
        }),
      }),
    })
    .build();

// Generated SQL now properly defines aliases:
// EXISTS (SELECT 1 FROM "SlotOfAppointment" AS sub_slots
//   WHERE sub_slots."appointmentId" = "Appointment"."id"
//   AND EXISTS (SELECT 1 FROM "_SlotOfAppointmentToUser"
//     INNER JOIN "users" AS sub_user ON sub_user."id" = "_SlotOfAppointmentToUser"."B"
//     WHERE "_SlotOfAppointmentToUser"."A" = sub_slots."id"
//     AND sub_user."id" = $1))
```

### Tests
- Added comprehensive test for nested relation filters

## [0.3.6] - 2026-01-07

### Changed

#### Runtime Refactoring
- **Extracted shared `ResultSetConverter` mixin** for `QueryExecutor` and `TransactionExecutor`
  - `resultSetToMaps()` - Convert database results to maps
  - `deserializeValue()` - Convert database values to Dart types
  - `snakeToCamelCase()` - Column name conversion
- **Cached regex patterns** for improved performance in `string_utils.dart` and `sql_compiler.dart`
- Reduced code duplication by ~71 lines with no functional changes

## [0.3.5] - 2026-01-07

### Added

#### Relation Filter Support in WhereInput Classes
- **Added support for filtering on relation fields in generated WhereInput classes**
  - Previously, all relation fields were skipped during generation, preventing queries like `FilterOperators.some()` from working on M2M relations
  - Now generates `ListRelationFilter` (some/every/none) for list relations and `RelationFilter` (is/isNot) for single relations

- **New generated filter types:**
  - `{Model}ListRelationFilter` - For filtering on list/many relations with `some`, `every`, `none` operators
  - `{Model}RelationFilter` - For filtering on single/one relations with `is`, `isNot` operators

#### Example Usage

```dart
// Filter appointments where at least one user has a specific email
final query = JsonQueryBuilder()
    .model('SlotOfAppointment')
    .action(QueryAction.findMany)
    .where({
      'user': {
        'some': {
          'email': {'contains': '@example.com'}
        }
      }
    })
    .build();
```

### Tests
- Added 13 comprehensive unit tests for relation filter generation
- All existing unit tests pass (no regressions)

## [0.3.4] - 2025-12-30

### Fixed

#### TransactionExecutor Relation Deserialization Bug
- **Fixed `include()` not deserializing nested relations when executed within transactions**
  - When using `executeInTransaction()` or `executeQueryAsMaps()` on a `TransactionExecutor`, queries with `include()` were returning flat maps with aliased column names (e.g., `consultationPlanTitle`) instead of properly nested objects (e.g., `{'consultationPlan': {'title': ...}}`)
  - This happened because `TransactionExecutor` was missing the `RelationDeserializer` logic that exists in `QueryExecutor`
  - Now `TransactionExecutor` properly deserializes relations using the same logic as `QueryExecutor`

- **Added proper value deserialization in `TransactionExecutor`**
  - DateTime, Date, Boolean, and JSON values are now properly deserialized within transactions
  - Previously, these values were returned as raw database values

#### Example

```dart
// This now works correctly within transactions:
await executor.executeInTransaction((txn) async {
  final result = await txn.executeQueryAsMaps(
    JsonQueryBuilder()
        .model('Consultation')
        .action(QueryAction.findUnique)
        .where({'id': consultationId})
        .include({
          'consultationPlan': {
            'include': {'consultantProfile': true}
          }
        })
        .build(),
  );

  // ✅ Now returns nested objects:
  // {
  //   'id': '...',
  //   'consultationPlan': {
  //     'title': 'Premium Consultation',
  //     'consultantProfile': { ... }
  //   }
  // }

  // ❌ Previously returned flat keys:
  // {
  //   'id': '...',
  //   'consultationPlanTitle': 'Premium Consultation',
  //   'consultationPlanConsultantProfileId': '...'
  // }
});
```

## [0.3.3] - 2025-12-29

### Added

#### Strict Model Name Validation (Opt-in)
- **New opt-in validation for model names** helps catch common mistakes when using PascalCase Prisma model names instead of lowercase PostgreSQL table names
  - Enable globally: `SqlCompiler.strictModelValidation = true`
  - Enable per-instance: `SqlCompiler(provider: 'postgresql', strictModelValidation: true)`
  - Disabled by default for backwards compatibility

- **Helpful error messages** when validation is enabled:
  - Detects PascalCase model names (e.g., `'User'`) and suggests the likely table name (e.g., `'user'`)
  - When SchemaRegistry is empty, reminds users to either use table names directly or run code generation
  - When SchemaRegistry has models, lists available models to help identify typos

### Example

```dart
// Enable strict validation globally
SqlCompiler.strictModelValidation = true;

// This now throws a helpful error:
final query = JsonQueryBuilder()
    .model('User')  // ❌ PascalCase - suggests using 'user' instead
    .action(QueryAction.findMany)
    .build();

// Error message:
// Model "User" not found in SchemaRegistry (registry is empty).
//
// When using JsonQueryBuilder without Prisma code generation, you must use
// the actual PostgreSQL table name instead of the Prisma model name.
//
// Try: .model('user') instead of .model('User')
//
// Alternatively, run "dart run prisma_flutter_connector:generate" to
// populate the SchemaRegistry with model-to-table mappings.
```

## [0.3.2] - 2025-12-29

### Fixed

#### Nested Include JOINs Bug
- **Fixed nested `include()` generating invalid SQL** - "missing FROM-clause entry for table" error
  - When using nested includes like `.include({'relation': {'include': {'nestedRelation': true}}})`
  - The nested JOIN clauses were not being added to the SQL output
  - This caused errors like `missing FROM-clause entry for table "t2"` because columns from the nested relation were selected but the table was never joined
  - Fixed `RelationCompiler._compileRelation()` to collect and combine nested JOIN clauses with the parent JOIN

#### Example

```dart
// This now works correctly:
final query = JsonQueryBuilder()
    .model('ConsultationPlan')
    .action(QueryAction.findUnique)
    .where({'id': planId})
    .include({
      'consultantProfile': {
        'include': {'user': true}  // ✅ Nested include now generates correct JOINs
      }
    })
    .build();
```

#### Deeply Nested Relation Filters Validation (Issue #13)
- **Added validation for invalid relation filter patterns**
  - Relation fields used without `some()`, `every()`, or `none()` operators now throw clear errors
  - Unknown filter operators on scalar fields are now detected with helpful error messages
  - Previously, these patterns would silently generate invalid SQL

- **Error messages now guide users to the correct syntax**
  - Suggests using `FilterOperators.some()`, `every()`, or `none()` for relation fields
  - Lists valid scalar operators when an unknown operator is detected
  - Mentions `FilterOperators.relationPath()` for complex OR conditions across relations

### Example

```dart
// This invalid pattern now throws a helpful error:
.where({
  'posts': {  // ❌ Relation field without operator
    'title': {'equals': 'Test'},
  },
})
// Error: Relation field "posts" on model "User" requires a filter operator.
// Use FilterOperators.some(), every(), or none().

// Correct usage:
.where({
  'posts': FilterOperators.some({  // ✅ Using some() operator
    'title': {'equals': 'Test'},
  }),
})
```

## [0.3.1] - 2025-12-28

### Fixed

#### Computed Fields with Relations Bug
- **Fixed computed fields returning `null` when used with `include()`**
  - Computed fields (e.g., `ComputedField.min()`, `ComputedField.max()`) now correctly return values when combined with relation includes
  - Previously, computed fields were dropped during relation deserialization because they weren't tracked in `columnAliases`
  - Added `computedFieldNames` to `SqlQuery` to track computed field names
  - After relation deserialization, computed fields are now copied back from the flat result maps

### Example

```dart
// This now works correctly:
final consultants = await prisma.consultant.findMany(
  include: {
    'user': {'select': {'name': true, 'image': true}},
    'domain': true,
  },
  computed: {
    'minPrice': ComputedField.min('price', from: 'ConsultationPlan',
      where: {'consultantProfileId': FieldRef('id')}),
  },
);
// consultants[0]['minPrice'] now returns the correct value instead of null
```

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
