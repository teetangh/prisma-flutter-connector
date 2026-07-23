/// Delegate generator using code_builder for type-safe AST generation.
///
/// Replaces StringBuffer-based delegate_generator.dart with code_builder
/// for structured class/method generation and dart_style auto-formatting.
// ignore_for_file: prefer_const_constructors
library;

import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/generator/string_utils.dart';

/// Generates delegate classes using code_builder AST.
class CbDelegateGenerator {
  final PrismaSchema schema;
  final bool serverMode;
  late final _formatter =
      DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);

  CbDelegateGenerator(this.schema, {this.serverMode = false});

  /// Generate delegate class for a single model.
  String generateDelegate(PrismaModel model) {
    final modelName = model.name;
    final tableName = model.tableName;
    final runtimeImport = serverMode ? 'runtime_server.dart' : 'runtime.dart';

    final library = Library((b) => b
      ..directives.addAll([
        Directive.import('package:prisma_flutter_connector/$runtimeImport'),
        Directive.import('../models/${toSnakeCase(modelName)}.dart'),
      ])
      ..body.add(_buildDelegateClass(modelName, tableName,
          hasUniqueFields: model.fields
                  .any((f) => (f.isId || f.isUnique) && !f.isRelation) ||
              model.compositeUniques.isNotEmpty,
          relationFields: model.fields
              .where((f) => f.isRelation)
              .map((f) => f.name)
              .toList())));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return _formatter.format('${library.accept(emitter)}');
  }

  Class _buildDelegateClass(String modelName, String tableName,
      {required bool hasUniqueFields, required List<String> relationFields}) {
    final relLiteral = relationFields.isEmpty
        ? 'const <String>{}'
        : '{${relationFields.map((n) => "'$n'").join(', ')}}';
    return Class((b) => b
      ..name = '${modelName}Delegate'
      ..docs.addAll([
        '/// Delegate for $modelName operations',
        '/// Provides type-safe CRUD operations using database adapters',
      ])
      ..fields.add(Field((f) => f
        ..name = '_executor'
        ..type = refer('BaseExecutor')
        ..modifier = FieldModifier.final$))
      ..constructors.add(Constructor((c) => c
        ..requiredParameters.add(Parameter((p) => p
          ..name = '_executor'
          ..toThis = true))))
      ..methods.addAll([
        // Models without any unique scalar field (e.g. composite @@id only)
        // have no WhereUniqueInput, so unique-keyed methods are omitted
        if (hasUniqueFields) _findUnique(modelName, tableName),
        if (hasUniqueFields) _findUniqueOrThrow(modelName),
        _findFirst(modelName, tableName),
        _findFirstOrThrow(modelName),
        _findMany(modelName, tableName, hasUniqueFields),
        _findManyProjected(modelName, tableName, hasUniqueFields),
        _findFirstProjected(modelName, tableName),
        _findManyRaw(modelName, tableName),
        _findFirstRaw(modelName, tableName),
        _create(modelName, tableName, relLiteral),
        _createMany(modelName, tableName),
        _createManyAndReturn(modelName, tableName),
        if (hasUniqueFields) _update(modelName, tableName, relLiteral),
        if (hasUniqueFields) _upsert(modelName, tableName),
        _updateMany(modelName, tableName),
        if (hasUniqueFields) _delete(modelName, tableName),
        _deleteMany(modelName, tableName),
        _count(modelName, tableName),
        _groupBy(modelName, tableName),
        _aggregate(modelName, tableName),
        _normalizeForJson(),
        if (hasUniqueFields) _whereUniqueToJson(modelName),
        _whereToJson(modelName),
        _orderByToJson(modelName),
      ]));
  }

  Method _findUnique(String m, String t) => Method((b) => b
    ..name = 'findUnique'
    ..docs.add('/// Find a single $m by unique field(s)')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m?>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..required = true
        ..type = refer('${m}WhereUniqueInput')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('${m}Include?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findUnique)
          .where(_whereUniqueToJson(where));

      if (include != null) queryBuilder.include(include.toJson());

      final result = await _executor.executeQueryAsSingleMap(queryBuilder.build());
      return result != null ? $m.fromJson(_normalizeForJson(result)) : null;
    '''));

  Method _findUniqueOrThrow(String m) => Method((b) => b
    ..name = 'findUniqueOrThrow'
    ..docs.add('/// Find a single $m or throw if not found')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'where'
      ..named = true
      ..required = true
      ..type = refer('${m}WhereUniqueInput')))
    ..body = Code('''
      final result = await findUnique(where: where);
      if (result == null) {
        throw Exception('$m not found');
      }
      return result;
    '''));

  Method _findFirst(String m, String t) => Method((b) => b
    ..name = 'findFirst'
    ..docs.add('/// Find the first $m matching criteria')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m?>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('${m}OrderByInput?')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('${m}Include?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findFirst);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy != null) queryBuilder.orderBy(_orderByToJson(orderBy));
      if (include != null) queryBuilder.include(include.toJson());

      final result = await _executor.executeQueryAsSingleMap(queryBuilder.build());
      return result != null ? $m.fromJson(_normalizeForJson(result)) : null;
    '''));

  Method _findFirstOrThrow(String m) => Method((b) => b
    ..name = 'findFirstOrThrow'
    ..docs.add('/// Find the first $m matching criteria, or throw if none')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('${m}OrderByInput?')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('${m}Include?')),
    ])
    ..body = Code('''
      final result =
          await findFirst(where: where, orderBy: orderBy, include: include);
      if (result == null) {
        throw Exception('$m not found');
      }
      return result;
    '''));

  Method _findMany(String m, String t, bool hasUniqueFields) => Method((b) => b
    ..name = 'findMany'
    ..docs.add('/// Find multiple ${m}s with optional filters')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<List<$m>>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('dynamic')),
      Parameter((p) => p
        ..name = 'take'
        ..named = true
        ..type = refer('int?')),
      Parameter((p) => p
        ..name = 'skip'
        ..named = true
        ..type = refer('int?')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('${m}Include?')),
      Parameter((p) => p
        ..name = 'includeRequired'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
      Parameter((p) => p
        ..name = 'selectFields'
        ..named = true
        ..type = refer('List<String>?')),
      Parameter((p) => p
        ..name = 'distinct'
        ..named = true
        ..type = refer('bool?')),
      Parameter((p) => p
        ..name = 'distinctFields'
        ..named = true
        ..type = refer('List<String>?')),
      if (hasUniqueFields)
        Parameter((p) => p
          ..name = 'cursor'
          ..named = true
          ..type = refer('${m}WhereUniqueInput?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findMany);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy is Map<String, dynamic>) queryBuilder.orderBy(orderBy);
      if (orderBy is List) queryBuilder.orderBy(orderBy);
      if (orderBy is ${m}OrderByInput) queryBuilder.orderBy(_orderByToJson(orderBy));
      if (take != null) queryBuilder.take(take);
      if (skip != null) queryBuilder.skip(skip);
      ${hasUniqueFields ? 'if (cursor != null) queryBuilder.cursor(_whereUniqueToJson(cursor));' : ''}
      if (include != null) queryBuilder.include(include.toJson());
      if (includeRequired != null) queryBuilder.includeRequired(includeRequired);
      if (selectFields != null) queryBuilder.selectFields(selectFields);
      if (distinct == true) queryBuilder.distinct(distinctFields);

      final results = await _executor.executeQueryAsMaps(queryBuilder.build());
      return results.map((json) => $m.fromJson(_normalizeForJson(json))).toList();
    '''));

  /// Fully-typed projection finder: typed where/include/select/distinct with
  /// Map rows out (projected/computed rows never hydrate typed models).
  Method _findManyProjected(String m, String t, bool hasUniqueFields) =>
      Method((b) => b
        ..name = 'findManyProjected'
        ..docs.addAll([
          '/// Find multiple ${m}s as projected rows (maps).',
          '///',
          '/// Typed inputs; `Map` rows out — use for scalar projection',
          '/// (`select:`/`distinctOn:`), computed correlated subqueries, and',
          '/// include-with-select. Rows may be partial, so they are not',
          '/// hydrated into typed models.',
        ])
        ..modifier = MethodModifier.async
        ..returns = refer('Future<List<Map<String, dynamic>>>')
        ..optionalParameters.addAll([
          Parameter((p) => p
            ..name = 'where'
            ..named = true
            ..type = refer('${m}WhereInput?')),
          Parameter((p) => p
            ..name = 'orderBy'
            ..named = true
            ..type = refer('dynamic')),
          Parameter((p) => p
            ..name = 'take'
            ..named = true
            ..type = refer('int?')),
          Parameter((p) => p
            ..name = 'skip'
            ..named = true
            ..type = refer('int?')),
          if (hasUniqueFields)
            Parameter((p) => p
              ..name = 'cursor'
              ..named = true
              ..type = refer('${m}WhereUniqueInput?')),
          Parameter((p) => p
            ..name = 'include'
            ..named = true
            ..type = refer('${m}Include?')),
          Parameter((p) => p
            ..name = 'select'
            ..named = true
            ..type = refer('List<${m}ScalarField>?')),
          Parameter((p) => p
            ..name = 'computed'
            ..named = true
            ..type = refer('Map<String, ComputedField>?')),
          Parameter((p) => p
            ..name = 'distinct'
            ..named = true
            ..type = refer('bool?')),
          Parameter((p) => p
            ..name = 'distinctOn'
            ..named = true
            ..type = refer('List<${m}ScalarField>?')),
        ])
        ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findMany);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy is Map<String, dynamic>) queryBuilder.orderBy(orderBy);
      if (orderBy is List) queryBuilder.orderBy(orderBy);
      if (orderBy is ${m}OrderByInput) queryBuilder.orderBy(_orderByToJson(orderBy));
      if (take != null) queryBuilder.take(take);
      if (skip != null) queryBuilder.skip(skip);
      ${hasUniqueFields ? 'if (cursor != null) queryBuilder.cursor(_whereUniqueToJson(cursor));' : ''}
      if (include != null) queryBuilder.include(include.toJson());
      if (select != null && select.isNotEmpty) {
        queryBuilder.selectFields([for (final f in select) f.fieldName]);
      }
      if (computed != null) queryBuilder.computed(computed);
      if (distinct == true || (distinctOn != null && distinctOn.isNotEmpty)) {
        queryBuilder.distinct(
          distinctOn == null || distinctOn.isEmpty
              ? null
              : [for (final f in distinctOn) f.fieldName],
        );
      }

      return await _executor.executeQueryAsMaps(queryBuilder.build());
    '''));

  /// findFirst variant of [_findManyProjected].
  Method _findFirstProjected(String m, String t) => Method((b) => b
    ..name = 'findFirstProjected'
    ..docs.addAll([
      '/// Find the first $m as a projected row (map). See findManyProjected.',
    ])
    ..modifier = MethodModifier.async
    ..returns = refer('Future<Map<String, dynamic>?>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('dynamic')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('${m}Include?')),
      Parameter((p) => p
        ..name = 'select'
        ..named = true
        ..type = refer('List<${m}ScalarField>?')),
      Parameter((p) => p
        ..name = 'computed'
        ..named = true
        ..type = refer('Map<String, ComputedField>?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findFirst);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy is Map<String, dynamic>) queryBuilder.orderBy(orderBy);
      if (orderBy is List) queryBuilder.orderBy(orderBy);
      if (orderBy is ${m}OrderByInput) queryBuilder.orderBy(_orderByToJson(orderBy));
      if (include != null) queryBuilder.include(include.toJson());
      if (select != null && select.isNotEmpty) {
        queryBuilder.selectFields([for (final f in select) f.fieldName]);
      }
      if (computed != null) queryBuilder.computed(computed);

      return await _executor.executeQueryAsSingleMap(queryBuilder.build());
    '''));

  Method _findManyRaw(String m, String t) => Method((b) => b
    ..name = 'findManyRaw'
    ..annotations.add(CodeExpression(
        Code("Deprecated('Use findManyProjected (typed inputs) instead; "
            'findManyRaw will be removed in 0.9.0'
            "')")))
    ..docs
        .add('/// Find multiple ${m}s as raw maps (use with include/computed)')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<List<Map<String, dynamic>>>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('dynamic')),
      Parameter((p) => p
        ..name = 'take'
        ..named = true
        ..type = refer('int?')),
      Parameter((p) => p
        ..name = 'skip'
        ..named = true
        ..type = refer('int?')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
      Parameter((p) => p
        ..name = 'includeRequired'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
      Parameter((p) => p
        ..name = 'selectFields'
        ..named = true
        ..type = refer('List<String>?')),
      Parameter((p) => p
        ..name = 'computed'
        ..named = true
        ..type = refer('Map<String, ComputedField>?')),
      Parameter((p) => p
        ..name = 'distinct'
        ..named = true
        ..type = refer('bool?')),
      Parameter((p) => p
        ..name = 'distinctFields'
        ..named = true
        ..type = refer('List<String>?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findMany);

      if (where != null) queryBuilder.where(where);
      if (orderBy is Map<String, dynamic>) queryBuilder.orderBy(orderBy);
      if (orderBy is List) queryBuilder.orderBy(orderBy);
      if (take != null) queryBuilder.take(take);
      if (skip != null) queryBuilder.skip(skip);
      if (include != null) queryBuilder.include(include);
      if (includeRequired != null) queryBuilder.includeRequired(includeRequired);
      if (selectFields != null) queryBuilder.selectFields(selectFields);
      if (computed != null) queryBuilder.computed(computed);
      if (distinct == true) queryBuilder.distinct(distinctFields);

      return await _executor.executeQueryAsMaps(queryBuilder.build());
    '''));

  Method _findFirstRaw(String m, String t) => Method((b) => b
    ..name = 'findFirstRaw'
    ..annotations.add(CodeExpression(
        Code("Deprecated('Use findFirstProjected (typed inputs) instead; "
            'findFirstRaw will be removed in 0.9.0'
            "')")))
    ..docs.add('/// Find the first $m as a raw map (use with include/computed)')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<Map<String, dynamic>?>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('dynamic')),
      Parameter((p) => p
        ..name = 'include'
        ..named = true
        ..type = refer('Map<String, dynamic>?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findFirst);

      if (where != null) queryBuilder.where(where);
      if (orderBy is Map<String, dynamic>) queryBuilder.orderBy(orderBy);
      if (orderBy is List) queryBuilder.orderBy(orderBy);
      if (include != null) queryBuilder.include(include);

      return await _executor.executeQueryAsSingleMap(queryBuilder.build());
    '''));

  Method _create(String m, String t, String relLiteral) => Method((b) => b
    ..name = 'create'
    ..docs.add('/// Create a new $m')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'data'
      ..named = true
      ..required = true
      ..type = refer('Create${m}Input')))
    ..body = Code('''
      final data0 = data.toJson();
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.create)
          .data(data0)
          .build();

      const relationFields = $relLiteral;
      if (data0.keys.any(relationFields.contains)) {
        final row = await _executor.executeMutationWithRelationsReturning(query);
        if (row == null) {
          throw Exception('Failed to create $m');
        }
        return $m.fromJson(_normalizeForJson(row));
      }

      final result = await _executor.executeQueryAsSingleMap(query);
      if (result == null) {
        throw Exception('Failed to create $m');
      }
      return $m.fromJson(_normalizeForJson(result));
    '''));

  Method _createMany(String m, String t) => Method((b) => b
    ..name = 'createMany'
    ..docs.add('/// Create multiple ${m}s')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<int>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'data'
        ..named = true
        ..required = true
        ..type = refer('List<Create${m}Input>')),
      Parameter((p) => p
        ..name = 'skipDuplicates'
        ..named = true
        ..type = refer('bool?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.createMany)
          .data({'data': data.map((d) => d.toJson()).toList()});
      if (skipDuplicates == true) queryBuilder.skipDuplicates();

      return await _executor.executeMutation(queryBuilder.build());
    '''));

  Method _createManyAndReturn(String m, String t) => Method((b) => b
    ..name = 'createManyAndReturn'
    ..docs.add('/// Create multiple ${m}s and return the created rows')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<List<$m>>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'data'
        ..named = true
        ..required = true
        ..type = refer('List<Create${m}Input>')),
      Parameter((p) => p
        ..name = 'skipDuplicates'
        ..named = true
        ..type = refer('bool?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.createManyAndReturn)
          .data({'data': data.map((d) => d.toJson()).toList()});
      if (skipDuplicates == true) queryBuilder.skipDuplicates();

      final results = await _executor.executeQueryAsMaps(queryBuilder.build());
      return results.map((json) => $m.fromJson(_normalizeForJson(json))).toList();
    '''));

  Method _update(String m, String t, String relLiteral) => Method((b) => b
    ..name = 'update'
    ..docs.add('/// Update a $m')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..required = true
        ..type = refer('${m}WhereUniqueInput')),
      Parameter((p) => p
        ..name = 'data'
        ..named = true
        ..required = true
        ..type = refer('Update${m}Input')),
    ])
    ..body = Code('''
      final data0 = data.toJson();
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.update)
          .where(_whereUniqueToJson(where))
          .data(data0)
          .build();

      const relationFields = $relLiteral;
      if (data0.keys.any(relationFields.contains)) {
        await _executor.executeMutationWithRelationsReturning(query);
      } else {
        await _executor.executeMutation(query);
      }

      // Fetch the updated record
      return await findUniqueOrThrow(where: where);
    '''));

  Method _upsert(String m, String t) => Method((b) => b
    ..name = 'upsert'
    ..docs.add('/// Create a $m, or update it if the unique key already exists')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..required = true
        ..type = refer('${m}WhereUniqueInput')),
      Parameter((p) => p
        ..name = 'create'
        ..named = true
        ..required = true
        ..type = refer('Create${m}Input')),
      Parameter((p) => p
        ..name = 'update'
        ..named = true
        ..required = true
        ..type = refer('Update${m}Input')),
    ])
    ..body = Code('''
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.upsert)
          .where(_whereUniqueToJson(where))
          .data({'create': create.toJson(), 'update': update.toJson()})
          .build();

      final result = await _executor.executeQueryAsSingleMap(query);
      if (result == null) {
        throw Exception('Failed to upsert $m');
      }
      return $m.fromJson(_normalizeForJson(result));
    '''));

  Method _updateMany(String m, String t) => Method((b) => b
    ..name = 'updateMany'
    ..docs.add('/// Update multiple ${m}s')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<int>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..required = true
        ..type = refer('${m}WhereInput')),
      Parameter((p) => p
        ..name = 'data'
        ..named = true
        ..required = true
        ..type = refer('Update${m}Input')),
    ])
    ..body = Code('''
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.updateMany)
          .where(_whereToJson(where))
          .data(data.toJson())
          .build();

      return await _executor.executeMutation(query);
    '''));

  Method _delete(String m, String t) => Method((b) => b
    ..name = 'delete'
    ..docs.add('/// Delete a $m')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'where'
      ..named = true
      ..required = true
      ..type = refer('${m}WhereUniqueInput')))
    ..body = Code('''
      // Fetch before deleting
      final existing = await findUniqueOrThrow(where: where);

      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.delete)
          .where(_whereUniqueToJson(where))
          .build();

      await _executor.executeMutation(query);
      return existing;
    '''));

  Method _deleteMany(String m, String t) => Method((b) => b
    ..name = 'deleteMany'
    ..docs.add('/// Delete multiple ${m}s')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<int>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'where'
      ..named = true
      ..required = true
      ..type = refer('${m}WhereInput')))
    ..body = Code('''
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.deleteMany)
          .where(_whereToJson(where))
          .build();

      return await _executor.executeMutation(query);
    '''));

  Method _count(String m, String t) => Method((b) => b
    ..name = 'count'
    ..docs.add('/// Count ${m}s matching criteria')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<int>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'where'
      ..named = true
      ..type = refer('${m}WhereInput?')))
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.count);

      if (where != null) queryBuilder.where(_whereToJson(where));

      return await _executor.executeCount(queryBuilder.build());
    '''));

  Method _groupBy(String m, String t) => Method((b) => b
    ..name = 'groupBy'
    ..docs.add('/// Group ${m}s by fields with aggregations')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<List<Map<String, dynamic>>>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'by'
        ..named = true
        ..required = true
        ..type = refer('List<String>')),
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'count'
        ..named = true
        ..type = refer('bool?')),
      Parameter((p) => p
        ..name = 'sum'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'avg'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'min'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'max'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'orderBy'
        ..named = true
        ..type = refer('dynamic')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.groupBy)
          .groupByFields(by);

      if (where != null) queryBuilder.where(_whereToJson(where));

      final agg = <String, dynamic>{};
      if (count == true) agg['_count'] = true;
      if (sum != null) agg['_sum'] = sum;
      if (avg != null) agg['_avg'] = avg;
      if (min != null) agg['_min'] = min;
      if (max != null) agg['_max'] = max;
      if (agg.isNotEmpty) queryBuilder.aggregation(agg);

      if (orderBy != null) queryBuilder.orderBy(orderBy);

      return await _executor.executeQueryAsMaps(queryBuilder.build());
    '''));

  Method _aggregate(String m, String t) => Method((b) => b
    ..name = 'aggregate'
    ..docs.add('/// Aggregate over ${m}s (count/sum/avg/min/max)')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<Map<String, dynamic>>')
    ..optionalParameters.addAll([
      Parameter((p) => p
        ..name = 'where'
        ..named = true
        ..type = refer('${m}WhereInput?')),
      Parameter((p) => p
        ..name = 'count'
        ..named = true
        ..type = refer('bool?')),
      Parameter((p) => p
        ..name = 'sum'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'avg'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'min'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'max'
        ..named = true
        ..type = refer('Map<String, bool>?')),
      Parameter((p) => p
        ..name = 'countFiltered'
        ..named = true
        ..type = refer('List<Map<String, dynamic>>?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.aggregate);

      if (where != null) queryBuilder.where(_whereToJson(where));

      final agg = <String, dynamic>{};
      if (count == true) agg['_count'] = true;
      if (sum != null) agg['_sum'] = sum;
      if (avg != null) agg['_avg'] = avg;
      if (min != null) agg['_min'] = min;
      if (max != null) agg['_max'] = max;
      if (countFiltered != null) agg['_countFiltered'] = countFiltered;
      queryBuilder.aggregation(agg);

      final result =
          await _executor.executeQueryAsSingleMap(queryBuilder.build());
      return result ?? <String, dynamic>{};
    '''));

  Method _normalizeForJson() => Method((b) => b
    ..name = '_normalizeForJson'
    ..docs.add(
        '/// Normalize map values for Freezed fromJson (DateTime -> String, etc.)')
    ..returns = refer('Map<String, dynamic>')
    ..requiredParameters.add(Parameter((p) => p
      ..name = 'map'
      ..type = refer('Map<String, dynamic>')))
    ..body = Code('''
      return map.map((key, value) {
        if (value is DateTime) return MapEntry(key, value.toIso8601String());
        if (value is Map<String, dynamic>) return MapEntry(key, _normalizeForJson(value));
        if (value is List) {
          return MapEntry(key, value.map((e) {
            if (e is Map<String, dynamic>) return _normalizeForJson(e);
            if (e is DateTime) return e.toIso8601String();
            return e;
          }).toList());
        }
        return MapEntry(key, value);
      });
    '''));

  Method _whereUniqueToJson(String m) => Method((b) => b
    ..name = '_whereUniqueToJson'
    ..docs.add('/// Convert WhereUniqueInput to JSON for JsonQueryBuilder')
    ..returns = refer('Map<String, dynamic>')
    ..requiredParameters.add(Parameter((p) => p
      ..name = 'where'
      ..type = refer('${m}WhereUniqueInput')))
    ..body = Code(
        "return where.toJson()..removeWhere((key, value) => value == null);"));

  Method _whereToJson(String m) => Method((b) => b
    ..name = '_whereToJson'
    ..docs.add('/// Convert WhereInput to JSON for JsonQueryBuilder')
    ..returns = refer('Map<String, dynamic>')
    ..requiredParameters.add(Parameter((p) => p
      ..name = 'where'
      ..type = refer('${m}WhereInput')))
    ..body = Code('''
      final json = where.toJson();
      final result = <String, dynamic>{};

      for (final entry in json.entries) {
        if (entry.value == null) continue;

        if (entry.key == 'AND' || entry.key == 'OR') {
          final list = entry.value as List?;
          if (list != null && list.isNotEmpty) {
            result[entry.key] = list.map((item) {
              if (item is Map) return item;
              return (item as ${m}WhereInput).toJson();
            }).toList();
          }
        } else if (entry.key == 'NOT') {
          final not = entry.value;
          if (not is Map) {
            result[entry.key] = not;
          } else if (not is ${m}WhereInput) {
            result[entry.key] = not.toJson();
          }
        } else {
          if (entry.value is Map) {
            final filterMap = entry.value as Map;
            final cleanedFilter = <String, dynamic>{};
            for (final filterEntry in filterMap.entries) {
              if (filterEntry.value != null) {
                cleanedFilter[filterEntry.key.toString()] = filterEntry.value;
              }
            }
            if (cleanedFilter.isNotEmpty) {
              result[entry.key] = cleanedFilter;
            }
          } else {
            try {
              final serialized = (entry.value as dynamic).toJson();
              if (serialized is Map) {
                final cleaned = <String, dynamic>{};
                for (final e in serialized.entries) {
                  if (e.value != null) cleaned[e.key.toString()] = e.value;
                }
                if (cleaned.isNotEmpty) result[entry.key] = cleaned;
              } else {
                result[entry.key] = entry.value;
              }
            } catch (_) {
              result[entry.key] = entry.value;
            }
          }
        }
      }

      return result;
    '''));

  Method _orderByToJson(String m) => Method((b) => b
    ..name = '_orderByToJson'
    ..docs.add('/// Convert OrderByInput to JSON for JsonQueryBuilder')
    ..returns = refer('Map<String, dynamic>')
    ..requiredParameters.add(Parameter((p) => p
      ..name = 'orderBy'
      ..type = refer('${m}OrderByInput')))
    ..body = Code('''
      final json = orderBy.toJson();
      final result = <String, dynamic>{};

      for (final entry in json.entries) {
        if (entry.value != null) {
          result[entry.key] = entry.value.toString().split('.').last;
        }
      }

      return result;
    '''));

  /// Generate all delegate files.
  Map<String, String> generateAll() {
    final files = <String, String>{};

    for (final model in schema.models) {
      final fileName = '${toSnakeCase(model.name)}_delegate.dart';
      files[fileName] = generateDelegate(model);
    }

    return files;
  }
}
