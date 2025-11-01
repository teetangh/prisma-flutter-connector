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

import 'dart:io';
import 'package:args/args.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/api_generator.dart';

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

  // Generate APIs
  print('🔌 Generating API clients...');
  final apiGenerator = APIGenerator(schema);
  final apiFiles = apiGenerator.generateAll();

  final apiDir = Directory('$outputPath/api');
  if (!apiDir.existsSync()) {
    apiDir.createSync(recursive: true);
  }

  for (final entry in apiFiles.entries) {
    final file = File('${apiDir.path}/${entry.key}');
    await file.writeAsString(entry.value);
    print('  ✓ Generated ${entry.key}');
  }

  // Generate main client file
  print('🎯 Generating PrismaClient...');
  final clientCode = _generatePrismaClient(schema);
  final clientFile = File('$outputPath/prisma_client.dart');
  await clientFile.writeAsString(clientCode);
  print('  ✓ Generated prisma_client.dart');

  print('\n✨ Code generation complete!');
  print('\n📝 Next steps:');
  print('  1. Run: dart run build_runner build --delete-conflicting-outputs');
  print('  2. Import: import \'package:your_app/generated/prisma_client.dart\';');
  print('  3. Use: final client = PrismaClient(config: ...);');
}

String _generatePrismaClient(PrismaSchema schema) {
  final buffer = StringBuffer();

  // Imports
  buffer.writeln("import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';");
  buffer.writeln("import 'package:graphql_flutter/graphql_flutter.dart';");

  for (final model in schema.models) {
    final snakeName = _toSnakeCase(model.name);
    buffer.writeln("import 'api/${snakeName}_api.dart';");
  }

  buffer.writeln();

  // PrismaClient class
  buffer.writeln('/// Generated Prisma client for your schema');
  buffer.writeln('class PrismaClient extends BasePrismaClient {');
  buffer.writeln('  PrismaClient({required super.config});');
  buffer.writeln();

  // Generate API getters
  for (final model in schema.models) {
    final camelName = _toLowerCamelCase(model.name);
    buffer.writeln('  late final ${model.name}API $camelName = ${model.name}API(graphQLClient, config);');
  }

  buffer.writeln('}');

  return buffer.toString();
}

String _toSnakeCase(String input) {
  return input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  ).substring(1);
}

String _toLowerCamelCase(String input) {
  if (input.isEmpty) return input;
  return input[0].toLowerCase() + input.substring(1);
}
