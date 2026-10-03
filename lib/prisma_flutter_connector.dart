/// Prisma Flutter Connector
///
/// A type-safe, pure-Dart Prisma ORM connector and code generator for Dart and
/// Flutter applications. Connects directly to PostgreSQL, Supabase, and SQLite
/// databases without requiring a GraphQL backend.
///
/// ## Usage
///
/// 1. Generate Dart code from your Prisma schema:
/// ```bash
/// dart run prisma_flutter_connector:generate \
///   --schema prisma/schema.prisma \
///   --output lib/generated/
/// ```
///
/// 2. Use the generated client with a database adapter:
/// ```dart
/// import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';
/// import 'package:your_app/generated/index.dart';
///
/// final adapter = await SupabaseAdapter.fromConnectionString(databaseUrl);
/// final prisma = PrismaClient(adapter: adapter);
/// final users = await prisma.user.findMany();
/// ```
library;

// Runtime exports (adapters, query compiler, executor, schema registry, errors, logging)
export 'runtime.dart';

// Generator exports (for CLI and programmatic codegen usage)
export 'src/generator/prisma_parser.dart';
export 'src/generator/cb_model_generator.dart';
export 'src/generator/cb_delegate_generator.dart';
export 'src/generator/cb_filter_types_generator.dart';
export 'src/generator/cb_client_generator.dart';
export 'src/generator/cb_schema_registry_generator.dart';
export 'src/generator/string_utils.dart';
