import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

/// Registry mirroring slot_repository's chain:
/// Slot -> appointment (N:1) -> consultation (1:1) -> consultationPlan (1:N).
SchemaRegistry _chainRegistry() {
  final s = SchemaRegistry();
  s.registerModel(ModelSchema(name: 'Slot', tableName: 'Slot', fields: {
    'id': const FieldInfo(
        name: 'id', columnName: 'id', type: 'String', isId: true),
    'appointmentId': const FieldInfo(
        name: 'appointmentId', columnName: 'appointmentId', type: 'String'),
  }, relations: {
    'appointment': RelationInfo.manyToOne(
        name: 'appointment',
        targetModel: 'Appointment',
        foreignKey: 'appointmentId'),
  }));
  s.registerModel(
      ModelSchema(name: 'Appointment', tableName: 'Appointment', fields: {
    'id': const FieldInfo(
        name: 'id', columnName: 'id', type: 'String', isId: true),
  }, relations: {
    'consultation': RelationInfo.oneToOne(
        name: 'consultation',
        targetModel: 'Consultation',
        foreignKey: 'appointmentId'),
  }));
  s.registerModel(
      ModelSchema(name: 'Consultation', tableName: 'Consultation', fields: {
    'id': const FieldInfo(
        name: 'id', columnName: 'id', type: 'String', isId: true),
    'appointmentId': const FieldInfo(
        name: 'appointmentId', columnName: 'appointmentId', type: 'String'),
    'requestStatus': const FieldInfo(
        name: 'requestStatus', columnName: 'requestStatus', type: 'String'),
  }, relations: {
    'consultationPlan': RelationInfo.oneToMany(
        name: 'consultationPlan',
        targetModel: 'Plan',
        foreignKey: 'consultationId'),
  }));
  s.registerModel(const ModelSchema(name: 'Plan', tableName: 'Plan', fields: {
    'id': FieldInfo(name: 'id', columnName: 'id', type: 'String', isId: true),
    'consultationId': FieldInfo(
        name: 'consultationId', columnName: 'consultationId', type: 'String'),
    'consultantProfileId': FieldInfo(
        name: 'consultantProfileId',
        columnName: 'consultantProfileId',
        type: 'String'),
  }));
  return s;
}

const _innerWhere = {
  'consultationPlan': {
    'some': {'consultantProfileId': 'c1'}
  },
  'requestStatus': {
    'in': ['PENDING', 'APPROVED']
  },
};

