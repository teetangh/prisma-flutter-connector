/// Prisma Flutter Connector - Server Runtime Library
///
/// This library provides the runtime components for pure Dart server environments
/// (Dart Frog, Shelf, etc.) without Flutter dependencies.
///
/// **Use this instead of `runtime.dart` when:**
/// - Building Dart Frog backends
/// - Building Shelf/Alfred servers
/// - Any pure Dart server environment
///
/// **Use `runtime.dart` when:**
/// - Building Flutter mobile/web apps
/// - Need SQLite support for offline-first mobile apps
///
/// ## Why This Exists
///
/// The main `runtime.dart` exports the SQLite adapter which depends on `sqflite`,
/// a Flutter plugin that imports `dart:ui`. This causes compilation errors in
/// pure Dart environments where Flutter SDK is not available.
///
/// This library exports only the PostgreSQL and Supabase adapters which use the
/// pure Dart `postgres` package.
///
/// ## Supported Databases
///
/// - **PostgreSQL** via `postgres` package
/// - **Supabase** (PostgreSQL with direct connection)
///
/// ## Usage
///
/// ```dart
/// // In your Dart Frog backend:
/// import 'package:prisma_flutter_connector/runtime_server.dart';
/// import 'package:postgres/postgres.dart' as pg;
///
/// // Connect to database
/// final connection = await pg.Connection.open(
///   pg.Endpoint(
///     host: 'localhost',
///     database: 'mydb',
///     username: 'user',
///     password: 'password',
///   ),
/// );
///
/// // Create adapter
/// final adapter = PostgresAdapter(connection);
/// final executor = QueryExecutor(adapter: adapter);
///
/// // Build and execute query
/// final query = JsonQueryBuilder()
///     .model('User')
///     .action(QueryAction.findMany)
///     .where({'email': FilterOperators.contains('@example.com')})
///     .orderBy({'createdAt': 'desc'})
///     .build();
///
/// final users = await executor.executeQueryAsMaps(query);
/// print('Found ${users.length} users');
/// ```
///
/// ## Supabase Connection
///
/// ```dart
/// final adapter = await SupabaseAdapter.fromConnectionString(
///   'postgresql://user:pass@host:6543/db?pgbouncer=true',
/// );
/// final executor = QueryExecutor(adapter: adapter);
/// ```
///
/// ## Transactions
///
/// ```dart
/// await executor.executeInTransaction((tx) async {
///   await tx.executeMutation(createUserQuery);
///   await tx.executeMutation(createProfileQuery);
///   // Both succeed or both rollback
/// });
/// ```
library prisma_flutter_connector.runtime_server;

// Core adapter types (pure Dart - no Flutter dependencies)
export 'src/runtime/adapters/types.dart';

// Server-safe database adapters (use only `postgres` package)
export 'src/runtime/adapters/postgres_adapter.dart';
export 'src/runtime/adapters/supabase_adapter.dart';
// Note: SQLite adapter is NOT exported here as it requires Flutter's sqflite package
// Use `runtime.dart` instead if you need SQLite support in a Flutter app

// Query building (pure Dart - no Flutter dependencies)
export 'src/runtime/query/json_protocol.dart';
export 'src/runtime/query/sql_compiler.dart';
export 'src/runtime/query/query_executor.dart';
