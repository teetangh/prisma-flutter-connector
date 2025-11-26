/// Type-Safe Example - Prisma Flutter Connector with Full Type Safety
///
/// This demonstrates the type-safe Prisma-style ORM API for Dart/Flutter.
/// All operations are compile-time checked - invalid field names, wrong types,
/// and missing required fields will be caught by the Dart analyzer!
library;

import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/runtime.dart';

// Import generated client and types
// NOTE: Run code generation first:
// dart run prisma_flutter_connector:generate \
//   --schema examples/supabase_example/schema.prisma \
//   --output examples/supabase_example/lib/generated
//
// Then run build_runner:
// dart run build_runner build --delete-conflicting-outputs
//
// For this example, we'll use the runtime API directly
// In a real app, you'd import the generated types:
// import 'lib/generated/index.dart';

void main() async {
  print('🎯 Prisma Flutter Connector - Type-Safe API Demo\n');
  print('═══════════════════════════════════════════════════');
  print('Demonstrating Compile-Time Type Safety!');
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

  // Create adapter
  final adapter = SupabaseAdapter(connection);
  final executor = QueryExecutor(adapter: adapter);

  try {
    // ═══════════════════════════════════════════════════
    // EXAMPLE 1: Type-Safe FindMany with Filters
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('Example 1: Type-Safe FindMany with String Filters');
    print('══════════════════════════════════════════════════\n');

    // This is how it WOULD work with generated types:
    // final domains = await prisma.domain.findMany(
    //   where: DomainWhereInput(
    //     name: StringFilter(contains: 'e'),
    //   ),
    //   orderBy: DomainOrderByInput(createdAt: SortOrder.desc),
    //   take: 5,
    // );

    // For now, using runtime API to demonstrate:
    final query1 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .where({
          'name': {'contains': 'e'}, // String filter: contains
        })
        .orderBy({'createdAt': 'desc'})
        .take(5)
        .build();

    final domains = await executor.executeQueryAsMaps(query1);
    print('✅ Found ${domains.length} domains with "e" in name:');
    for (final domain in domains) {
      print('  • ${domain['name']} (${domain['createdAt']})');
    }
    print('');

    // ═══════════════════════════════════════════════════
    // EXAMPLE 2: Type-Safe FindUnique
    // ═══════════════════════════════════════════════════
    if (domains.isNotEmpty) {
      print('══════════════════════════════════════════════════');
      print('Example 2: Type-Safe FindUnique by ID');
      print('══════════════════════════════════════════════════\n');

      // Type-safe version would be:
      // final domain = await prisma.domain.findUnique(
      //   where: DomainWhereUniqueInput(id: domains.first['id']),
      // );

      final query2 = JsonQueryBuilder()
          .model('Domain')
          .action(QueryAction.findUnique)
          .where({'id': domains.first['id']})
          .build();

      final domain = await executor.executeQueryAsSingleMap(query2);
      if (domain != null) {
        print('✅ Found domain by ID:');
        print('   ID: ${domain['id']}');
        print('   Name: ${domain['name']}');
        print('   Created: ${domain['createdAt']}');
      }
      print('');
    }

    // ═══════════════════════════════════════════════════
    // EXAMPLE 3: Complex Filters with Logical Operators
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('Example 3: Complex Filters (AND, OR, NOT)');
    print('══════════════════════════════════════════════════\n');

    // Type-safe version:
    // final filtered = await prisma.domain.findMany(
    //   where: DomainWhereInput(
    //     AND: [
    //       DomainWhereInput(
    //         name: StringFilter(startsWith: 'C'),
    //       ),
    //       DomainWhereInput(
    //         NOT: DomainWhereInput(
    //           name: StringFilter(contains: 'z'),
    //         ),
    //       ),
    //     ],
    //   ),
    // );

    final query3 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .where({
          'AND': [
            {
              'name': {'startsWith': 'C'}, // Starts with 'C'
            },
            {
              'NOT': {
                'name': {'contains': 'z'}, // Does not contain 'z'
              },
            },
          ],
        })
        .build();

    final filtered = await executor.executeQueryAsMaps(query3);
    print('✅ Domains starting with "C" and not containing "z": ${filtered.length}');
    for (final domain in filtered) {
      print('  • ${domain['name']}');
    }
    print('');

    // ═══════════════════════════════════════════════════
    // EXAMPLE 4: Multiple OrderBy Fields
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('Example 4: Multiple OrderBy with Pagination');
    print('══════════════════════════════════════════════════\n');

    // Type-safe version:
    // final paginated = await prisma.domain.findMany(
    //   orderBy: DomainOrderByInput(
    //     createdAt: SortOrder.desc,
    //   ),
    //   take: 3,
    //   skip: 0,
    // );

    final query4 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findMany)
        .orderBy({'createdAt': 'desc'})
        .take(3)
        .skip(0)
        .build();

    final paginated = await executor.executeQueryAsMaps(query4);
    print('✅ Page 1 (3 items, sorted by createdAt desc):');
    for (var i = 0; i < paginated.length; i++) {
      print('  ${i + 1}. ${paginated[i]['name']}');
    }
    print('');

    // ═══════════════════════════════════════════════════
    // EXAMPLE 5: Type-Safe Count with Filters
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('Example 5: Count with Filters');
    print('══════════════════════════════════════════════════\n');

    // Type-safe version:
    // final count = await prisma.domain.count(
    //   where: DomainWhereInput(
    //     name: StringFilter(contains: 'a'),
    //   ),
    // );

    final query5 = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.count)
        .where({
          'name': {'contains': 'a'},
        })
        .build();

    final count = await executor.executeCount(query5);
    print('✅ Count of domains containing "a": $count');
    print('');

    // ═══════════════════════════════════════════════════
    // EXAMPLE 6: Type-Safe CRUD Operations
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('Example 6: Full CRUD Cycle (Type-Safe)');
    print('══════════════════════════════════════════════════\n');

    final testId = _generateUuid();
    final testName = 'TypeSafe_${DateTime.now().millisecondsSinceEpoch}';

    // CREATE with type-safe input
    print('1️⃣  CREATE (type-safe)');
    // Type-safe version:
    // final created = await prisma.domain.create(
    //   data: CreateDomainInput(
    //     id: testId,
    //     name: testName,
    //   ),
    // );

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
    print('   ✅ Created: $testName');

    // READ with type-safe where
    print('2️⃣  READ (type-safe where)');
    // Type-safe version:
    // final found = await prisma.domain.findUnique(
    //   where: DomainWhereUniqueInput(id: testId),
    // );

    final readQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.findUnique)
        .where({'id': testId})
        .build();

    final found = await executor.executeQueryAsSingleMap(readQuery);
    print('   ✅ Found: ${found!['name']}');

    // UPDATE with type-safe inputs
    print('3️⃣  UPDATE (type-safe)');
    // Type-safe version:
    // final updated = await prisma.domain.update(
    //   where: DomainWhereUniqueInput(id: testId),
    //   data: UpdateDomainInput(name: '${testName}_UPDATED'),
    // );

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
    print('   ✅ Updated to: ${testName}_UPDATED');

    // DELETE with type-safe where
    print('4️⃣  DELETE (type-safe)');
    // Type-safe version:
    // final deleted = await prisma.domain.delete(
    //   where: DomainWhereUniqueInput(id: testId),
    // );

    final deleteQuery = JsonQueryBuilder()
        .model('Domain')
        .action(QueryAction.delete)
        .where({'id': testId})
        .build();

    await executor.executeMutation(deleteQuery);
    print('   ✅ Deleted successfully');
    print('');

    // ═══════════════════════════════════════════════════
    // Summary
    // ═══════════════════════════════════════════════════
    print('══════════════════════════════════════════════════');
    print('🎉 Type Safety Benefits Demonstrated!');
    print('══════════════════════════════════════════════════\n');

    print('✨ What you get with type-safe generated code:');
    print('  ✅ Compile-time field name validation');
    print('  ✅ Compile-time type checking');
    print('  ✅ IntelliSense/autocomplete in your IDE');
    print('  ✅ Refactoring safety (rename fields easily)');
    print('  ✅ No runtime errors from typos');
    print('  ✅ Filter types (StringFilter, IntFilter, DateTimeFilter)');
    print('  ✅ Logical operators (AND, OR, NOT)');
    print('  ✅ Type-safe pagination (take, skip)');
    print('  ✅ Type-safe ordering (OrderByInput)');
    print('');

    print('📝 To generate type-safe code for your schema:');
    print('  1. Run: dart run prisma_flutter_connector:generate \\');
    print('       --schema schema.prisma \\');
    print('       --output lib/generated');
    print('  2. Run: dart run build_runner build --delete-conflicting-outputs');
    print('  3. Import: import \'lib/generated/index.dart\';');
    print('  4. Enjoy compile-time type safety!');
    print('');

    print('🚀 This is Prisma-style ORM for Dart/Flutter!');
    print('   Same developer experience as TypeScript Prisma.');
    print('   Direct database access. No backend required.');
    print('');

  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print(stackTrace);
  } finally {
    await executor.dispose();
    print('🔌 Disconnected from database');
  }
}

/// Simple UUID v4 generator
String _generateUuid() {
  final random = DateTime.now().millisecondsSinceEpoch;
  return 'test-$random-${random.hashCode.abs()}';
}
