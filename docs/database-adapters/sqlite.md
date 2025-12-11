# SQLite Adapter

Embedded SQLite database for mobile and offline-first applications.

## Location

`lib/src/runtime/adapters/sqlite_adapter.dart`

## Overview

The SQLite adapter uses `sqflite` for mobile platforms, providing a local embedded database. Ideal for offline-first apps or local data storage.

## Usage

```dart
import 'package:prisma_flutter_connector/runtime.dart';

final adapter = SQLiteAdapter(
  path: 'app_database.db',
);

await adapter.connect();

final prisma = PrismaClient(adapter: adapter);
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `path` | String | required | Database file path |
| `version` | int | 1 | Schema version |
| `onCreate` | Function | null | Called on first creation |
| `onUpgrade` | Function | null | Called on version upgrade |

## Database Path

```dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Get the default databases directory
final dbPath = await getDatabasesPath();
final path = join(dbPath, 'my_app.db');

final adapter = SQLiteAdapter(path: path);
```

## In-Memory Database

For testing:

```dart
final adapter = SQLiteAdapter(path: ':memory:');
```

## Migrations

```dart
final adapter = SQLiteAdapter(
  path: 'app.db',
  version: 2,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT
      )
    ''');
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN avatar TEXT');
    }
  },
);
```

## Type Mappings

| SQLite | Dart |
|--------|------|
| INTEGER | int |
| REAL | double |
| TEXT | String |
| BLOB | Uint8List |
| NULL | null |

**Note:** SQLite has limited type system. Dates are stored as TEXT (ISO8601) or INTEGER (Unix timestamp).

## Transactions

```dart
await adapter.transaction([
  SqlQuery(sql: 'INSERT INTO users (id, email) VALUES (?, ?)', args: ['1', 'a@b.com']),
  SqlQuery(sql: 'INSERT INTO profiles (userId) VALUES (?)', args: ['1']),
]);
```

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android | ✅ |
| iOS | ✅ |
| macOS | ✅ |
| Windows | ✅ (via sqflite_common_ffi) |
| Linux | ✅ (via sqflite_common_ffi) |
| Web | ❌ (use IndexedDB) |

## Desktop Support

For Windows/Linux, add `sqflite_common_ffi`:

```yaml
dependencies:
  sqflite_common_ffi: ^2.3.0
```

```dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(MyApp());
}
```

## Limitations

- No concurrent write access (SQLite locks database)
- Limited data types compared to PostgreSQL
- No network access (local only)
- Single database file
