# Supabase Adapter

Connect to Supabase PostgreSQL databases directly.

## Location

`lib/src/runtime/adapters/supabase_adapter.dart`

## Overview

The Supabase adapter connects directly to your Supabase PostgreSQL database, bypassing the REST/GraphQL APIs for maximum performance and full SQL capabilities.

## Usage

```dart
import 'package:prisma_flutter_connector/runtime.dart';

final adapter = SupabaseAdapter(
  host: 'db.xxxx.supabase.co',
  port: 5432,
  database: 'postgres',
  username: 'postgres',
  password: 'your-database-password', // From Supabase dashboard
  sslMode: SslMode.require,
);

await adapter.connect();

final prisma = PrismaClient(adapter: adapter);
```

## Getting Connection Details

1. Go to your Supabase project dashboard
2. Navigate to **Settings** > **Database**
3. Find the connection string under "Connection string" > "URI"
4. Extract the components:
   - Host: `db.xxxx.supabase.co`
   - Port: `5432` (or `6543` for connection pooling)
   - Database: `postgres`
   - Username: `postgres`
   - Password: Your database password

## Environment Variables

```dart
final adapter = SupabaseAdapter(
  host: Platform.environment['SUPABASE_HOST']!,
  port: int.parse(Platform.environment['SUPABASE_PORT'] ?? '5432'),
  database: Platform.environment['SUPABASE_DATABASE'] ?? 'postgres',
  username: Platform.environment['SUPABASE_USER'] ?? 'postgres',
  password: Platform.environment['SUPABASE_PASSWORD']!,
  sslMode: SslMode.require,
);
```

## Connection Pooling

For production, use Supabase's connection pooler (port 6543):

```dart
final adapter = SupabaseAdapter(
  host: 'db.xxxx.supabase.co',
  port: 6543,  // Pooler port
  database: 'postgres',
  username: 'postgres.xxxx', // Project ref added for pooler
  password: 'password',
  sslMode: SslMode.require,
);
```

## Row Level Security (RLS)

The direct database connection bypasses RLS by default. To enable RLS:

1. Create a role with RLS enabled
2. Use that role's credentials
3. Or use Supabase's REST API for RLS-protected queries

## Limitations

- Bypasses Supabase's REST/GraphQL caching
- No automatic JWT handling
- RLS requires explicit role configuration
- Realtime subscriptions not supported (use Supabase client for those)

## When to Use

**Use Supabase Adapter when:**
- You need complex queries (JOINs, aggregations)
- Performance is critical
- You're doing batch operations
- You control the database schema

**Use Supabase REST API when:**
- You need RLS enforcement
- You want automatic caching
- You need realtime subscriptions
