# Migration Guide: v0.1.0 → v0.2.0

## Overview

Version 0.2.0 introduces **full compile-time type safety** to the Prisma Flutter Connector. All CRUD operations now use typed inputs instead of `Map<String, dynamic>`, matching the Prisma TypeScript experience.

## What Changed

### Before (v0.1.0) - Map-based API
```dart
// ❌ Old way - no type safety
final domain = await prisma.domain.findUnique(
  where: {'id': 'abc'},  // Map - no compile-time checking
);

final domains = await prisma.domain.findMany(
  where: {'name': {'contains': 'test'}},  // Nested maps
  orderBy: {'createdAt': 'desc'},
);
```

### After (v0.2.0) - Type-safe API
```dart
// ✅ New way - full type safety
final domain = await prisma.domain.findUnique(
  where: DomainWhereUniqueInput(id: 'abc'),  // Typed input
);

final domains = await prisma.domain.findMany(
  where: DomainWhereInput(
    name: StringFilter(contains: 'test'),  // Type-safe filter
  ),
  orderBy: DomainOrderByInput(createdAt: SortOrder.desc),
);
```

## Migration Steps

### Step 1: Regenerate Code

Run the code generator to create type-safe client code:

```bash
# Generate type-safe code
dart run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated

# Run build_runner to generate Freezed code
dart run build_runner build --delete-conflicting-outputs
```

### Step 2: Update Imports

```dart
// Before
import 'package:prisma_flutter_connector/runtime.dart';

// After - import generated types
import 'lib/generated/index.dart';  // Includes all models, filters, client
```

### Step 3: Migrate CRUD Operations

#### FindUnique / FindUniqueOrThrow

```dart
// Before
final user = await prisma.user.findUnique(
  where: {'id': userId},
);

// After
final user = await prisma.user.findUnique(
  where: UserWhereUniqueInput(id: userId),
);
```

#### FindMany

```dart
// Before
final users = await prisma.user.findMany(
  where: {
    'email': {'contains': '@example.com'},
    'age': {'gte': 18},
  },
  orderBy: {'createdAt': 'desc'},
  take: 10,
  skip: 0,
);

// After
final users = await prisma.user.findMany(
  where: UserWhereInput(
    email: StringFilter(contains: '@example.com'),
    age: IntFilter(gte: 18),
  ),
  orderBy: UserOrderByInput(createdAt: SortOrder.desc),
  take: 10,
  skip: 0,
);
```

#### Create

```dart
// Before
final user = await prisma.user.create(
  data: {
    'name': 'John Doe',
    'email': 'john@example.com',
    'age': 25,
  },
);

// After
final user = await prisma.user.create(
  data: CreateUserInput(
    name: 'John Doe',
    email: 'john@example.com',
    age: 25,
  ),
);
```

#### Update

```dart
// Before
final user = await prisma.user.update(
  where: {'id': userId},
  data: {
    'name': 'Jane Doe',
    'age': 26,
  },
);

// After
final user = await prisma.user.update(
  where: UserWhereUniqueInput(id: userId),
  data: UpdateUserInput(
    name: 'Jane Doe',
    age: 26,
  ),
);
```

#### Delete

```dart
// Before
final user = await prisma.user.delete(
  where: {'id': userId},
);

// After
final user = await prisma.user.delete(
  where: UserWhereUniqueInput(id: userId),
);
```

#### Count

```dart
// Before
final count = await prisma.user.count(
  where: {'email': {'contains': '@example.com'}},
);

// After
final count = await prisma.user.count(
  where: UserWhereInput(
    email: StringFilter(contains: '@example.com'),
  ),
);
```

## Filter Migration Guide

### String Filters

```dart
// Before
where: {
  'name': {'equals': 'John'},
  'email': {'contains': '@example.com'},
  'username': {'startsWith': 'user_'},
}

// After
where: UserWhereInput(
  name: StringFilter(equals: 'John'),
  email: StringFilter(contains: '@example.com'),
  username: StringFilter(startsWith: 'user_'),
)
```

### Numeric Filters

```dart
// Before
where: {
  'age': {'gte': 18},
  'score': {'lt': 100},
}

// After
where: UserWhereInput(
  age: IntFilter(gte: 18),
  score: IntFilter(lt: 100),
)
```

### DateTime Filters

```dart
// Before
where: {
  'createdAt': {'gte': '2024-01-01T00:00:00Z'},
  'updatedAt': {'lt': DateTime.now().toIso8601String()},
}

// After
where: UserWhereInput(
  createdAt: DateTimeFilter(gte: DateTime.parse('2024-01-01T00:00:00Z')),
  updatedAt: DateTimeFilter(lt: DateTime.now()),
)
```

### Boolean Filters

```dart
// Before
where: {
  'isActive': {'equals': true},
}

// After
where: UserWhereInput(
  isActive: BooleanFilter(equals: true),
)
```

### Logical Operators

