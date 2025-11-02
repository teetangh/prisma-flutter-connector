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

  // Generate main client file (adapter-based)
  print('🎯 Generating PrismaClient...');
  final clientGenerator = ClientGenerator(schema);
  final clientCode = clientGenerator.generate();
  final clientFile = File('$outputPath/prisma_client.dart');
  await clientFile.writeAsString(clientCode);
  print('  ✓ Generated prisma_client.dart');

  print('\n✨ Code generation complete!');
  print('\n📝 Next steps:');
  print('  1. Run: dart run build_runner build --delete-conflicting-outputs');
  print('  2. Import the generated client:');
  print('     import \'package:your_app/generated/prisma_client.dart\';');
  print('  3. Create a database adapter:');
  print('     final adapter = PostgresAdapter(connection);');
  print('     // or SupabaseAdapter, SQLiteAdapter, etc.');
  print('  4. Use the client:');
  print('     final prisma = PrismaClient(adapter: adapter);');
  print('     final users = await prisma.user.findMany();');
}
