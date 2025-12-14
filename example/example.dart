/// Prisma Flutter Connector - Complete Example
///
/// This example demonstrates the main features of prisma_flutter_connector:
/// - Direct database connections (no GraphQL backend required)
/// - Multiple database adapters (PostgreSQL, Supabase, SQLite, MySQL)
/// - Type-safe query building
/// - Transaction support
///
/// ## Quick Start
///
/// ```dart
/// // 1. Create a database adapter
/// final adapter = await SupabaseAdapter.fromConnectionString(
///   'postgresql://user:pass@host:6543/db',
/// );
///
/// // 2. Execute queries
/// final result = await adapter.queryRaw(
///   SqlQuery('SELECT * FROM users WHERE id = \$1', ['user-123']),
/// );
///
/// // 3. Close connection when done
/// await adapter.dispose();
/// ```
library;

import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/adapters.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';

/// Main entry point demonstrating prisma_flutter_connector usage.
Future<void> main() async {
  print('Prisma Flutter Connector - Example\n');

  // ========================================================================
  // BASIC USAGE: Connect and Query
  // ========================================================================

  // Option 1: PostgreSQL direct connection
  await _postgresExample();

  // Option 2: Supabase connection (recommended for cloud apps)
  await _supabaseExample();

  // Option 3: Using the Query Builder
  await _queryBuilderExample();

  // Option 4: Transaction example
  await _transactionExample();

  print('\nAll examples completed!');
}

/// Example 1: Direct PostgreSQL Connection
Future<void> _postgresExample() async {
  print('--- PostgreSQL Direct Connection ---');

  // Connect to PostgreSQL
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: 'localhost',
      database: 'mydb',
      username: 'postgres',
      password: 'password',
    ),
  );

  try {
    // Create adapter from connection
    final adapter = PostgresAdapter(connection);

    // Execute raw SQL query
    final result = await adapter.queryRaw(
      const SqlQuery(
        sql: 'SELECT id, name, email FROM users LIMIT 5',
        args: [],
        argTypes: [],
      ),
    );

    print('Found ${result.rows.length} users');
    // Rows are returned as List<List<dynamic>> with column order matching columnNames
    final nameIdx = result.columnNames.indexOf('name');
    final emailIdx = result.columnNames.indexOf('email');
    for (final row in result.rows) {
      print('  - ${row[nameIdx]} (${row[emailIdx]})');
    }

    await adapter.dispose();
  } catch (e) {
    print('PostgreSQL example skipped: $e');
  }

  print('');
}

/// Example 2: Supabase Connection
Future<void> _supabaseExample() async {
  print('--- Supabase Connection ---');

  try {
    // Create adapter from connection string
    // Supports both pooled (:6543) and direct (:5432) connections
    final adapter = await SupabaseAdapter.fromConnectionString(
      'postgresql://postgres.projectid:password@host:6543/postgres',
    );

    // Execute query
    final result = await adapter.queryRaw(
      const SqlQuery(
        sql: 'SELECT COUNT(*) as count FROM users',
        args: [],
        argTypes: [],
      ),
    );

    // Access count from first row, first column
    print('Total users: ${result.rows.first.first}');

    await adapter.dispose();
  } catch (e) {
    print('Supabase example skipped: $e');
  }

  print('');
}

/// Example 3: Type-Safe Query Builder
Future<void> _queryBuilderExample() async {
  print('--- Query Builder ---');

  // The JsonQueryBuilder provides a type-safe way to build queries
  // similar to Prisma's query API

  // Find many with filters
  final findManyQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.findMany)
      .where({'email': FilterOperators.contains('@example.com')})
      .orderBy({'createdAt': 'desc'})
      .take(10)
      .build();

  print('Find many query: $findManyQuery');

  // Find unique by ID
  final findUniqueQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.findUnique)
      .where({'id': 'user-123'})
      .build();

  print('Find unique query: $findUniqueQuery');

  // Create new record
  final createQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.create)
      .data({
        'email': 'newuser@example.com',
        'name': 'New User',
      })
      .build();

  print('Create query: $createQuery');

  // Update existing record
  final updateQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.update)
      .where({'id': 'user-123'})
      .data({'name': 'Updated Name'})
      .build();

  print('Update query: $updateQuery');

  // Delete record
  final deleteQuery = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.delete)
      .where({'id': 'user-123'})
      .build();

  print('Delete query: $deleteQuery');

  print('');
}

/// Example 4: Transactions
Future<void> _transactionExample() async {
  print('--- Transactions ---');

  print('Transaction support ensures atomic operations:');
  print('');
  print('  await executor.executeInTransaction((tx) async {');
  print('    // Create user');
  print('    await tx.executeMutation(createUserQuery);');
  print('    ');
  print('    // Create profile (linked to user)');
  print('    await tx.executeMutation(createProfileQuery);');
  print('    ');
  print('    // If any operation fails, all changes are rolled back');
  print('  });');
  print('');

  print('Supported isolation levels:');
  print('  - IsolationLevel.readUncommitted');
  print('  - IsolationLevel.readCommitted');
  print('  - IsolationLevel.repeatableRead');
  print('  - IsolationLevel.serializable');

  print('');
}
