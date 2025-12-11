# PostgreSQL Adapter

Direct connection to PostgreSQL databases.

## Location

`lib/src/runtime/adapters/postgres_adapter.dart`

## Installation

The `postgres` package is included as a dependency.

## Usage

```dart
import 'package:prisma_flutter_connector/runtime.dart';

final adapter = PostgresAdapter(
  host: 'localhost',
  port: 5432,
  database: 'mydb',
  username: 'postgres',
  password: 'password',
  sslMode: SslMode.disable, // or SslMode.require for production
);

// Connect before using
await adapter.connect();

// Use with PrismaClient
final prisma = PrismaClient(adapter: adapter);

// Don't forget to close
await adapter.close();
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `host` | String | required | Database host |
| `port` | int | 5432 | Database port |
| `database` | String | required | Database name |
| `username` | String | required | Username |
| `password` | String | required | Password |
| `sslMode` | SslMode | disable | SSL mode |
| `timeout` | Duration | 30s | Connection timeout |

## SSL Modes

```dart
enum SslMode {
  disable,    // No SSL
  require,    // Require SSL, don't verify certificate
  verifyFull, // Require SSL with certificate verification
}
```

## Transactions

```dart
final results = await adapter.transaction([
  SqlQuery(sql: 'INSERT INTO users (email) VALUES (\$1)', args: ['a@b.com']),
  SqlQuery(sql: 'INSERT INTO profiles (userId) VALUES (\$1)', args: [userId]),
], isolationLevel: IsolationLevel.serializable);
```

## Type Mappings

| PostgreSQL | Dart |
|------------|------|
| INTEGER | int |
| BIGINT | int |
| REAL/FLOAT | double |
| DOUBLE PRECISION | double |
| NUMERIC/DECIMAL | Decimal |
| BOOLEAN | bool |
| VARCHAR/TEXT | String |
| TIMESTAMP | DateTime |
| TIMESTAMPTZ | DateTime |
| UUID | String |
| JSONB | Map<String, dynamic> |
| BYTEA | Uint8List |

## Connection Pooling

The adapter uses the `postgres` package's built-in connection pooling:

```dart
final adapter = PostgresAdapter(
  host: 'localhost',
  database: 'mydb',
  username: 'user',
  password: 'pass',
  // Pool settings are managed internally
);
```

## Error Handling

```dart
try {
  await adapter.queryRaw(query);
} on PostgresException catch (e) {
  print('Database error: ${e.message}');
  print('Code: ${e.code}');
}
```
