/// Client generator using code_builder for type-safe AST generation.
// ignore_for_file: prefer_const_constructors
library;

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates the main PrismaClient class using code_builder.
class CbClientGenerator {
  final PrismaSchema schema;
  final bool serverMode;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  CbClientGenerator(this.schema, {this.serverMode = false});

  String generate() {
    final runtimeImport = serverMode ? 'runtime_server.dart' : 'runtime.dart';

    final directives = <Directive>[
      Directive.import('package:prisma_flutter_connector/$runtimeImport'),
    ];

    // Import delegates and models
    for (final model in schema.models) {
      final sn = toSnakeCase(model.name);
      directives.add(Directive.import('delegates/${sn}_delegate.dart'));
    }
    for (final model in schema.models) {
      final sn = toSnakeCase(model.name);
      directives.add(Directive.import('models/$sn.dart'));
    }

    final library = Library((b) => b
      ..comments.addAll([
        '/// Generated Prisma Client for Dart/Flutter',
        '///',
        '/// This client provides type-safe database access using adapters.',
        '/// No GraphQL backend required — connects directly to your database!',
      ])
      ..directives.addAll(directives)
      ..body.addAll([
        _buildPrismaClientClass(),
        _buildWhereHelperClass(),
      ]));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return _formatter.format('${library.accept(emitter)}');
  }

  Class _buildPrismaClientClass() {
    final delegateFields = <Field>[];
    final constructorInits = <Code>[];

    for (final model in schema.models) {
      final camelName = toLowerCamelCase(model.name);
      delegateFields.add(Field((f) => f
        ..name = camelName
        ..docs.add('/// Delegate for ${model.name} operations')
        ..type = refer('late final ${model.name}Delegate')));
    }

    for (final model in schema.models) {
      final camelName = toLowerCamelCase(model.name);
      constructorInits
          .add(Code('$camelName = ${model.name}Delegate(_executor);'));
    }

    return Class((b) => b
      ..name = 'PrismaClient'
      ..docs.addAll([
        '/// Main Prisma client for database operations',
        '///',
        '/// Provides access to all models through type-safe delegate classes.',
      ])
      ..fields.addAll([
        Field((f) => f
          ..name = 'adapter'
          ..docs.add(
              '/// The database adapter (PostgreSQL, Supabase, SQLite, etc.)')
          ..type = refer('SqlDriverAdapter')
          ..modifier = FieldModifier.final$),
        Field((f) => f
          ..name = '_executor'
          ..docs.add('/// The query executor')
          ..type = refer('BaseExecutor')
          ..modifier = FieldModifier.final$),
        ...delegateFields,
      ])
      ..constructors.addAll([
        // Main constructor
        Constructor((c) => c
          ..docs.addAll([
            '/// Create a new PrismaClient with a database adapter',
          ])
          ..optionalParameters.add(Parameter((p) => p
            ..name = 'adapter'
            ..named = true
            ..required = true
            ..toThis = true))
          ..initializers
              .add(Code('_executor = QueryExecutor(adapter: adapter)'))
          ..body = Block.of(constructorInits)),
        // Transaction constructor
        Constructor((c) => c
          ..name = '_transaction'
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'executor'
            ..type = refer('BaseExecutor')))
          ..initializers.addAll([
            Code('adapter = executor.adapter'),
            Code('_executor = executor'),
          ])
          ..body = Block.of(constructorInits)),
      ])
      ..methods.addAll([
        // $transaction method
        Method((m) => m
          ..name = r'$transaction'
          ..docs.addAll([
            '/// Execute multiple operations in a transaction',
            '///',
            '/// All operations succeed or all rollback on error.',
          ])
          ..modifier = MethodModifier.async
          ..types.add(refer('T'))
          ..returns = refer('Future<T>')
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'callback'
            ..type = refer('Future<T> Function(PrismaClient)')))
          ..optionalParameters.add(Parameter((p) => p
            ..name = 'isolationLevel'
            ..named = true
            ..type = refer('IsolationLevel?')))
          ..body = Code('''
            final queryExecutor = _executor as QueryExecutor;
            return await queryExecutor.executeInTransaction((txExecutor) async {
              final txClient = PrismaClient._transaction(txExecutor);
              return await callback(txClient);
            }, isolationLevel: isolationLevel);
          ''')),
        // $disconnect method
        Method((m) => m
          ..name = r'$disconnect'
          ..docs.add('/// Close the database connection')
          ..modifier = MethodModifier.async
          ..returns = refer('Future<void>')
          ..body = Code('''
            final queryExecutor = _executor as QueryExecutor;
            await queryExecutor.dispose();
          ''')),
      ]));
  }

  Class _buildWhereHelperClass() {
    final methods = <Method>[
      _staticHelper('equals', 'Equals', 'dynamic', 'FilterOperators.equals'),
      _staticHelper('not', 'Not equals', 'dynamic', 'FilterOperators.not'),
      _staticHelper('in_', 'In list', 'List<dynamic>', 'FilterOperators.in_'),
      _staticHelper(
          'notIn', 'Not in list', 'List<dynamic>', 'FilterOperators.notIn'),
      _staticHelper('lt', 'Less than', 'dynamic', 'FilterOperators.lt'),
      _staticHelper(
          'lte', 'Less than or equal', 'dynamic', 'FilterOperators.lte'),
      _staticHelper('gt', 'Greater than', 'dynamic', 'FilterOperators.gt'),
      _staticHelper(
          'gte', 'Greater than or equal', 'dynamic', 'FilterOperators.gte'),
      _staticHelper('contains', 'Contains (string)', 'String',
          'FilterOperators.contains'),
      _staticHelper(
          'startsWith', 'Starts with', 'String', 'FilterOperators.startsWith'),
      _staticHelper(
          'endsWith', 'Ends with', 'String', 'FilterOperators.endsWith'),
      Method((m) => m
        ..name = 'and'
        ..static = true
        ..docs.add('/// AND conditions')
        ..returns = refer('Map<String, dynamic>')
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'conditions'
          ..type = refer('List<Map<String, dynamic>>')))
        ..body = Code('return FilterOperators.and(conditions);')),
      Method((m) => m
        ..name = 'or'
        ..static = true
        ..docs.add('/// OR conditions')
        ..returns = refer('Map<String, dynamic>')
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'conditions'
          ..type = refer('List<Map<String, dynamic>>')))
        ..body = Code('return FilterOperators.or(conditions);')),
      Method((m) => m
        ..name = 'none'
        ..static = true
        ..docs.add('/// NOT condition')
        ..returns = refer('Map<String, dynamic>')
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'condition'
          ..type = refer('Map<String, dynamic>')))
        ..body = Code('return FilterOperators.none(condition);')),
    ];

    return Class((b) => b
      ..name = 'Where'
      ..docs.addAll([
        '/// Helper class for filter operators',
        '///',
        '/// Use these when building WHERE clauses.',
      ])
      ..methods.addAll(methods));
  }

  Method _staticHelper(
      String name, String doc, String paramType, String delegateTo) {
    return Method((m) => m
      ..name = name
      ..static = true
      ..docs.add('/// $doc')
      ..returns = refer('Map<String, dynamic>')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'value'
        ..type = refer(paramType)))
      ..body = Code('return $delegateTo(value);'));
  }
}