```dart
// Before
where: {
  'AND': [
    {'age': {'gte': 18}},
    {'email': {'contains': '@example.com'}},
  ],
  'OR': [
    {'role': {'equals': 'ADMIN'}},
    {'role': {'equals': 'MODERATOR'}},
  ],
  'NOT': {
    'status': {'equals': 'DELETED'},
  },
}

// After
where: UserWhereInput(
  AND: [
    UserWhereInput(age: IntFilter(gte: 18)),
    UserWhereInput(email: StringFilter(contains: '@example.com')),
  ],
  OR: [
    UserWhereInput(role: RoleFilter(equals: Role.admin)),
    UserWhereInput(role: RoleFilter(equals: Role.moderator)),
  ],
  NOT: UserWhereInput(status: StatusFilter(equals: Status.deleted)),
)
```

## Ordering Migration

```dart
// Before
orderBy: {'createdAt': 'desc'}

// After
orderBy: UserOrderByInput(createdAt: SortOrder.desc)
```

## Benefits of Migration

### ✅ Compile-Time Type Checking

```dart
// ❌ Old way - typos not caught until runtime
where: {'emial': 'test@example.com'}  // Typo! No error until runtime

// ✅ New way - caught at compile time
where: UserWhereInput(emial: ...)  // Compile error: undefined parameter
```

### ✅ IntelliSense Support

Your IDE will now provide autocomplete for:
- All available fields
- All filter operations
- All enum values

### ✅ Refactoring Safety

Renaming a field in your schema will cause compile errors everywhere it's used, making refactoring safe and easy.

### ✅ Type Safety

```dart
// ❌ Old way - wrong types accepted
where: {'age': 'not a number'}  // No compile error!

// ✅ New way - type errors caught
where: UserWhereInput(age: IntFilter(equals: 'not a number'))  // Compile error!
```

## Breaking Changes

### 1. All Where Clauses

- `Map<String, dynamic>` → `ModelWhereInput` or `ModelWhereUniqueInput`

### 2. All Data Inputs

- `Map<String, dynamic>` → `CreateModelInput` or `UpdateModelInput`

### 3. OrderBy

- `Map<String, String>` → `ModelOrderByInput`

### 4. Filters

- Nested maps → Typed filter objects (`StringFilter`, `IntFilter`, etc.)

## Gradual Migration

You can migrate gradually:

1. **Start with new features** - Use type-safe API for new code
2. **Migrate critical paths** - Update important queries first
3. **Bulk update** - Use find-and-replace for simple cases
4. **Test thoroughly** - Leverage compile-time checking

## Common Patterns

### Pattern 1: Simple Lookup

```dart
// Before
final user = await prisma.user.findUnique(where: {'id': id});

// After
final user = await prisma.user.findUnique(
  where: UserWhereUniqueInput(id: id),
);
```

### Pattern 2: Filter + Sort + Paginate

```dart
// Before
final users = await prisma.user.findMany(
  where: {'status': {'equals': 'ACTIVE'}},
  orderBy: {'createdAt': 'desc'},
  take: 20,
  skip: offset,
);

// After
final users = await prisma.user.findMany(
  where: UserWhereInput(
    status: StatusFilter(equals: Status.active),
  ),
  orderBy: UserOrderByInput(createdAt: SortOrder.desc),
  take: 20,
  skip: offset,
);
```

### Pattern 3: Complex Filtering

```dart
// Before
final users = await prisma.user.findMany(
  where: {
    'AND': [
      {'age': {'gte': 18}},
      {'OR': [
        {'role': {'equals': 'ADMIN'}},
        {'permissions': {'has': 'WRITE'}},
      ]},
    ],
  },
);

// After
final users = await prisma.user.findMany(
  where: UserWhereInput(
    AND: [
      UserWhereInput(age: IntFilter(gte: 18)),
      UserWhereInput(
        OR: [
          UserWhereInput(role: RoleFilter(equals: Role.admin)),
          UserWhereInput(permissions: StringListFilter(has: 'WRITE')),
        ],
      ),
    ],
  ),
);
```

## Troubleshooting

### Issue: "Type not found"

**Solution:** Make sure you've run build_runner:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Issue: "Cannot convert Map to Input type"

**Solution:** Update your code to use typed inputs instead of maps.

### Issue: "Part file doesn't exist"

**Solution:** Run build_runner to generate Freezed code for input types.

## Help & Support

- 📖 **Documentation:** See TYPE_SAFETY_ANALYSIS.md for detailed examples
- 💡 **Examples:** Check `examples/supabase_example/type_safe_example.dart`
- 🐛 **Issues:** https://github.com/anthropics/prisma-flutter-connector/issues

## Summary

The migration to type-safe APIs provides:
- ✅ Compile-time error detection
- ✅ Better IDE support
- ✅ Safer refactoring
- ✅ Improved code quality
- ✅ Same API as Prisma TypeScript

**Recommendation:** Migrate incrementally, starting with new code and critical paths.
