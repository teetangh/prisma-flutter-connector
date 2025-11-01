/// Prisma Flutter Connector
///
/// A generic, type-safe Flutter connector for Prisma backends using GraphQL.
/// Works with ANY Prisma schema through code generation.
///
/// ## Usage
///
/// 1. Generate Dart code from your Prisma schema:
/// ```bash
/// flutter pub run prisma_flutter_connector:generate \
///   --schema prisma/schema.prisma \
///   --output lib/generated/
/// ```
///
/// 2. Use the generated client:
/// ```dart
/// import 'package:your_app/generated/prisma_client.dart';
///
/// final client = PrismaClient(
///   config: PrismaConfig(
///     graphqlEndpoint: 'https://api.example.com/graphql',
///   ),
/// );
///
/// final data = await client.yourModel.list();
/// ```
library prisma_flutter_connector;

// Core client exports
export 'src/client/prisma_config.dart';
export 'src/client/base_client.dart';
export 'src/client/base_api.dart';

// Exception exports
export 'src/exceptions/prisma_exception.dart';
export 'src/exceptions/network_exception.dart' show NetworkException;
export 'src/exceptions/not_found_exception.dart';
export 'src/exceptions/validation_exception.dart';

// Generator exports (for CLI usage)
export 'src/generator/prisma_parser.dart';
export 'src/generator/model_generator.dart';
export 'src/generator/api_generator.dart';
export 'src/generator/filter_generator.dart';
