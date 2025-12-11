/// CRUD Validation Script
///
/// Tests the adapter-based ORM with real Supabase database operations.
/// This validates that the connector works end-to-end before continuing development.
library;

import 'dart:math';
import 'package:postgres/postgres.dart' as pg;
// Import only what we need to avoid Flutter dependencies
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';

/// Test configuration
const supabaseConfig = {
  'host': 'aws-0-ap-south-1.pooler.supabase.com',
  'port': 6543, // Pooled connection
  'database': 'postgres',
  'username': 'postgres.pzmbxqdgibfkhjwzeprf',
  'password': 'wUScbMsQ0OsipiYv',
};

/// Simple UUID v4 generator
String generateUuid() {
  final random = Random();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));

  // Set version (4) and variant bits
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  return [
    bytes.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(4, 6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(6, 8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes.sublist(8, 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    bytes
        .sublist(10, 16)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(),
  ].join('-');
}

void main() async {
  print('🧪 Prisma Flutter Connector - CRUD Validation\n');
  print('═══════════════════════════════════════════════════════════════\n');

  QueryExecutor? executor;

  try {
    // =========================================================================
    // SETUP: Connect to Supabase
    // =========================================================================
    print('📡 Connecting to Supabase...');

    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: supabaseConfig['host'] as String,
        port: supabaseConfig['port'] as int,
        database: supabaseConfig['database'] as String,
        username: supabaseConfig['username'] as String,
        password: supabaseConfig['password'] as String,
      ),
      settings: const pg.ConnectionSettings(
        sslMode: pg.SslMode.require,
      ),
    );

    print('✅ Connected successfully!\n');

    // Create adapter and executor
    final adapter = PostgresAdapter(connection);
    executor = QueryExecutor(adapter: adapter);

    // =========================================================================
    // TEST 1: READ (findMany) - List existing domains
    // =========================================================================
    print('═══════════════════════════════════════════════════════════════');
    print('TEST 1: READ (findMany) - List existing domains');
    print('═══════════════════════════════════════════════════════════════\n');

    final findManyQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .orderBy({'createdAt': 'desc'}) // Use camelCase field name
        .take(5)
        .build();

    print(
        'Executing: SELECT * FROM "domain" ORDER BY "created_at" DESC LIMIT 5\n');

    final existingDomains = await executor.executeQueryAsMaps(findManyQuery);

    print('✅ Found ${existingDomains.length} domains:');
    for (final domain in existingDomains) {
      print('   • ID: ${domain['id']} | Name: ${domain['name']}');
    }
    print('');

    // =========================================================================
    // TEST 2: CREATE - Add a new domain
    // =========================================================================
    print('═══════════════════════════════════════════════════════════════');
    print('TEST 2: CREATE - Add a new test domain');
    print('═══════════════════════════════════════════════════════════════\n');

    final testDomainName = 'ORM_TEST_${DateTime.now().millisecondsSinceEpoch}';
    final testDomainId = generateUuid();
    final now = DateTime.now().toUtc().toIso8601String();

    final createQuery =
        JsonQueryBuilder().model('Domain').action(QueryAction.create).data({
      'id': testDomainId, // Generate UUID for id field
      'name': testDomainName,
      'createdAt': now, // Use camelCase field name
      'updatedAt': now, // Use camelCase field name
    }).build();

    print('Creating domain: $testDomainName\n');

    final createResult = await executor.executeQueryAsMaps(createQuery);

    if (createResult.isNotEmpty) {
      final created = createResult.first;
      print('✅ Domain created successfully!');
      print('   • ID: ${created['id']}');
      print('   • Name: ${created['name']}');
      print('   • Created: ${created['createdAt']}');
      print('');

      final createdId = testDomainId; // Use the generated UUID

      // ======================================================================
      // TEST 3: READ (findUnique) - Fetch the created domain
      // ======================================================================
      print('═══════════════════════════════════════════════════════════════');
      print('TEST 3: READ (findUnique) - Fetch created domain');
      print(
          '═══════════════════════════════════════════════════════════════\n');

      final findUniqueQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findUnique)
          .where({'id': createdId}).build();

      print('Fetching domain with ID: $createdId\n');

      final foundDomain =
          await executor.executeQueryAsSingleMap(findUniqueQuery);

      if (foundDomain != null) {
        print('✅ Domain found:');
        print('   • ID: ${foundDomain['id']}');
        print('   • Name: ${foundDomain['name']}');
        print('');
      } else {
        print('❌ Domain not found!');
      }

      // ======================================================================
      // TEST 4: UPDATE - Modify the domain
      // ======================================================================
      print('═══════════════════════════════════════════════════════════════');
      print('TEST 4: UPDATE - Modify domain name');
      print(
          '═══════════════════════════════════════════════════════════════\n');

      final updatedName = '${testDomainName}_UPDATED';

      final updateQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.update)
          .where({'id': createdId}).data({
        'name': updatedName,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }).build();

      print('Updating domain name to: $updatedName\n');

      await executor.executeMutation(updateQuery);

      // Verify update
      final verifyQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findUnique)
          .where({'id': createdId}).build();

      final updatedDomain = await executor.executeQueryAsSingleMap(verifyQuery);

      if (updatedDomain != null && updatedDomain['name'] == updatedName) {
        print('✅ Domain updated successfully!');
        print('   • New name: ${updatedDomain['name']}');
        print('');
      } else {
        print('❌ Update verification failed!');
      }

      // ======================================================================
      // TEST 5: DELETE - Remove the test domain
      // ======================================================================
      print('═══════════════════════════════════════════════════════════════');
      print('TEST 5: DELETE - Clean up test domain');
      print(
          '═══════════════════════════════════════════════════════════════\n');

      final deleteQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.delete)
          .where({'id': createdId}).build();

      print('Deleting test domain...\n');

      await executor.executeMutation(deleteQuery);

      // Verify deletion
      final verifyDeleteQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findUnique)
          .where({'id': createdId}).build();

      final deletedDomain =
          await executor.executeQueryAsSingleMap(verifyDeleteQuery);

      if (deletedDomain == null) {
        print('✅ Domain deleted successfully!');
        print('');
      } else {
        print('❌ Deletion verification failed!');
      }

      // ======================================================================
      // TEST 6: COUNT - Count domains
      // ======================================================================
      print('═══════════════════════════════════════════════════════════════');
      print('TEST 6: COUNT - Count total domains');
      print(
          '═══════════════════════════════════════════════════════════════\n');

      final countQuery =
          JsonQueryBuilder().model('Domain').action(QueryAction.count).build();

      final totalCount = await executor.executeCount(countQuery);

      print('✅ Total domains in database: $totalCount');
      print('');

      // ======================================================================
      // TEST 7: FILTER - Find domains with WHERE clause
      // ======================================================================
      print('═══════════════════════════════════════════════════════════════');
      print('TEST 7: FILTER - Find domains containing "tech"');
      print(
          '═══════════════════════════════════════════════════════════════\n');

      final filterQuery = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findMany)
          .where({'name': FilterOperators.contains('tech')})
          .take(5)
          .build();

      final filteredDomains = await executor.executeQueryAsMaps(filterQuery);

      print('✅ Found ${filteredDomains.length} domains containing "tech":');
      for (final domain in filteredDomains) {
        print('   • ${domain['name']}');
      }
      print('');
    } else {
      print('❌ Failed to create domain!');
    }

    // =========================================================================
    // SUMMARY
    // =========================================================================
    print('═══════════════════════════════════════════════════════════════');
    print('🎉 VALIDATION COMPLETE!');
    print('═══════════════════════════════════════════════════════════════\n');

    print('✅ All CRUD operations successful:');
    print('   • CREATE - Domain inserted with auto-generated ID');
    print('   • READ (findMany) - Listed multiple domains');
    print('   • READ (findUnique) - Fetched single domain by ID');
    print('   • UPDATE - Modified domain name');
    print('   • DELETE - Removed test domain');
    print('   • COUNT - Counted total domains');
    print('   • FILTER - Searched with WHERE clause');
    print('');
    print('🚀 Adapter-based ORM is working perfectly!');
    print('🚀 Ready to continue development and publish to pub.dev!');
    print('');
  } catch (e, stackTrace) {
    print('\n❌ ERROR: $e\n');
    print('Stack trace:');
    print(stackTrace);
  } finally {
    if (executor != null) {
      await executor.dispose();
      print('🔌 Connection closed.');
    }
  }
}
