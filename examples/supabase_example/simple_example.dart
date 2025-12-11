/// Simple Working Example - Prisma-Style ORM in Dart
///
/// This demonstrates the adapter-based ORM working with Supabase.
/// Uses the runtime library directly (no code generation needed for this demo).
///
/// ⚠️ NOTE: This example uses the low-level runtime API (JsonQueryBuilder)
/// for demonstration purposes. In production, use the type-safe generated client!
///
/// See type_safe_example.dart for the recommended type-safe approach.
library;

import 'dart:io';
import 'dart:math';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart' as pg;
// Import only what we need to avoid Flutter dependencies
import 'package:prisma_flutter_connector/src/runtime/adapters/supabase_adapter.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';

/// Simple UUID v4 generator
String generateUuid() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return [
    bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(10, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
  ].join('-');
}

void main() async {
  print('🎯 Prisma Flutter Connector - Live Demo\n');
  print('═══════════════════════════════════════════════════');
  print('Direct Database Access - No Backend Required!');
  print('═══════════════════════════════════════════════════\n');

  // Load environment variables
  final env = DotEnv()..load();

  final host = env['SUPABASE_HOST'];
  final port = int.tryParse(env['SUPABASE_PORT'] ?? '6543') ?? 6543;
  final database = env['SUPABASE_DATABASE'] ?? 'postgres';
  final username = env['SUPABASE_USERNAME'];
  final password = env['SUPABASE_PASSWORD'];

  if (host == null || username == null || password == null) {
    print('❌ Error: Missing environment variables!');
    print('Please create a .env file with:');
    print('  SUPABASE_HOST=your-host');
    print('  SUPABASE_PORT=6543');
    print('  SUPABASE_DATABASE=postgres');
    print('  SUPABASE_USERNAME=your-username');
    print('  SUPABASE_PASSWORD=your-password');
    exit(1);
  }

  // Connect to Supabase
  print('📡 Connecting to Supabase PostgreSQL...');
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    ),
    settings: const pg.ConnectionSettings(
      sslMode: pg.SslMode.require,
    ),
  );
  print('✅ Connected!\n');

  // Create adapter and executor
  final adapter = SupabaseAdapter(connection);
  final executor = QueryExecutor(adapter: adapter);

  try {
    // Example 1: findMany with ordering
    print('══════════════════════════════════════════════════');
    print('Example 1: Find Many Domains (with ordering)');
    print('══════════════════════════════════════════════════\n');

    final query1 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .orderBy({'createdAt': 'desc'})
        .take(5)
        .build();

    final domains = await executor.executeQueryAsMaps(query1);
    print('Found ${domains.length} domains:');
    for (final domain in domains) {
      print('  • ${domain['name']} (ID: ${domain['id']})');
    }
    print('');

    // Example 2: findUnique
    if (domains.isNotEmpty) {
      print('══════════════════════════════════════════════════');
      print('Example 2: Find Unique Domain by ID');
      print('══════════════════════════════════════════════════\n');

      final query2 = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findUnique)
          .where({'id': domains.first['id']})
          .build();

      final domain = await executor.executeQueryAsSingleMap(query2);
      if (domain != null) {
        print('✅ Found: ${domain['name']}');
        print('   Created: ${domain['createdAt']}');
        print('');
      }
    }

    // Example 3: Count
    print('══════════════════════════════════════════════════');
    print('Example 3: Count Total Domains');
    print('══════════════════════════════════════════════════\n');

    final query3 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.count)
        .build();

    final count = await executor.executeCount(query3);
    print('Total domains: $count');
    print('');

    // Example 4: Filter with WHERE clause
    print('══════════════════════════════════════════════════');
    print('Example 4: Filter Newsletters (contains filter)');
    print('══════════════════════════════════════════════════\n');

    final query4 = JsonQueryBuilder()
        .model('Newsletter')
        .action(QueryAction.findMany)
        .where({'email': FilterOperators.contains('@')})
        .take(3)
        .build();

    final newsletters = await executor.executeQueryAsMaps(query4);
    print('Found ${newsletters.length} newsletter subscribers:');
    for (final newsletter in newsletters) {
      print('  • ${newsletter['email']}');
    }
    print('');

    // Example 5: Full CRUD cycle
    print('══════════════════════════════════════════════════');
    print('Example 5: Complete CRUD Cycle');
    print('══════════════════════════════════════════════════\n');

    final testId = generateUuid();
    final testName = 'TEST_${DateTime.now().millisecondsSinceEpoch}';

    // CREATE
    print('1️⃣  CREATE');
    final createQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.create)
        .data({
          'id': testId,
          'name': testName,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        })
        .build();

    await executor.executeMutation(createQuery);
    print('   ✅ Created domain: $testName');

    // READ
    print('2️⃣  READ');
    final readQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findUnique)
        .where({'id': testId})
        .build();

    final created = await executor.executeQueryAsSingleMap(readQuery);
    print('   ✅ Read domain: ${created!['name']}');

    // UPDATE
    print('3️⃣  UPDATE');
    final updateQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.update)
        .where({'id': testId})
        .data({
          'name': '${testName}_UPDATED',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        })
        .build();

    await executor.executeMutation(updateQuery);

    final updated = await executor.executeQueryAsSingleMap(readQuery);
    print('   ✅ Updated domain: ${updated!['name']}');

    // DELETE
    print('4️⃣  DELETE');
    final deleteQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.delete)
        .where({'id': testId})
        .build();

    await executor.executeMutation(deleteQuery);
    print('   ✅ Deleted domain (cleanup)');
    print('');

    // Summary
    print('══════════════════════════════════════════════════');
    print('🎉 SUCCESS - All Operations Complete!');
    print('══════════════════════════════════════════════════\n');

    print('✨ What we just demonstrated:');
    print('  ✅ Direct Supabase connection (no backend!)');
    print('  ✅ Type-safe query building (JsonQueryBuilder)');
    print('  ✅ Parameterized SQL generation (SQL injection safe)');
    print('  ✅ Full CRUD operations (Create, Read, Update, Delete)');
    print('  ✅ Complex filters (WHERE, ORDER BY, LIMIT)');
    print('  ✅ Count aggregations');
    print('  ✅ String filters (contains, etc.)');
    print('');

    print('🚀 This is Prisma-style ORM in pure Dart!');
    print('   No GraphQL backend required.');
    print('   Works with PostgreSQL, MySQL, SQLite, Supabase.');
    print('');

    print('📦 Next: Run code generation to get type-safe models:');
    print('   dart run prisma_flutter_connector:generate \\');
    print('     --schema schema.prisma \\');
    print('     --output lib/generated');
    print('');

  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print(stackTrace);
  } finally {
    await executor.dispose();
    print('🔌 Disconnected from database');
  }
}
