# Prisma Flutter Connector - Production Readiness Roadmap

## Current Status: v0.1.8 (~60% Production Ready)

The connector handles basic CRUD operations well but is missing critical features for production use.

---

## What's Working (v0.1.8)

### Core CRUD
- `findUnique`, `findFirst`, `findMany`
- `create`, `createMany`
- `update`, `updateMany`
- `delete`, `deleteMany`
- `count`

### Query Features
- WHERE clauses: `equals`, `not`, `in`, `notIn`, `lt`, `lte`, `gt`, `gte`, `contains`, `startsWith`, `endsWith`
- Logical operators: `AND`, `OR`, `NOT`
- ORDER BY, LIMIT, OFFSET
- SELECT field filtering

### Database Support
- PostgreSQL (full)
- Supabase (PostgreSQL-based)
- SQLite (mobile offline)

### Transaction Support
- `executeInTransaction` with ACID guarantees
- Isolation levels: READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE

### Type Conversion
- DateTime, UUID, JSON, Bytes, BigInt
- Enum type handling (fixed UndecodedBytes issue)
- RETURNING clause for UPDATE/CREATE (PostgreSQL/Supabase)

---

## What's Missing for Production

### P0 - Critical

| Feature | Status | Impact |
|---------|--------|--------|
| **Relations/JOINs** | Not implemented | Can't load nested data in single query |
| **Aggregations** | Not implemented | No sum, avg, min, max, groupBy |

### P1 - High Priority

| Feature | Status | Impact |
|---------|--------|--------|
| **Upsert** | Not implemented | INSERT ... ON CONFLICT not supported |
| **Raw SQL API** | Hidden | No escape hatch for complex queries |
| **Query Logging** | Not implemented | Hard to debug in production |
| **Typed Exceptions** | Basic only | Generic errors, hard to handle specifically |

### P2 - Medium Priority

| Feature | Status | Impact |
|---------|--------|--------|
| **Connection Pooling** | Not implemented | May struggle under load |
| **Distinct Queries** | Not implemented | Can't deduplicate results |
| **Case-Insensitive Filters** | Not implemented | Search requires workarounds |

---

## Implementation Plan

### Phase 1: Relations with JOINs

**Goal:** Enable `include()` to load related records in a single query.

**Current Problem:**
```dart
// N+1 queries required today
final domains = await findAll();  // 1 query
for (final domain in domains) {
  final subDomains = await findSubDomainsByDomainId(domainId);  // N queries
}
```

**Target:**
```dart
// Single query with JOINs
final query = JsonQueryBuilder()
    .model('Domain')
    .action(QueryAction.findMany)
    .include({'subDomains': true})
    .build();

// Generates: SELECT d.*, s.* FROM "Domain" d
//            LEFT JOIN "SubDomain" s ON s."domainId" = d.id
```

**Implementation:**

1. **Schema Registry** (`lib/src/runtime/schema/schema_registry.dart`)
   - Store relation metadata from Prisma schema
   - Track foreign keys, join tables, relation types

2. **Relation Compiler** (`lib/src/runtime/query/relation_compiler.dart`)
   - Build LEFT JOIN clauses
   - Handle one-to-one, one-to-many, many-to-many

3. **Result Deserializer** (update `query_executor.dart`)
   - Convert flat JOIN results to nested objects
   - Group child records by parent ID

4. **Code Generator Update** (`bin/generate.dart`)
   - Parse @relation directives
   - Generate schema_registry.dart for each project

**Complexity:** High (1-2 weeks)

---

### Phase 2: Aggregations

**Goal:** Support aggregate functions.

**Target:**
```dart
final stats = await executor.executeQueryAsSingleMap(
  JsonQueryBuilder()
    .model('ConsultantProfile')
    .action(QueryAction.aggregate)
    .aggregation({
      '_count': true,
      '_avg': {'rating': true},
      '_sum': {'totalSessions': true},
      '_min': {'hourlyRate': true},
      '_max': {'hourlyRate': true},
    })
    .build()
);
```

**Implementation:**

1. Add `aggregation()` method to `JsonQueryBuilder`
2. Implement `_compileAggregateQuery()` in SQL compiler
3. Generate: `SELECT COUNT(*), AVG(rating), SUM(totalSessions)... FROM ...`

**Complexity:** Medium (3-4 days)

