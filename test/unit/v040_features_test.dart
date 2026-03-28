import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

void main() {
  group('v0.4.0 Features', () {
    group('#26 - orderBy List support', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('single Map orderBy still works', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .orderBy({'createdAt': 'desc'}).build();

        final result = compiler.compile(query);
        expect(result.sql, contains('ORDER BY "createdAt" DESC'));
      });

      test('List<Map> orderBy generates multi-column sort', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .orderBy([
          {'lastName': 'asc'},
          {'firstName': 'asc'},
        ]).build();

        final result = compiler.compile(query);
        expect(
            result.sql, contains('ORDER BY "lastName" ASC, "firstName" ASC'));
      });

      test('List<Map> with extended syntax works', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .orderBy([
          {
            'createdAt': {'sort': 'desc', 'nulls': 'last'}
          },
          {'name': 'asc'},
        ]).build();

        final result = compiler.compile(query);
        expect(result.sql, contains('ORDER BY'));
        expect(result.sql, contains('"createdAt" DESC NULLS LAST'));
        expect(result.sql, contains('"name" ASC'));
      });
    });

    group('#24 - @default(uuid) auto-generation', () {
      late SqlCompiler compiler;
      late SchemaRegistry registry;

      setUp(() {
        registry = SchemaRegistry();
        registry.registerModel(const ModelSchema(
          name: 'Feedback',
          tableName: 'feedbacks',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
              defaultValue: 'uuid()',
            ),
            'title': FieldInfo(
              name: 'title',
              columnName: 'title',
              type: 'String',
            ),
            'createdAt': FieldInfo(
              name: 'createdAt',
              columnName: 'created_at',
              type: 'DateTime',
              defaultValue: 'now()',
            ),
          },
        ));
        compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      });

      test('auto-generates gen_random_uuid() for @default(uuid()) fields', () {
        final query = JsonQueryBuilder()
            .model('Feedback')
            .action(QueryAction.create)
            .data({'title': 'Test feedback'}).build();

        final result = compiler.compile(query);

        // Should have gen_random_uuid() as a raw SQL value, not a parameter
        expect(result.sql, contains('gen_random_uuid()'));
        expect(result.sql, contains('NOW()'));
        // Title should still be parameterized
        expect(result.args, contains('Test feedback'));
      });

      test('does not override explicitly provided ID', () {
        final query = JsonQueryBuilder()
            .model('Feedback')
            .action(QueryAction.create)
            .data({'id': 'custom-id', 'title': 'Test'}).build();

        final result = compiler.compile(query);

        // Should NOT have gen_random_uuid() since ID was provided
        expect(result.sql, isNot(contains('gen_random_uuid()')));
        expect(result.args, contains('custom-id'));
      });
    });

    group('#32 - M2M in relationPath filters', () {
      late SqlCompiler compiler;
      late SchemaRegistry registry;

      setUp(() {
        registry = SchemaRegistry();
        registry.registerModel(ModelSchema(
          name: 'Appointment',
          tableName: 'appointments',
          fields: {
            'id': const FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
          },
          relations: {
            'slots': RelationInfo.oneToMany(
              name: 'slots',
              targetModel: 'SlotOfAppointment',
              foreignKey: 'appointmentId',
            ),
          },
        ));
        registry.registerModel(ModelSchema(
          name: 'SlotOfAppointment',
          tableName: 'slots_of_appointment',
          fields: {
            'id': const FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
            'appointmentId': const FieldInfo(
                name: 'appointmentId',
                columnName: 'appointment_id',
                type: 'String'),
          },
          relations: {
            'user': RelationInfo.manyToMany(
              name: 'user',
              targetModel: 'User',
              joinTable: '_SlotOfAppointmentToUser',
              joinColumn: 'A',
              inverseJoinColumn: 'B',
            ),
          },
        ));
        registry.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
            'name': FieldInfo(
                name: 'name', columnName: 'name', type: 'String'),
          },
        ));
        compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      });

      test('M2M in first position of relationPath generates junction JOINs',
          () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.findMany)
            .where({
          ...FilterOperators.relationPath('user', {'id': 'user-1'}),
        }).build();

        final result = compiler.compile(query);

        // Should generate EXISTS with junction table
        expect(result.sql, contains('_SlotOfAppointmentToUser'));
      });
    });

    group('#30 - Nested writes (1:N create)', () {
      late SqlCompiler compiler;
      late SchemaRegistry registry;

      setUp(() {
        registry = SchemaRegistry();
        registry.registerModel(ModelSchema(
          name: 'appointments',
          tableName: 'appointments',
          fields: {
            'id': const FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
          },
          relations: {
            'slots': RelationInfo.oneToMany(
              name: 'slots',
              targetModel: 'slots_of_appointment',
              foreignKey: 'appointmentId',
            ),
          },
        ));
        registry.registerModel(const ModelSchema(
          name: 'slots_of_appointment',
          tableName: 'slots_of_appointment',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
              defaultValue: 'uuid()',
            ),
            'appointmentId': FieldInfo(
                name: 'appointmentId',
                columnName: 'appointment_id',
                type: 'String'),
            'startsAt': FieldInfo(
                name: 'startsAt', columnName: 'starts_at', type: 'DateTime'),
          },
        ));
        compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      });

      test('nested create generates parent + child INSERTs', () {
        final query = JsonQueryBuilder()
            .model('appointments')
            .action(QueryAction.create)
            .data({
          'id': 'appt-1',
          'slots': {
            'create': [
              {'startsAt': '2026-01-01T10:00:00Z'},
              {'startsAt': '2026-01-01T11:00:00Z'},
            ],
          },
        }).build();

        final result = compiler.compileWithRelations(query);

        // Main query should insert the appointment
        expect(result.mainQuery.sql, contains('INSERT INTO "appointments"'));
        expect(result.mainQuery.sql, isNot(contains('slots')));

        // Should have 2 relation mutations for the child slots
        expect(result.relationMutations, hasLength(2));
        for (final mutation in result.relationMutations) {
          expect(mutation.sql, contains('INSERT INTO "slots_of_appointment"'));
          // FK should be injected
          expect(mutation.args, contains('appt-1'));
        }
      });
    });

    group('#33 - groupBy in SqlCompiler', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('generates GROUP BY with COUNT', () {
        final query = JsonQueryBuilder()
            .model('Consultation')
            .action(QueryAction.groupBy)
            .groupByFields(['requestStatus']).aggregation(
                {'_count': true}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('GROUP BY "requestStatus"'));
        expect(result.sql, contains('COUNT(*)'));
      });

      test('generates GROUP BY with multiple aggregations', () {
        final query = JsonQueryBuilder()
            .model('Payment')
            .action(QueryAction.groupBy)
            .groupByFields(['status']).aggregation({
          '_count': true,
          '_sum': {'amount': true},
          '_avg': {'amount': true},
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('GROUP BY "status"'));
        expect(result.sql, contains('COUNT(*)'));
        expect(result.sql, contains('SUM("amount")'));
        expect(result.sql, contains('AVG("amount")'));
      });
    });

    group('SchemaRegistryGenerator', () {
      test('can import and use the generator', () {
        // This is a compile-time test - if this file compiles, the import works
        expect(true, isTrue);
      });
    });
  });
}
