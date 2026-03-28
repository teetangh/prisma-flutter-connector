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
        Directive.import('../filters.dart'),
      ])
      ..body.add(_buildDelegateClass(modelName, tableName)));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return _formatter.format('${library.accept(emitter)}');
  }

  Class _buildDelegateClass(String modelName, String tableName) {
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
        _findUnique(modelName, tableName),
        _findUniqueOrThrow(modelName),
        _findFirst(modelName, tableName),
        _findMany(modelName, tableName),
        _create(modelName, tableName),
        _createMany(modelName, tableName),
        _update(modelName, tableName),
        _updateMany(modelName, tableName),
        _delete(modelName, tableName),
        _deleteMany(modelName, tableName),
        _count(modelName, tableName),
        _groupBy(modelName, tableName),
        _normalizeForJson(),
        _whereUniqueToJson(modelName),
        _whereToJson(modelName),
        _orderByToJson(modelName),
      ]));
  }

  Method _findUnique(String m, String t) => Method((b) => b
    ..name = 'findUnique'
    ..docs.add('/// Find a single $m by unique field(s)')
    ..modifier = MethodModifier.async
    ..returns = refer('Future<$m?>')
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'where'
      ..named = true
      ..required = true
      ..type = refer('${m}WhereUniqueInput')))
    ..body = Code('''
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findUnique)
          .where(_whereUniqueToJson(where))
          .build();

      final result = await _executor.executeQueryAsSingleMap(query);
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
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findFirst);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy != null) queryBuilder.orderBy(_orderByToJson(orderBy));

      final result = await _executor.executeQueryAsSingleMap(queryBuilder.build());
      return result != null ? $m.fromJson(_normalizeForJson(result)) : null;
    '''));

  Method _findMany(String m, String t) => Method((b) => b
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
        ..type = refer('${m}OrderByInput?')),
      Parameter((p) => p
        ..name = 'take'
        ..named = true
        ..type = refer('int?')),
      Parameter((p) => p
        ..name = 'skip'
        ..named = true
        ..type = refer('int?')),
    ])
    ..body = Code('''
      final queryBuilder = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.findMany);

      if (where != null) queryBuilder.where(_whereToJson(where));
      if (orderBy != null) queryBuilder.orderBy(_orderByToJson(orderBy));
      if (take != null) queryBuilder.take(take);
      if (skip != null) queryBuilder.skip(skip);

      final results = await _executor.executeQueryAsMaps(queryBuilder.build());
      return results.map((json) => $m.fromJson(_normalizeForJson(json))).toList();
    '''));

  Method _create(String m, String t) => Method((b) => b
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
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.create)
          .data(data.toJson())
          .build();

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
    ..optionalParameters.add(Parameter((p) => p
      ..name = 'data'
      ..named = true
      ..required = true
      ..type = refer('List<Create${m}Input>')))
    ..body = Code('''
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.createMany)
          .data({'data': data.map((d) => d.toJson()).toList()})
          .build();

      return await _executor.executeMutation(query);
    '''));

  Method _update(String m, String t) => Method((b) => b
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
      final query = JsonQueryBuilder()
          .model('$t')
          .action(QueryAction.update)
          .where(_whereUniqueToJson(where))
          .data(data.toJson())
          .build();

      await _executor.executeMutation(query);

      // Fetch the updated record
      return await findUniqueOrThrow(where: where);
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
                for (final e in (serialized as Map).entries) {
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
