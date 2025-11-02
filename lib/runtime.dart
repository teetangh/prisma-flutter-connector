/// Prisma Flutter Connector - Runtime Library
///
/// This library provides the runtime components for the Prisma Flutter Connector,
/// enabling direct database access from Dart/Flutter applications without requiring
/// a GraphQL backend.
///
/// ## Features
///
/// - **Direct Database Access**: Connect directly to PostgreSQL, MySQL, SQLite, and Supabase
/// - **Type-Safe Queries**: Build queries using Prisma's JSON protocol
/// - **Multiple Adapters**: Swap database providers easily
/// - **Transaction Support**: Full ACID transaction support
/// - **Offline-First**: Use SQLite adapter for mobile offline capabilities
///
/// ## Supported Databases
///
/// - **PostgreSQL** via `postgres` package
/// - **Supabase** (PostgreSQL with direct connection)
/// - **SQLite** via `sqflite` package (mobile)
/// - **MySQL** (coming soon)
///
/// ## Usage
///
/// ```dart
/// import 'package:prisma_flutter_connector/runtime.dart';
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
/// ## Database Adapters
///
/// ### PostgreSQL
/// ```dart
/// final adapter = PostgresAdapter(connection);
/// ```
///
/// ### Supabase
/// ```dart
/// final adapter = await SupabaseAdapter.fromConnectionString(
///   'postgresql://user:pass@host:6543/db?pgbouncer=true',
/// );
/// ```
///
/// ### SQLite (Mobile)
/// ```dart
/// final database = await openDatabase('app.db');
/// final adapter = SQLiteAdapter(database);
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
library prisma_flutter_connector.runtime;

// Core adapter types
export 'src/runtime/adapters/types.dart';

// Database adapters
export 'src/runtime/adapters/postgres_adapter.dart';
export 'src/runtime/adapters/supabase_adapter.dart';
export 'src/runtime/adapters/sqlite_adapter.dart';

// Query building
export 'src/runtime/query/json_protocol.dart';
export 'src/runtime/query/sql_compiler.dart';
export 'src/runtime/query/query_executor.dart';
