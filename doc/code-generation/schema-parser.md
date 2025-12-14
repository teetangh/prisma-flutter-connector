# Schema Parser

The `PrismaParser` class parses Prisma schema files (`.prisma`) into an AST that can be used for code generation.

## Location

`lib/src/generator/prisma_parser.dart`

## Usage

```dart
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

final parser = PrismaParser();
final schema = parser.parse(schemaContent);

// Access parsed data
print('Provider: ${schema.datasourceProvider}');
print('Models: ${schema.models.length}');
print('Enums: ${schema.enums.length}');
```

## Parsed Schema Structure

### PrismaSchema

```dart
class PrismaSchema {
  final List<PrismaModel> models;
  final List<PrismaEnum> enums;
  final String datasourceProvider; // 'postgresql', 'mysql', 'sqlite'
}
```

### PrismaModel

```dart
class PrismaModel {
  final String name;           // Dart class name
  final String? dbName;        // Original table name if renamed
  final List<PrismaField> fields;
  final List<PrismaRelation> relations;

  String get tableName => dbName ?? name; // For SQL queries
}
```

### PrismaField

```dart
class PrismaField {
  final String name;
  final String type;           // 'String', 'Int', 'DateTime', etc.
  final bool isRequired;
  final bool isList;
  final bool isId;
  final bool isUnique;
  final String? defaultValue;
  final bool isUpdatedAt;
  final bool isCreatedAt;
  final bool isRelation;
  final String? dbName;        // Original column name if renamed
}
```

## Reserved Keyword Handling

Dart has reserved keywords that cannot be used as identifiers. The parser automatically renames these:

| Schema Name | Dart Name | Database Name |
|-------------|-----------|---------------|
| `Class` (model) | `ClassModel` | `Class` (via @@map) |
| `class` (field) | `classRef` | `class` (via @map) |
| `enum` (field) | `enumValue` | `enum` |
| `type` (field) | `typeValue` | `type` |

The original names are preserved in `dbName` for database queries.

## Supported Features

- Model definitions with all field types
- Relations (one-to-one, one-to-many, many-to-many)
- Enums
- Field attributes: `@id`, `@unique`, `@default`, `@updatedAt`
- Model attributes: `@@map`, `@@unique`, `@@index`
- Datasource providers: PostgreSQL, MySQL, SQLite, MongoDB

## Example

Input schema:
```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String?
  posts     Post[]
  createdAt DateTime @default(now())
}
```

Parsed output:
```dart
PrismaModel(
  name: 'User',
  fields: [
    PrismaField(name: 'id', type: 'String', isId: true),
    PrismaField(name: 'email', type: 'String', isUnique: true),
    PrismaField(name: 'name', type: 'String', isRequired: false),
    PrismaField(name: 'createdAt', type: 'DateTime', isCreatedAt: true),
  ],
  relations: [
    PrismaRelation(name: 'posts', type: 'Post', isList: true),
  ],
)
```
