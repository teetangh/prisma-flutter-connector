/// Example: Using the Generated Prisma Client with Supabase
///
/// This demonstrates the complete Prisma-style ORM experience in Dart/Flutter.
/// No GraphQL backend required - direct database access!
///
/// NOTE: This example requires running build_runner first to generate Freezed models:
///   flutter pub run build_runner build --delete-conflicting-outputs
///
/// For a working example that doesn't require code generation, see:
///   simple_example.dart

import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/runtime.dart';
import 'package:supabase_example/generated/prisma_client.dart';

void main() async {
  print('🎯 Prisma Flutter Connector - Complete Example\n');
  print('Using generated client with Supabase database');
  print('═══════════════════════════════════════════════════\n');

  // ============================================================================
  // STEP 1: Load environment variables and connect to Supabase
  // ============================================================================
  print('📡 Loading environment variables...');

  final env = DotEnv()..load();

  final host = env['SUPABASE_HOST'];
  final port = int.tryParse(env['SUPABASE_PORT'] ?? '6543') ?? 6543;
  final database = env['SUPABASE_DATABASE'] ?? 'postgres';
  final username = env['SUPABASE_USERNAME'];
  final password = env['SUPABASE_PASSWORD'];

  if (host == null || username == null || password == null) {
    print('❌ Error: Missing environment variables!');
    print('Please create a .env file with required Supabase credentials.');
    exit(1);
  }

  print('📡 Connecting to Supabase...');

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

  // ============================================================================
  // STEP 2: Create Adapter
  // ============================================================================
  print('🔌 Creating Supabase adapter...');

  final adapter = SupabaseAdapter(connection);

  print('✅ Adapter created!\n');

  // ============================================================================
  // STEP 3: Initialize PrismaClient
  // ============================================================================
  print('🎯 Initializing PrismaClient (generated from schema)...');

  final prisma = PrismaClient(adapter: adapter);

  print('✅ PrismaClient ready!\n');

  // ============================================================================
  // STEP 4: Use the Client - Just Like Prisma in TypeScript!
  // ============================================================================

  try {
    // Example 1: Find Many Domains
    print('═══════════════════════════════════════════════════');
    print('Example 1: prisma.domain.findMany()');
    print('═══════════════════════════════════════════════════\n');

    final domains = await prisma.domain.findMany(
      orderBy: {'createdAt': 'desc'},
      take: 5,
    );

    print('Found ${domains.length} domains:');
    for (final domain in domains) {
      print('  • ${domain.name} (ID: ${domain.id})');
    }
    print('');

    // Example 2: Find Unique Domain
    print('═══════════════════════════════════════════════════');
    print('Example 2: prisma.domain.findUnique()');
    print('═══════════════════════════════════════════════════\n');

    if (domains.isNotEmpty) {
      final firstDomain = await prisma.domain.findUnique(
        where: {'id': domains.first.id},
      );

      if (firstDomain != null) {
        print('✅ Found domain: ${firstDomain.name}');
        print('   Created: ${firstDomain.createdAt}');
        print('');
      }
    }

    // Example 3: Count
    print('═══════════════════════════════════════════════════');
    print('Example 3: prisma.domain.count()');
    print('═══════════════════════════════════════════════════\n');

    final totalDomains = await prisma.domain.count();
    print('Total domains in database: $totalDomains');
    print('');

    // Example 4: Find with Filter
    print('═══════════════════════════════════════════════════');
    print('Example 4: prisma.newsletter.findMany() with filter');
    print('═══════════════════════════════════════════════════\n');

    final newsletters = await prisma.newsletter.findMany(
      where: {
        'email': Where.contains('@'),  // All emails
      },
      take: 3,
    );

    print('Found ${newsletters.length} newsletter subscribers:');
    for (final newsletter in newsletters) {
      print('  • ${newsletter.email}');
    }
    print('');

    // Example 5: Transaction (Create + Update)
    print('═══════════════════════════════════════════════════');
    print(r'Example 5: prisma.$transaction()');
    print('═══════════════════════════════════════════════════\n');

    final testDomainName = 'ORM_GENERATED_TEST_${DateTime.now().millisecondsSinceEpoch}';

    // ignore: no_leading_underscores_for_local_identifiers
    await prisma.$transaction((tx) async {
      // Create domain
      final created = await tx.domain.create(data: {
        'id': _generateUuid(),
        'name': testDomainName,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Created domain: ${created.name}');

      // Update it
      final updated = await tx.domain.update(
        where: {'id': created.id},
        data: {
          'name': '${testDomainName}_UPDATED',
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      print('✅ Updated domain: ${updated.name}');

      // Delete it (cleanup)
      await tx.domain.delete(where: {'id': created.id});
      print('✅ Deleted test domain (cleanup)');
    });

    print('✅ Transaction completed successfully!');
    print('');

    // Summary
    print('═══════════════════════════════════════════════════');
    print('🎉 ALL EXAMPLES COMPLETE!');
    print('═══════════════════════════════════════════════════\n');

    print('✨ What we just did:');
    print('  ✅ Connected to Supabase with adapter');
    print('  ✅ Used generated PrismaClient');
    print('  ✅ Performed CRUD operations');
    print('  ✅ Used filters and ordering');
    print('  ✅ Executed transactions');
    print('  ✅ NO GraphQL backend required!');
    print('');

    print('🚀 This is Prisma-style ORM in Dart/Flutter!');
    print('');

    print('📝 Generated client features:');
    print('  • ${prisma.domain.runtimeType} - Type-safe domain operations');
    print('  • ${prisma.newsletter.runtimeType} - Type-safe newsletter operations');
    print('  • ${prisma.user.runtimeType} - Type-safe user operations');
    print('  • + 34 more model delegates!');
    print('');

  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print(stackTrace);
  } finally {
    // Cleanup
    await prisma.$disconnect();
    print('🔌 Disconnected from database');
  }
}

/// Simple UUID v4 generator
String _generateUuid() {
  final random = DateTime.now().millisecondsSinceEpoch;
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
    RegExp(r'[xy]'),
    (match) {
      final r = (random + (random * 16).toInt()) % 16;
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    },
  );
}
