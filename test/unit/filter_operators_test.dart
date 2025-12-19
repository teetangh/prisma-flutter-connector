import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';

void main() {
  group('FilterOperators', () {
    group('Equality Operators', () {
      test('equals creates correct map', () {
        final result = FilterOperators.equals('test');

        expect(result, {'equals': 'test'});
      });

      test('equals with null value', () {
        final result = FilterOperators.equals(null);

        expect(result, {'equals': null});
      });

      test('equals with int value', () {
        final result = FilterOperators.equals(42);

        expect(result, {'equals': 42});
      });

      test('equals with bool value', () {
        final result = FilterOperators.equals(true);

        expect(result, {'equals': true});
      });

      test('not creates correct map', () {
        final result = FilterOperators.not('test');

        expect(result, {'not': 'test'});
      });

      test('not with null value', () {
        final result = FilterOperators.not(null);

        expect(result, {'not': null});
      });
    });

    group('List Operators', () {
      test('in_ creates correct map with strings', () {
        final result = FilterOperators.in_(['a', 'b', 'c']);

        expect(result, {
          'in': ['a', 'b', 'c']
        });
      });

      test('in_ creates correct map with ints', () {
        final result = FilterOperators.in_([1, 2, 3]);

        expect(result, {
          'in': [1, 2, 3]
        });
      });

      test('in_ with empty list', () {
        final result = FilterOperators.in_([]);

        expect(result, {'in': []});
      });

      test('notIn creates correct map', () {
        final result = FilterOperators.notIn(['x', 'y']);

        expect(result, {
          'notIn': ['x', 'y']
        });
      });

      test('notIn with ints', () {
        final result = FilterOperators.notIn([1, 2, 3]);

        expect(result, {
          'notIn': [1, 2, 3]
        });
      });
    });

    group('Comparison Operators', () {
      test('lt creates correct map', () {
        final result = FilterOperators.lt(100);

        expect(result, {'lt': 100});
      });

      test('lt with double', () {
        final result = FilterOperators.lt(99.99);

        expect(result, {'lt': 99.99});
      });

      test('lt with DateTime', () {
        final date = DateTime(2024, 1, 1);
        final result = FilterOperators.lt(date);

        expect(result, {'lt': date});
      });

      test('lte creates correct map', () {
        final result = FilterOperators.lte(100);

        expect(result, {'lte': 100});
      });

      test('gt creates correct map', () {
        final result = FilterOperators.gt(50);

        expect(result, {'gt': 50});
      });

      test('gt with double', () {
        final result = FilterOperators.gt(49.99);

        expect(result, {'gt': 49.99});
      });

      test('gte creates correct map', () {
        final result = FilterOperators.gte(50);

        expect(result, {'gte': 50});
      });
    });

    group('String Operators', () {
      test('contains creates correct map', () {
        final result = FilterOperators.contains('test');

        expect(result, {'contains': 'test'});
      });

      test('contains with empty string', () {
        final result = FilterOperators.contains('');

        expect(result, {'contains': ''});
      });

      test('startsWith creates correct map', () {
        final result = FilterOperators.startsWith('prefix');

        expect(result, {'startsWith': 'prefix'});
      });

      test('endsWith creates correct map', () {
        final result = FilterOperators.endsWith('suffix');

        expect(result, {'endsWith': 'suffix'});
      });

      test('containsInsensitive creates correct map with mode', () {
        final result = FilterOperators.containsInsensitive('Test');

        expect(result, {
          'contains': {'value': 'Test', 'mode': 'insensitive'}
        });
      });

      test('startsWithInsensitive creates correct map with mode', () {
        final result = FilterOperators.startsWithInsensitive('Prefix');

        expect(result, {
          'startsWith': {'value': 'Prefix', 'mode': 'insensitive'}
        });
      });

      test('endsWithInsensitive creates correct map with mode', () {
        final result = FilterOperators.endsWithInsensitive('Suffix');

        expect(result, {
          'endsWith': {'value': 'Suffix', 'mode': 'insensitive'}
        });
      });
    });

    group('Logical Operators', () {
      test('and creates correct map', () {
        final result = FilterOperators.and([
          {'status': 'active'},
          {'role': 'admin'},
        ]);

        expect(result, {
          'AND': [
            {'status': 'active'},
            {'role': 'admin'},
          ]
        });
      });

      test('and with single condition', () {
        final result = FilterOperators.and([
          {'status': 'active'},
        ]);

        expect(result, {
          'AND': [
            {'status': 'active'},
          ]
        });
      });

      test('and with empty list', () {
        final result = FilterOperators.and([]);

        expect(result, {'AND': []});
      });

      test('or creates correct map', () {
        final result = FilterOperators.or([
          {'role': 'admin'},
          {'role': 'moderator'},
        ]);

        expect(result, {
          'OR': [
            {'role': 'admin'},
            {'role': 'moderator'},
          ]
        });
      });

      test('or with multiple conditions', () {
        final result = FilterOperators.or([
          {'status': 'active'},
          {'status': 'pending'},
          {'status': 'review'},
        ]);

        expect(result, {
          'OR': [
            {'status': 'active'},
            {'status': 'pending'},
            {'status': 'review'},
          ]
        });
      });

      test('none creates correct map', () {
        final result = FilterOperators.none({'status': 'banned'});

        expect(result, {
          'NOT': {'status': 'banned'}
        });
      });

      test('none with nested condition', () {
        final result = FilterOperators.none({
          'AND': [
            {'status': 'inactive'},
            {'deletedAt': null},
          ]
        });

        expect(result, {
          'NOT': {
            'AND': [
              {'status': 'inactive'},
              {'deletedAt': null},
            ]
          }
        });
      });
    });

    group('Complex Combinations', () {
      test('nested AND within OR', () {
        final result = FilterOperators.or([
          FilterOperators.and([
            {'status': 'active'},
            {'role': 'admin'},
          ]),
          FilterOperators.and([
            {'status': 'active'},
            {'role': 'moderator'},
          ]),
        ]);

        expect(result, {
          'OR': [
            {
              'AND': [
                {'status': 'active'},
                {'role': 'admin'},
              ]
            },
            {
              'AND': [
                {'status': 'active'},
                {'role': 'moderator'},
              ]
            },
          ]
        });
      });

      test('comparison operators combined with contains', () {
        // Simulate a price range query with name filter
        final priceFilter = {
          'price': {
            ...FilterOperators.gte(10),
            ...FilterOperators.lte(100),
          }
        };

        expect(priceFilter, {
          'price': {'gte': 10, 'lte': 100}
        });
      });

      test('NOT with in_ operator', () {
        final result = FilterOperators.none({
          'status': FilterOperators.in_(['banned', 'suspended']),
        });

        expect(result, {
          'NOT': {
            'status': {
              'in': ['banned', 'suspended']
            }
          }
        });
      });
    });

    group('Relation Filters', () {
      test('some creates correct structure', () {
        final result = FilterOperators.some({
          'price': FilterOperators.lte(5000),
        });

        expect(result, {
          'some': {
            'price': {'lte': 5000}
          }
        });
      });

      test('every creates correct structure', () {
        final result = FilterOperators.every({
          'published': true,
        });

        expect(result, {
          'every': {'published': true}
        });
      });

      test('noneMatch creates correct structure', () {
        final result = FilterOperators.noneMatch({
          'spam': true,
        });

        expect(result, {
          'none': {'spam': true}
        });
      });

      test('isEmpty creates empty none structure', () {
        final result = FilterOperators.isEmpty();

        expect(result, {'none': <String, dynamic>{}});
      });

      test('isNotEmpty creates empty some structure', () {
        final result = FilterOperators.isNotEmpty();

        expect(result, {'some': <String, dynamic>{}});
      });

      test('can be used in where clause', () {
        // This simulates the intended usage
        final whereClause = {
          'consultationPlans': FilterOperators.some({
            'price': FilterOperators.lte(5000),
          }),
        };

        expect(whereClause, {
          'consultationPlans': {
            'some': {
              'price': {'lte': 5000}
            }
          }
        });
      });

      test('can combine multiple relation filters', () {
        final whereClause = {
          'posts': FilterOperators.some({
            'published': true,
          }),
          'comments': FilterOperators.noneMatch({
            'spam': true,
          }),
        };

        expect(whereClause, {
          'posts': {
            'some': {'published': true}
          },
          'comments': {
            'none': {'spam': true}
          },
        });
      });
    });
  });

  group('JsonQueryBuilder', () {
    test('builds basic findMany query', () {
      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).build();

      expect(query.modelName, 'User');
      expect(query.action, 'findMany');
    });

    test('builds query with where clause', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .where({'email': 'test@example.com'}).build();

      expect(query.args.arguments?['where'], {'email': 'test@example.com'});
    });

    test('builds query with data clause', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.create)
          .data({'email': 'test@example.com', 'name': 'Test'}).build();

      expect(query.args.arguments?['data'], {
        'email': 'test@example.com',
        'name': 'Test',
      });
    });

    test('builds query with orderBy clause', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .orderBy({'createdAt': 'desc'}).build();

      expect(query.args.arguments?['orderBy'], {'createdAt': 'desc'});
    });

    test('builds query with take and skip', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .take(10)
          .skip(20)
          .build();

      expect(query.args.arguments?['take'], 10);
      expect(query.args.arguments?['skip'], 20);
    });

    test('builds query with filter operators', () {
      final query = JsonQueryBuilder()
          .model('Product')
          .action(QueryAction.findMany)
          .where({
        'price': FilterOperators.gte(100),
        'name': FilterOperators.contains('phone'),
      }).build();

      expect(query.args.arguments?['where'], {
        'price': {'gte': 100},
        'name': {'contains': 'phone'},
      });
    });

    test('builds query with select', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .select({'id': true, 'email': true}).build();

      expect(query.args.selection, isNotNull);
      expect(query.args.selection!.fields, isNotNull);
    });

    test('builds query with include', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .include({'posts': true}).build();

      expect(query.args.selection, isNotNull);
      expect(query.args.selection!.fields, isNotNull);
    });

    test('throws when model is missing', () {
      expect(
        () => JsonQueryBuilder().action(QueryAction.findMany).build(),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when action is missing', () {
      expect(
        () => JsonQueryBuilder().model('User').build(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('JsonQuery', () {
    test('toJson produces correct structure', () {
      const query = JsonQuery(
        modelName: 'User',
        action: 'findMany',
        args: JsonQueryArgs(
          arguments: {
            'where': {'email': 'test@example.com'}
          },
        ),
      );

      final json = query.toJson();

      expect(json['modelName'], 'User');
      expect(json['action'], 'findMany');
      expect(json['query']['arguments']['where']['email'], 'test@example.com');
    });

    test('toString produces JSON string', () {
      const query = JsonQuery(
        modelName: 'User',
        action: 'findMany',
        args: JsonQueryArgs(),
      );

      final str = query.toString();

      expect(str.contains('User'), true);
      expect(str.contains('findMany'), true);
    });
  });

  group('JsonQueryArgs', () {
    test('toJson with arguments only', () {
      const args = JsonQueryArgs(
        arguments: {
          'where': {'id': '123'}
        },
      );

      final json = args.toJson();

      expect(json['arguments'], {
        'where': {'id': '123'}
      });
      expect(json.containsKey('selection'), false);
    });

    test('toJson with selection only', () {
      const args = JsonQueryArgs(
        selection: JsonSelection(scalars: true),
      );

      final json = args.toJson();

      expect(json['selection']['\$scalars'], true);
    });

    test('toJson with both arguments and selection', () {
      const args = JsonQueryArgs(
        arguments: {'take': 10},
        selection: JsonSelection(scalars: true),
      );

      final json = args.toJson();

      expect(json['arguments'], {'take': 10});
      expect(json['selection']['\$scalars'], true);
    });
  });

  group('JsonSelection', () {
    test('toJson with scalars', () {
      const selection = JsonSelection(scalars: true);

      final json = selection.toJson();

      expect(json['\$scalars'], true);
    });

    test('toJson with composites', () {
      const selection = JsonSelection(composites: true);

      final json = selection.toJson();

      expect(json['\$composites'], true);
    });

    test('toJson with fields', () {
      const selection = JsonSelection(
        fields: {
          'id': JsonFieldSelection(),
          'email': JsonFieldSelection(),
        },
      );

      final json = selection.toJson();

      expect(json.containsKey('id'), true);
      expect(json.containsKey('email'), true);
    });
  });

  group('JsonFieldSelection', () {
    test('toJson empty', () {
      const fieldSelection = JsonFieldSelection();

      final json = fieldSelection.toJson();

      expect(json, isEmpty);
    });

    test('toJson with arguments', () {
      const fieldSelection = JsonFieldSelection(
        arguments: {'take': 5},
      );

      final json = fieldSelection.toJson();

      expect(json['arguments'], {'take': 5});
    });

    test('toJson with nested selection', () {
      const fieldSelection = JsonFieldSelection(
        selection: JsonSelection(scalars: true),
      );

      final json = fieldSelection.toJson();

      expect(json['selection']['\$scalars'], true);
    });
  });

  group('PrismaValue', () {
    test('dateTime creates correct structure', () {
      final dt = DateTime(2024, 1, 15, 10, 30);
      final value = PrismaValue.dateTime(dt);

      expect(value.type, '\$type');
      expect(value.value['DateTime'], dt.toIso8601String());
    });

    test('json creates correct structure', () {
      final jsonData = {'key': 'value', 'number': 42};
      final value = PrismaValue.json(jsonData);

      expect(value.type, '\$type');
      expect(value.value['Json'], contains('key'));
    });

    test('bytes creates correct structure', () {
      final bytes = [1, 2, 3, 4, 5];
      final value = PrismaValue.bytes(bytes);

      expect(value.type, '\$type');
      expect(value.value['Bytes'], isA<String>());
    });

    test('decimal creates correct structure', () {
      final value = PrismaValue.decimal('123.45');

      expect(value.type, '\$type');
      expect(value.value['Decimal'], '123.45');
    });

    test('bigInt creates correct structure', () {
      final value = PrismaValue.bigInt(BigInt.from(9999999999999));

      expect(value.type, '\$type');
      expect(value.value['BigInt'], '9999999999999');
    });

    test('toJson produces map', () {
      final value = PrismaValue.decimal('99.99');

      final json = value.toJson();

      expect(json['\$type']['Decimal'], '99.99');
    });
  });

  group('QueryAction enum', () {
    test('all actions have correct values', () {
      expect(QueryAction.findUnique.value, 'findUnique');
      expect(QueryAction.findUniqueOrThrow.value, 'findUniqueOrThrow');
      expect(QueryAction.findFirst.value, 'findFirst');
      expect(QueryAction.findFirstOrThrow.value, 'findFirstOrThrow');
      expect(QueryAction.findMany.value, 'findMany');
      expect(QueryAction.create.value, 'create');
      expect(QueryAction.createMany.value, 'createMany');
      expect(QueryAction.update.value, 'update');
      expect(QueryAction.updateMany.value, 'updateMany');
      expect(QueryAction.upsert.value, 'upsert');
      expect(QueryAction.delete.value, 'delete');
      expect(QueryAction.deleteMany.value, 'deleteMany');
      expect(QueryAction.aggregate.value, 'aggregate');
      expect(QueryAction.groupBy.value, 'groupBy');
      expect(QueryAction.count.value, 'count');
    });
  });
}
