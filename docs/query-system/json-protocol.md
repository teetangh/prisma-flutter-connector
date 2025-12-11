# JSON Protocol

Prisma's query protocol used internally to represent queries.

## Location

`lib/src/runtime/query/json_protocol.dart`

## Overview

The JSON protocol is an intermediate representation of queries, inspired by Prisma's internal protocol. It provides a consistent format that can be compiled to different SQL dialects.

## Query Structure

```dart
class JsonQuery {
  final String modelName;    // "User"
  final String action;       // "findMany", "create", etc.
  final JsonQueryArgs args;  // Query arguments
}

class JsonQueryArgs {
  final Map<String, dynamic>? arguments;  // where, orderBy, etc.
  final Map<String, dynamic>? selection;  // Field selection
}
```

## Query Builder

Use `JsonQueryBuilder` to construct queries fluently:

```dart
final query = JsonQueryBuilder()
    .model('User')
    .action(QueryAction.findMany)
    .where({
      'email': {'contains': '@example.com'},
    })
    .orderBy({'createdAt': 'desc'})
    .take(10)
    .skip(0)
    .build();
```

## Query Actions

```dart
enum QueryAction {
  findUnique,
  findUniqueOrThrow,
  findFirst,
  findFirstOrThrow,
  findMany,
  create,
  createMany,
  update,
  updateMany,
  delete,
  deleteMany,
  count,
  aggregate,
  groupBy,
}
```

## JSON Examples

### findMany

```json
{
  "modelName": "User",
  "action": "findMany",
  "args": {
    "arguments": {
      "where": {
        "email": {"contains": "@company.com"}
      },
      "orderBy": {"createdAt": "desc"},
      "take": 10,
      "skip": 0
    }
  }
}
```

### create

```json
{
  "modelName": "User",
  "action": "create",
  "args": {
    "arguments": {
      "data": {
        "email": "new@example.com",
        "name": "New User"
      }
    }
  }
}
```

### update

```json
{
  "modelName": "User",
  "action": "update",
  "args": {
    "arguments": {
      "where": {"id": "abc123"},
      "data": {"name": "Updated Name"}
    }
  }
}
```

### delete

```json
{
  "modelName": "User",
  "action": "delete",
  "args": {
    "arguments": {
      "where": {"id": "abc123"}
    }
  }
}
```

## Filter Operators

Available in `where` clauses:

| Operator | Description | Example |
|----------|-------------|---------|
| `equals` | Exact match | `{"email": {"equals": "a@b.com"}}` |
| `not` | Not equal | `{"status": {"not": "deleted"}}` |
| `in` | In list | `{"id": {"in": ["a", "b"]}}` |
| `notIn` | Not in list | `{"id": {"notIn": ["x"]}}` |
| `lt` | Less than | `{"age": {"lt": 18}}` |
| `lte` | Less or equal | `{"age": {"lte": 18}}` |
| `gt` | Greater than | `{"age": {"gt": 18}}` |
| `gte` | Greater or equal | `{"age": {"gte": 18}}` |
| `contains` | String contains | `{"name": {"contains": "john"}}` |
| `startsWith` | String starts with | `{"name": {"startsWith": "J"}}` |
| `endsWith` | String ends with | `{"email": {"endsWith": ".com"}}` |

## Logical Operators

```json
{
  "AND": [
    {"email": {"contains": "@company.com"}},
    {"status": "active"}
  ],
  "OR": [
    {"role": "admin"},
    {"role": "moderator"}
  ],
  "NOT": {
    "status": "deleted"
  }
}
```