---

### Phase 3: Upsert

**Goal:** INSERT ... ON CONFLICT support.

**Target:**
```dart
final user = await executor.executeQueryAsSingleMap(
  JsonQueryBuilder()
    .model('User')
    .action(QueryAction.upsert)
    .where({'email': 'user@example.com'})
    .data({
      'create': {'email': '...', 'name': '...'},
      'update': {'name': '...'},
    })
    .build()
);
```

**Implementation:**

1. Implement `_compileUpsertQuery()` in SQL compiler
2. PostgreSQL: `INSERT ... ON CONFLICT DO UPDATE`
3. MySQL: `INSERT ... ON DUPLICATE KEY UPDATE`
4. SQLite: `INSERT OR REPLACE`

**Complexity:** Medium (2-3 days)

---

### Phase 4: Raw SQL API

**Goal:** Escape hatch for unsupported operations.

**Target:**
```dart
final results = await executor.executeRaw(
  'SELECT * FROM users WHERE created_at > NOW() - INTERVAL \$1 DAY',
  [7],
);
```

**Implementation:**

1. Add `executeRaw()` to QueryExecutor
2. Add `executeMutationRaw()` for writes
3. Bypass JSON protocol, use adapter directly

**Complexity:** Simple (1 day)

---

### Phase 5: Query Logging

**Goal:** Debug queries in development and production.

**Target:**
```dart
final executor = QueryExecutor(
  adapter: adapter,
  logger: ConsoleQueryLogger(),
);

// Output: [15ms] SELECT * FROM "User" WHERE id = $1 → 1 row
```

**Implementation:**

1. Create `QueryLogger` interface
2. Add hooks in QueryExecutor: onQueryStart, onQueryEnd, onQueryError
3. Include SQL, parameters, duration, row count

**Complexity:** Medium (2-3 days)

---

### Phase 6: Typed Exceptions

**Goal:** Semantic error handling.

**Target:**
```dart
try {
  await executor.executeQueryAsSingleMap(query);
} on UniqueConstraintException catch (e) {
  print('Duplicate ${e.field}: ${e.value}');
} on ForeignKeyException catch (e) {
  print('Invalid reference');
} on RecordNotFoundException {
  print('Not found');
}
```

**Implementation:**

1. Create exception hierarchy in `lib/src/runtime/errors/`
2. Parse PostgreSQL error codes (23505 = unique, 23503 = FK, etc.)
3. Map to semantic exceptions

**Complexity:** Simple (2 days)

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/src/runtime/schema/schema_registry.dart` | Relation metadata storage |
| `lib/src/runtime/query/relation_compiler.dart` | JOIN clause generation |
| `lib/src/runtime/logging/query_logger.dart` | Query logging interface |
| `lib/src/runtime/errors/prisma_exceptions.dart` | Typed exception hierarchy |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/src/runtime/query/sql_compiler.dart` | Add aggregate, upsert, JOINs |
| `lib/src/runtime/query/query_executor.dart` | Raw SQL, logging, result nesting |
| `lib/src/runtime/query/json_protocol.dart` | Aggregation builder method |
| `bin/generate.dart` | Generate schema registry |

---

## Testing Strategy

### Unit Tests
- SQL compiler output validation
- Relation compiler JOIN generation
- Result deserializer nesting

### Integration Tests (familiarise_mobile)
- DomainRepository with includes
- ConsultantProfile aggregations
- User upsert operations

### Manual Tests
- Error handling scenarios
- Performance with large result sets
- Transaction isolation

---

## Timeline

| Phase | Features | Duration |
|-------|----------|----------|
| Phase 1 | Relations/JOINs | 1-2 weeks |
| Phase 2 | Aggregations | 3-4 days |
| Phase 3 | Upsert | 2-3 days |
| Phase 4 | Raw SQL | 1 day |
| Phase 5 | Query Logging | 2-3 days |
| Phase 6 | Typed Exceptions | 2 days |
| **Total** | | **~3-4 weeks** |

---

## Release Plan

### v0.2.0 (Production Ready)
- [ ] All Phase 1-6 features implemented
- [ ] Full test coverage
- [ ] Updated documentation
- [ ] Performance benchmarks
- [ ] Migration guide from v0.1.x

### Breaking Changes
- None planned - all new features are additive
