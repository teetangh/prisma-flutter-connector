import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_filter_types_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('isNull typed filters (#0.9.0)', () {
    final parsed = PrismaParser().parse('model Ping { id String @id }');

    test('every filter class carries isNull with true/false emission', () {
      final flat = _flat(CbFilterTypesGenerator(parsed).generate());
      // param present on plain + custom-body filters
      expect('bool? isNull'.allMatches(flat).length, greaterThan(5));
      expect(flat, contains("if (isNull == true) 'isNull': true"));
      expect(flat, contains("if (isNull == false) 'isNotNull': true"));
    });

    test('compiler emits IS NULL / IS NOT NULL', () {
      final c = SqlCompiler(provider: 'postgresql');
      final qNull = JsonQueryBuilder()
          .model('Session')
          .action(QueryAction.findMany)
          .where({
        'endedAt': {'isNull': true}
      }).build();
      expect(c.compile(qNull).sql, contains('"endedAt" IS NULL'));
      final qNotNull = JsonQueryBuilder()
          .model('Session')
          .action(QueryAction.findMany)
          .where({
        'startedAt': {'isNotNull': true}
      }).build();
      expect(c.compile(qNotNull).sql, contains('"startedAt" IS NOT NULL'));
    });
  });

  group('setNull on typed updates (#0.9.0)', () {
    const schema = '''
model User {
  id    String  @id
  image String?
  name  String
}
''';
    test('update/updateMany accept setNull and inject explicit nulls', () {
      final parsed = PrismaParser().parse(schema);
      final flat = _flat(CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first));
      expect(flat, contains('List<UserScalarField>? setNull'));
      expect(flat, contains('data0[f.fieldName] = null'));
    });

    test('compiler SET emits NULL assignment for explicit null values', () {
      final c = SqlCompiler(provider: 'postgresql');
      final q = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.update)
          .where({'id': 'u1'}).data({'image': null}).build();
      final r = c.compile(q);
      expect(r.sql, contains('"image" = \$1'));
      expect(r.args.first, isNull);
    });
  });

  group('m2m nested set (#0.9.0)', () {
    test('write input for m2m relation carries set', () {
      const schema = '''
model Profile {
  id         String      @id
  subDomains SubDomain[]
}
model SubDomain {
  id       String    @id
  profiles Profile[]
}
''';
      final parsed = PrismaParser().parse(schema);
      final flat = _flat(CbModelGenerator(parsed)
          .generateModel(parsed.models.firstWhere((m) => m.name == 'Profile')));
      expect(flat, contains('List<SubDomainWhereUniqueInput>? set'));
      expect(
          flat,
          contains(
              "if (set != null) 'set': set!.map((e) => e.toJson()).toList()"));
    });

    test('engine compiles set as junction clear + connects', () {
      final s = SchemaRegistry();
      s.registerModel(
          ModelSchema(name: 'Profile', tableName: 'Profile', fields: {
        'id': const FieldInfo(
            name: 'id', columnName: 'id', type: 'String', isId: true),
      }, relations: {
        'subDomains': RelationInfo.manyToMany(
          name: 'subDomains',
          targetModel: 'SubDomain',
          joinTable: '_ProfileToSubDomain',
          joinColumn: 'A',
          inverseJoinColumn: 'B',
        ),
      }));
      s.registerModel(
          const ModelSchema(name: 'SubDomain', tableName: 'SubDomain', fields: {
        'id':
            FieldInfo(name: 'id', columnName: 'id', type: 'String', isId: true),
      }));
      final c = SqlCompiler(provider: 'postgresql', schema: s);
      final compiled = c.compileWithRelations(JsonQueryBuilder()
          .model('Profile')
          .action(QueryAction.update)
          .where({'id': 'p1'}).data({
        'subDomains': {
          'set': [
            {'id': 's1'},
            {'id': 's2'}
          ]
        }
      }).build());
      final muts = compiled.relationMutations;
      expect(muts.length, 3); // 1 clear + 2 connects
      expect(muts.first.sql,
          contains('DELETE FROM "_ProfileToSubDomain" WHERE "A" = \$1'));
      expect(muts[1].sql, contains('INSERT INTO "_ProfileToSubDomain"'));
      expect(muts[1].args, equals(['p1', 's1']));
      expect(muts[2].args, equals(['p1', 's2']));
    });

    test('set on a 1:N relation throws (no silent data loss)', () {
      final s = SchemaRegistry();
      s.registerModel(ModelSchema(name: 'Author', tableName: 'Author', fields: {
        'id': const FieldInfo(
            name: 'id', columnName: 'id', type: 'String', isId: true),
      }, relations: {
        'posts': RelationInfo.oneToMany(
            name: 'posts', targetModel: 'Post', foreignKey: 'authorId'),
      }));
      s.registerModel(
          const ModelSchema(name: 'Post', tableName: 'Post', fields: {
        'id':
            FieldInfo(name: 'id', columnName: 'id', type: 'String', isId: true),
        'authorId':
            FieldInfo(name: 'authorId', columnName: 'authorId', type: 'String'),
      }));
      final c = SqlCompiler(provider: 'postgresql', schema: s);
      expect(
        () => c.compileWithRelations(JsonQueryBuilder()
            .model('Author')
            .action(QueryAction.update)
            .where({'id': 'a1'}).data({
          'posts': {
            'set': [
              {'id': 'p1'}
            ]
          }
        }).build()),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('null-tolerant defaulted-array decode (#0.9.0)', () {
    test('required String[] decodes NULL as const []', () {
      const schema = '''
model Clip {
  id   String   @id
  urls String[] @default([])
}
''';
      final parsed = PrismaParser().parse(schema);
      final flat =
          _flat(CbModelGenerator(parsed).generateModel(parsed.models.first));
      expect(flat, contains("(json['urls'] as List?)?.cast<String>()"));
      expect(flat, isNot(contains("(json['urls'] as List).cast<String>()")));
    });
  });
}
