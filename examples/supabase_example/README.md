# Supabase Example - Prisma Flutter Connector

This example demonstrates the Prisma Flutter Connector working with a Supabase PostgreSQL database.

## Files

- `simple_example.dart` - **Working example** using runtime library directly (no code generation)
- `lib/example.dart` - Example using generated Prisma client (requires build_runner)
- `schema.prisma` - Prisma schema pulled from Supabase database
- `.env.example` - Template for database credentials

## Quick Start

### 1. Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your Supabase credentials
# SUPABASE_HOST=your-project.pooler.supabase.com
# SUPABASE_USERNAME=postgres.yourproject
# SUPABASE_PASSWORD=your-password
```

### 2. Run Simple Example (No Code Generation)

```bash
# Install dependencies
dart pub get

# Run the example
dart run simple_example.dart
```

This demonstrates:
- Direct Supabase connection (no backend!)
- Full CRUD operations
- Complex filters and ordering
- Transaction support

### 3. Generate Type-Safe Client (Optional)

**⚠️ Schema Requirement:** Before generating, ensure your schema doesn't use Dart reserved keywords.

#### Reserved Keywords to Avoid

The following cannot be used as model or field names:
```
abstract, as, assert, async, await, break, case, catch, class, const,
continue, covariant, default, deferred, do, dynamic, else, enum, export,
extends, extension, external, factory, false, final, finally, for,
Function, get, hide, if, implements, import, in, interface, is, late,
library, mixin, new, null, on, operator, part, rethrow, return, set,
show, static, super, switch, sync, this, throw, true, try, typedef,
var, void, while, with, yield
```

#### Common Issues in This Schema

The current `schema.prisma` contains reserved keywords:
- **Model name:** `Class` (Dart reserved keyword)
- **Field names:** `class` (Dart reserved keyword)

#### How to Fix Reserved Keywords

**Option 1: Rename in Schema (Recommended)**

```prisma
// Before:
model Class {
  id String @id
}

model Waitlist {
  class Class @relation(...)
  classId String
}

// After:
model Lesson {
  id String @id
}

model Waitlist {
  lesson Lesson @relation(...)
  lessonId String
}
```

**Option 2: Use @map to Keep Original Database Names**

```prisma
// Rename in Dart, keep DB name with @map
model Lesson {
  id String @id

  @@map("Class")  // Table is still named "Class" in database
}

model Waitlist {
  lesson Lesson @relation(fields: [lessonId], references: [id])
  lessonId String @map("classId")  // Column is still "classId" in DB

  @@map("waitlist")
}
```

**Why @map?**
- ✅ No database migration needed
- ✅ Generated Dart code uses valid identifiers
- ✅ Schema matches your actual database structure

**Why Rename?**
- ✅ Cleaner, more consistent
- ✅ Better for new projects
- ✅ Follows Dart naming conventions

#### Generate Client

```bash
# Generate Prisma client
dart run prisma_flutter_connector:generate \
  --schema schema.prisma \
  --output lib/generated

# Generate Freezed models
flutter pub run build_runner build --delete-conflicting-outputs

# Run the generated client example
dart run lib/example.dart
```

## Features Demonstrated

### Simple Example (`simple_example.dart`)
✅ Direct database access (no GraphQL backend)
✅ JsonQueryBuilder for type-safe queries
✅ Full CRUD operations
✅ WHERE clauses with filters
✅ ORDER BY and LIMIT
✅ Count aggregations
✅ Parameterized SQL (injection-safe)

### Generated Client Example (`lib/example.dart`)
✅ Generated PrismaClient with type-safe models
✅ Freezed immutable models
✅ JSON serialization
✅ Transaction support
✅ Relation handling (when properly configured)

## Troubleshooting

### Reserved Keyword Error

```
❌ Generator Error: Reserved Dart keyword "Class" cannot be used as model name

Suggestion: Prisma follows strict naming rules to ensure generated code compiles.

Option 1 (Recommended): Rename the model in your schema
  → model Lesson { ... }
  → model Course { ... }
  → model ClassModel { ... }

Option 2: Use @map to keep the original database table name
  → model Lesson {
      ...
      @@map("Class")  // Maps to "Class" table in database
    }

Learn more: https://pris.ly/d/naming-models
```

**Why is Dart stricter than TypeScript?**

Unlike JavaScript/TypeScript, Dart does **not** allow reserved keywords as identifiers in any context:

```javascript
// ✅ Valid in JavaScript/TypeScript
const obj = { class: "foo" };
console.log(obj.class);
```

```dart
// ❌ Invalid in Dart - compilation error
class MyClass {
  String class;  // Error: 'class' is reserved
}
```

This is why we follow Prisma's strict validation approach - to ensure your generated code compiles.

### Flutter Dependency Error

```
Error: Dart library 'dart:ui' is not available on this platform.
```

**Solution:** Use `simple_example.dart` instead of importing the full `runtime.dart`. See file for import pattern.

### Build Runner Fails

```
Could not generate `toJson` code for `user`
```

**Solution:** This happens when relation fields cause circular dependencies. The upgraded generator now excludes relations from JSON serialization automatically.

## Architecture

```
┌─────────────────────────────────────────┐
│   Flutter/Dart Application              │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │  Generated PrismaClient            │ │
│  │  - Type-safe models (Freezed)      │ │
│  │  - CRUD operations (Delegates)     │ │
│  └────────────────────────────────────┘ │
│              │                           │
│              ▼                           │
│  ┌────────────────────────────────────┐ │
│  │  Runtime Library                   │ │
│  │  - QueryExecutor                   │ │
│  │  - JsonProtocol                    │ │
│  │  - SQL Compiler                    │ │
│  └────────────────────────────────────┘ │
│              │                           │
│              ▼                           │
│  ┌────────────────────────────────────┐ │
│  │  Database Adapter                  │ │
│  │  - SupabaseAdapter                 │ │
│  │  - PostgresAdapter                 │ │
│  │  - SQLiteAdapter                   │ │
│  └────────────────────────────────────┘ │
└──────────────┼───────────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │  Supabase PostgreSQL  │
    │  (Direct Connection)  │
    └──────────────────────┘
```

## Production Considerations

- ✅ Use environment variables for credentials (never commit .env)
- ✅ Ensure schema doesn't use reserved keywords
- ✅ Run `dart analyze` on generated code
- ✅ Test all CRUD operations before production
- ⚠️ Handle connection errors gracefully
- ⚠️ Use connection pooling for high load
- ⚠️ Implement proper error handling

## Next Steps

1. **Fix schema** - Rename reserved keywords
2. **Generate client** - Run code generation
3. **Build models** - Run build_runner  
4. **Test** - Verify all operations work
5. **Deploy** - Use in your Flutter app!

## Learn More

- [Prisma Flutter Connector Documentation](https://github.com/YOUR_REPO)
- [Prisma Schema Reference](https://www.prisma.io/docs/reference/api-reference/prisma-schema-reference)
- [Supabase Documentation](https://supabase.com/docs)
