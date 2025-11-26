#!/usr/bin/env dart

/// Prisma Flutter Connector Code Generator CLI
///
/// Generates Dart models and API clients from Prisma schema files.
///
/// Usage:
/// ```bash
/// dart run prisma_flutter_connector:generate \
///   --schema prisma/schema.prisma \
///   --output lib/generated/
/// ```
library;

import 'dart:io';
import 'package:args/args.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/client_generator.dart';
import 'package:prisma_flutter_connector/src/generator/filter_types_generator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('schema',
        abbr: 's', mandatory: true, help: 'Path to Prisma schema file')
    ..addOption('output',
        abbr: 'o',
        mandatory: true,
        help: 'Output directory for generated files')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error: $e\n');
    print(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    print('Prisma Flutter Connector Code Generator\n');
    print(parser.usage);
    exit(0);
  }

  final schemaPath = args['schema'] as String;
  final outputPath = args['output'] as String;

  // Read schema file
  final schemaFile = File(schemaPath);
  if (!schemaFile.existsSync()) {
    print('Error: Schema file not found: $schemaPath');
    exit(1);
  }

  print('📖 Reading Prisma schema: $schemaPath');
  final schemaContent = await schemaFile.readAsString();

  // Parse schema
  print('🔍 Parsing Prisma schema...');
  final prismaParser = PrismaParser();
  final schema = prismaParser.parse(schemaContent);

  print('✅ Found ${schema.models.length} models and ${schema.enums.length} enums');

  // Create output directory
  final outputDir = Directory(outputPath);
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Generate models
  print('🏗️  Generating models...');
  final modelGenerator = ModelGenerator(schema);
  final modelFiles = modelGenerator.generateAll();

  final modelsDir = Directory('$outputPath/models');
  if (!modelsDir.existsSync()) {
    modelsDir.createSync(recursive: true);
  }

  for (final entry in modelFiles.entries) {
    final file = File('${modelsDir.path}/${entry.key}');
    await file.writeAsString(entry.value);
    print('  ✓ Generated ${entry.key}');
  }

  // Generate Delegates (adapter-based)
  print('🔌 Generating model delegates...');
  final delegateGenerator = DelegateGenerator(schema);
  final delegateFiles = delegateGenerator.generateAll();

  final delegatesDir = Directory('$outputPath/delegates');
  if (!delegatesDir.existsSync()) {
    delegatesDir.createSync(recursive: true);
  }

  for (final entry in delegateFiles.entries) {
    final file = File('${delegatesDir.path}/${entry.key}');
    await file.writeAsString(entry.value);
    print('  ✓ Generated ${entry.key}');
  }

  // Generate filter types
  print('🔍 Generating filter types...');
  final filterTypesGenerator = FilterTypesGenerator(schema);
  final filterTypesCode = filterTypesGenerator.generate();
  final filterTypesFile = File('$outputPath/filters.dart');
  await filterTypesFile.writeAsString(filterTypesCode);
  print('  ✓ Generated filters.dart');

  // Generate main client file (adapter-based)
  print('🎯 Generating PrismaClient...');
  final clientGenerator = ClientGenerator(schema);
  final clientCode = clientGenerator.generate();
  final clientFile = File('$outputPath/prisma_client.dart');
  await clientFile.writeAsString(clientCode);
  print('  ✓ Generated prisma_client.dart');

  // Generate barrel export file
  print('📦 Generating barrel exports...');
  final barrelExportCode = _generateBarrelExport(schema);
  final barrelFile = File('$outputPath/index.dart');
  await barrelFile.writeAsString(barrelExportCode);
  print('  ✓ Generated index.dart');

  print('\n✨ Code generation complete!');
  print('\n📝 Next steps:');
  print('  1. Run: dart run build_runner build --delete-conflicting-outputs');
  print('  2. Import the generated client:');
  print('     import \'package:your_app/generated/index.dart\';');
  print('  3. Create a database adapter:');
  print('     final adapter = PostgresAdapter(connection);');
  print('     // or SupabaseAdapter, SQLiteAdapter, etc.');
  print('  4. Use the type-safe client:');
  print('     final prisma = PrismaClient(adapter: adapter);');
  print('     final users = await prisma.user.findMany(');
  print('       where: UserWhereInput(email: StringFilter(contains: \'@example.com\')),');
  print('       orderBy: UserOrderByInput(createdAt: SortOrder.desc),');
  print('     );');
}

/// Generate barrel export file for easy imports
String _generateBarrelExport(PrismaSchema schema) {
  final buffer = StringBuffer();

  buffer.writeln('/// Generated barrel export file');
  buffer.writeln('/// Import this file to access all generated types');
  buffer.writeln('library;');
  buffer.writeln();

  // Export the main client
  buffer.writeln("export 'prisma_client.dart';");
  buffer.writeln();

  // Export filters
  buffer.writeln("export 'filters.dart';");
  buffer.writeln();

  // Export all models
  buffer.writeln('// Models');
  for (final model in schema.models) {
    final snakeName = _toSnakeCase(model.name);
    buffer.writeln("export 'models/$snakeName.dart';");
  }
  buffer.writeln();

  // Export all enums
  buffer.writeln('// Enums');
  for (final enumDef in schema.enums) {
    final snakeName = _toSnakeCase(enumDef.name);
    buffer.writeln("export 'models/$snakeName.dart';");
  }
  buffer.writeln();

  // Export all delegates
  buffer.writeln('// Delegates');
  for (final model in schema.models) {
    final snakeName = _toSnakeCase(model.name);
    buffer.writeln("export 'delegates/${snakeName}_delegate.dart';");
  }

  return buffer.toString();
}

/// Convert PascalCase to snake_case
String _toSnakeCase(String input) {
  return input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  ).replaceFirst(RegExp(r'^_'), '');
}
