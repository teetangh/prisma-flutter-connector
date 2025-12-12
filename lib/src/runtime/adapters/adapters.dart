/// Database adapters for Prisma Flutter Connector.
///
/// This library provides database adapters that enable direct database
/// connections from Dart/Flutter, similar to how Prisma works in TypeScript/Node.js.
///
/// Supported databases:
/// - PostgreSQL (via `postgres` package)
/// - Supabase (via direct PostgreSQL connection)
/// - SQLite (via `sqflite` package for mobile)
/// - MySQL (via `mysql_client` package)
library;

export 'types.dart';
export 'postgres_adapter.dart';
export 'supabase_adapter.dart';
export 'sqlite_adapter.dart';
export 'mysql_adapter.dart';