void main() {
  group('nested typed relation filters replace relationPath (#0.8.0)', () {
    late SqlCompiler compiler;
    setUp(() => compiler =
        SqlCompiler(provider: 'postgresql', schema: _chainRegistry()));

    SqlQuery nested() => compiler.compile(JsonQueryBuilder()
            .model('Slot')
            .action(QueryAction.findMany)
            .where({
          'appointment': {
            'is': {
              'consultation': {'is': _innerWhere}
            }
          }
        }).build());

    SqlQuery viaPath() => compiler.compile(JsonQueryBuilder()
            .model('Slot')
            .action(QueryAction.findMany)
            .where({
          '_relationPath': 'appointment.consultation',
          '_relationWhere': _innerWhere,
        }).build());

    test('nested typed shape compiles to correctly-correlated nested EXISTS',
        () {
      final r = nested();
      // 3 EXISTS levels: appointment -> consultation -> consultationPlan
      expect('EXISTS'.allMatches(r.sql).length, 3);
      // each level correlates to its immediate parent alias
      expect(r.sql, contains('sub_appointment."id" = "Slot"."appointmentId"'));
      expect(r.sql,
          contains('sub_consultation."appointmentId" = sub_appointment."id"'));
      expect(
          r.sql,
          contains(
              'sub_consultationPlan."consultationId" = sub_consultation."id"'));
      expect(r.args, equals(['c1', 'PENDING', 'APPROVED']));
    });

    test('semantic equivalence with legacy relationPath (same filters + args)',
        () {
      final a = nested();
      final b = viaPath();
      // Both are EXISTS-based semijoins over the same tables with the same
      // parameters (structures differ: nested EXISTS vs JOIN-chain EXISTS).
      for (final sql in [a.sql, b.sql]) {
        expect(sql, contains('"Appointment"'));
        expect(sql, contains('"Consultation"'));
        expect(sql, contains('"Plan"'));
        expect(sql, contains('EXISTS'));
      }
      expect(a.args, equals(b.args));
    });

    test('aliases stay distinct along a chain of distinct relation names', () {
      final r = nested();
      // sub_<relationName> is unique per level here; a collision could only
      // occur if the SAME relation name repeated along one chain (documented
      // limitation — not exercised by the app schema).
      expect(r.sql, contains('sub_appointment'));
      expect(r.sql, contains('sub_consultation'));
      expect(r.sql, contains('sub_consultationPlan'));
    });
  });

  group('include with per-relation select compiles to projected columns', () {
    test('select sub-map limits the relation columns in the SELECT list', () {
      final s = SchemaRegistry();
      s.registerModel(ModelSchema(name: 'Post', tableName: 'Post', fields: {
        'id': const FieldInfo(
            name: 'id', columnName: 'id', type: 'String', isId: true),
        'title':
            const FieldInfo(name: 'title', columnName: 'title', type: 'String'),
        'authorId': const FieldInfo(
            name: 'authorId', columnName: 'authorId', type: 'String'),
      }, relations: {
        'author': RelationInfo.manyToOne(
            name: 'author', targetModel: 'User', foreignKey: 'authorId'),
      }));
      s.registerModel(
          const ModelSchema(name: 'User', tableName: 'User', fields: {
        'id':
            FieldInfo(name: 'id', columnName: 'id', type: 'String', isId: true),
        'name': FieldInfo(name: 'name', columnName: 'name', type: 'String'),
        'secret':
            FieldInfo(name: 'secret', columnName: 'secret', type: 'String'),
      }));
      final compiler = SqlCompiler(provider: 'postgresql', schema: s);

      // Shape emitted by XInclude.toJson() when a nested include has select:
      final q = JsonQueryBuilder()
          .model('Post')
          .action(QueryAction.findMany)
          .include({
        'author': {
          'select': {'name': true}
        }
      }).build();
      final r = compiler.compile(q);

      expect(r.sql, contains('"author__name"'));
      expect(r.sql, isNot(contains('"author__secret"')));
    });
  });

  group('projected finders generation (#0.8.0)', () {
    const schema = '''
model Post {
  id       String @id
  title    String
  views    Int
  author   User   @relation(fields: [authorId], references: [id])
  authorId String
}
model User { id String @id }
''';

    String delegate() {
      final parsed = PrismaParser().parse(schema);
      return CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);
    }

    test('findManyProjected has typed inputs and selectFields wiring', () {
      final flat = _flat(delegate());
      expect(flat,
          contains('Future<List<Map<String, dynamic>>> findManyProjected'));
      expect(flat, contains('PostWhereInput? where'));
      expect(flat, contains('List<PostScalarField>? select'));
      expect(flat, contains('Map<String, ComputedField>? computed'));
      expect(flat, contains('List<PostScalarField>? distinctOn'));
      expect(flat, contains('PostWhereUniqueInput? cursor'));
      expect(flat,
          contains('selectFields([for (final f in select) f.fieldName])'));
      expect(flat, contains('if (computed != null) queryBuilder.computed'));
    });

    test('findFirstProjected exists and returns a single map', () {
      final flat = _flat(delegate());
      expect(
          flat, contains('Future<Map<String, dynamic>?> findFirstProjected'));
      expect(flat, contains('executeQueryAsSingleMap'));
    });

    test('raw helpers are removed in 0.9.0', () {
      final flat = _flat(delegate());
      expect(flat, isNot(contains('findManyRaw')));
      expect(flat, isNot(contains('findFirstRaw')));
    });
  });
}
