import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/relation_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

void main() {
  group('Atomic update ops (#70 gaps)', () {
    final compiler = SqlCompiler(provider: 'postgresql');

    SqlQuery update(Map<String, dynamic> data) => compiler.compile(
          JsonQueryBuilder()
              .model('Counter')
              .action(QueryAction.update)
              .where({'id': 'c1'})
              .data(data)
              .build(),
        );

    test('increment -> col = col + ?', () {
      final r = update({
        'count': {'increment': 5}
      });
      expect(r.sql, contains('"count" = "count" + \$1'));
      expect(r.args.first, 5);
    });

    test('decrement/multiply/divide map to -, *, /', () {
      expect(
          update({
            'count': {'decrement': 1}
          }).sql,
          contains('"count" = "count" - \$1'));
      expect(
          update({
            'count': {'multiply': 2}
          }).sql,
          contains('"count" = "count" * \$1'));
      expect(
          update({
            'count': {'divide': 2}
          }).sql,
          contains('"count" = "count" / \$1'));
    });

    test('set -> plain assignment', () {
      final r = update({
        'count': {'set': 0}
      });
      expect(r.sql, contains('"count" = \$1'));
      expect(r.sql, isNot(contains('"count" = "count"')));
    });

    test('plain scalar still assigns directly', () {
      final r = update({'name': 'x'});
      expect(r.sql, contains('"name" = \$1'));
    });
  });

  group('createManyAndReturn + skipDuplicates (#70 gaps)', () {
    final compiler = SqlCompiler(provider: 'postgresql');

    test('skipDuplicates -> ON CONFLICT DO NOTHING', () {
      final r = compiler.compile(JsonQueryBuilder()
          .model('Tag')
          .action(QueryAction.createMany)
          .data({
            'data': [
              {'id': 'a'}
            ]
          })
          .skipDuplicates()
          .build());
      expect(r.sql, contains('ON CONFLICT DO NOTHING'));
      expect(r.sql, isNot(contains('RETURNING')));
    });

    test('createManyAndReturn -> RETURNING *', () {
      final r = compiler.compile(JsonQueryBuilder()
          .model('Tag')
          .action(QueryAction.createManyAndReturn)
          .data({
        'data': [
          {'id': 'a'}
        ]
      }).build());
      expect(r.sql, contains('RETURNING *'));
    });
  });

  group('Nested include depth guard (#70 gaps)', () {
    test('exceeding maxIncludeDepth throws', () {
      final schema = SchemaRegistry();
      // Self-referential model: Node -> child Node -> ...
      schema.registerModel(ModelSchema(
        name: 'Node',
        tableName: 'Node',
        fields: {
          'id': const FieldInfo(
              name: 'id', columnName: 'id', type: 'String', isId: true),
          'parentId': const FieldInfo(
              name: 'parentId', columnName: 'parentId', type: 'String'),
        },
        relations: {
          'child': RelationInfo.manyToOne(
              name: 'child', targetModel: 'Node', foreignKey: 'parentId'),
        },
      ));
      final rc = RelationCompiler(schema: schema);

      // Build an include nested deeper than the limit.
      Map<String, dynamic> nest(int n) =>
          n == 0 ? {'child': true} : {'child': {'include': nest(n - 1)}};

      expect(
        () => rc.compile(
          baseModel: 'Node',
          baseAlias: 't0',
          include: nest(RelationCompiler.maxIncludeDepth + 1),
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
