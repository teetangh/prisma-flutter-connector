/// Example demonstrating the new adapter-based architecture.
///
/// This shows how to use the Prisma Flutter Connector with direct database
/// connections, similar to how Prisma works in TypeScript/Next.js.
///
/// No GraphQL backend required!

import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/adapters.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';

Future<void> main() async {
  print('🚀 Prisma Flutter Connector - Adapter Example\n');

  // ============================================================================
  // EXAMPLE 1: PostgreSQL Direct Connection
  // ============================================================================
  print('📦 Example 1: PostgreSQL Direct Connection\n');

  // Connect to PostgreSQL
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: 'localhost',
      database: 'mydb',
      username: 'postgres',
      password: 'password',
    ),
  );

  // Create adapter
  final adapter = PostgresAdapter(connection);

  // Create query executor
  final executor = QueryExecutor(adapter: adapter);

  // Build a query using JSON protocol
  final query = JsonQueryBuilder()
      .model('User')
      .action(QueryAction.findMany)
      .where({'email': FilterOperators.contains('@example.com')})
      .orderBy({'createdAt': 'desc'})
      .take(10)
      .build();

  try {
    // Execute query
    final users = await executor.executeQueryAsMaps(query);

    print('Found ${users.length} users:');
    for (final user in users) {
      print('  - ${user['name']} (${user['email']})');
    }
  } finally {
    await executor.dispose();
  }

  print('');

  // ============================================================================
  // EXAMPLE 2: Supabase Connection
  // ============================================================================
  print('📦 Example 2: Supabase Connection\n');

  final supabaseAdapter = await SupabaseAdapter.fromConnectionString(
    'postgresql://postgres.projectid:password@host:6543/postgres?pgbouncer=true',
  );

  final supabaseExecutor = QueryExecutor(adapter: supabaseAdapter);

  // Create a new domain
  final createQuery = JsonQueryBuilder()
      .model('Domain')
      .action(QueryAction.create)
      .data({
        'name': 'Technology',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      })
      .build();

  try {
    await supabaseExecutor.executeMutation(createQuery);
    print('✅ Created domain successfully');

    // Query all domains
    final domainsQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .orderBy({'createdAt': 'desc'})
        .build();

    final domains = await supabaseExecutor.executeQueryAsMaps(domainsQuery);
    print('Found ${domains.length} domains');
  } finally {
    await supabaseExecutor.dispose();
  }

  print('');

  // ============================================================================
  // EXAMPLE 3: Transactions
  // ============================================================================
  print('📦 Example 3: Transactions\n');

  final txAdapter = await SupabaseAdapter.fromConnectionString(
    'postgresql://...',
  );

  final txExecutor = QueryExecutor(adapter: txAdapter);

  try {
    await txExecutor.executeInTransaction((tx) async {
      // Create a user
      final createUser = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.create)
          .data({
            'email': 'newuser@example.com',
            'name': 'New User',
          })
          .build();

      await tx.executeMutation(createUser);

      // Create a profile for the user
      final createProfile = JsonQueryBuilder()
          .model('Profile')
          .action(QueryAction.create)
          .data({
            'bio': 'Hello world',
          })
          .build();

      await tx.executeMutation(createProfile);

      print('✅ Transaction completed successfully');

      // If we throw here, both inserts will be rolled back
      // throw Exception('Rollback!');
    });
  } finally {
    await txExecutor.dispose();
  }

  print('');

  // ============================================================================
  // EXAMPLE 4: SQLite (Mobile - Offline First)
  // ============================================================================
  print('📦 Example 4: SQLite (Mobile - Offline First)\n');
  print('(This would work in a real Flutter app with sqflite)\n');

  // In a real Flutter app:
  // import 'package:sqflite/sqflite.dart';
  //
  // final database = await openDatabase(
  //   'app.db',
  //   version: 1,
  //   onCreate: (db, version) async {
  //     await db.execute('''
  //       CREATE TABLE users (
  //         id TEXT PRIMARY KEY,
  //         name TEXT NOT NULL,
  //         email TEXT UNIQUE NOT NULL,
  //         created_at TEXT NOT NULL
  //       )
  //     ''');
  //   },
  // );
  //
  // final sqliteAdapter = SQLiteAdapter(database);
  // final sqliteExecutor = QueryExecutor(adapter: sqliteAdapter);
  //
  // // Now you can use Prisma API offline!
  // final localUsers = await sqliteExecutor.executeQueryAsMaps(
  //   JsonQueryBuilder()
  //       .model('User')
  //       .action(QueryAction.findMany)
  //       .build(),
  // );

  print('✅ All examples completed!\n');

  print('==================================================================');
  print('🎉 Key Benefits:');
  print('');
  print('1. ✅ No GraphQL backend required');
  print('2. ✅ Direct database access from Dart');
  print('3. ✅ Works offline with SQLite');
  print('4. ✅ Type-safe query building');
  print('5. ✅ Transaction support');
  print('6. ✅ Database-agnostic (swap adapters easily)');
  print('7. ✅ Same DX as Prisma in TypeScript!');
  print('==================================================================');
}
