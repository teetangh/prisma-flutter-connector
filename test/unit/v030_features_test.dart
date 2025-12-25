/// Comprehensive tests for prisma_flutter_connector v0.3.0 features
///
/// This file tests all 5 phases of v0.3.0 enhancements:
/// - Phase 1: Connect/Disconnect API for M2M relations
/// - Phase 2: `in:` filter + include combination
/// - Phase 3: Deep nesting support
/// - Phase 4: M2M support in relationPath filter
/// - Phase 5: @@map() table name mapping

import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

void main() {
  group('v0.3.0 Features', () {
    late SchemaRegistry schemaRegistry;

    setUp(() {
      schemaRegistry = SchemaRegistry();

      // Register comprehensive schema for testing
      _registerTestSchema(schemaRegistry);
    });

    // =========================================================================
    // PHASE 1: Connect/Disconnect API for M2M Relations
    // =========================================================================
    group('Phase 1: Connect/Disconnect API', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      group('connect operations', () {
        test('compiles connect with create action', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.create)
              .data({
            'id': 'slot-123',
            'startsAt': '2024-01-01T10:00:00Z',
            'users': {
              'connect': [
                {'id': 'user-1'},
                {'id': 'user-2'},
              ],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          // Main INSERT should not include 'users' field
          expect(result.mainQuery.sql, contains('INSERT INTO'));
          expect(result.mainQuery.sql, contains('"slot_of_appointments"'));
          expect(result.mainQuery.sql, isNot(contains('users')));

          // Should generate 2 junction table INSERTs
          expect(result.relationMutations.length, 2);
          expect(result.relationMutations[0].sql,
              contains('INSERT INTO "_SlotOfAppointmentToUser"'));
          expect(result.relationMutations[0].sql,
              contains('ON CONFLICT DO NOTHING'));
        });

        test('compiles connect with update action', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.update)
              .where({'id': 'slot-123'})
              .data({
            'users': {
              'connect': [
                {'id': 'user-new'},
              ],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          expect(result.mainQuery.sql, contains('UPDATE'));
          expect(result.relationMutations.length, 1);
          expect(result.relationMutations[0].args, ['slot-123', 'user-new']);
        });

        test('handles empty connect array', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.create)
              .data({
            'id': 'slot-123',
            'startsAt': '2024-01-01T10:00:00Z',
            'users': {
              'connect': [],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          expect(result.relationMutations, isEmpty);
        });
      });

      group('disconnect operations', () {
        test('compiles disconnect in update action', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.update)
              .where({'id': 'slot-123'})
              .data({
            'users': {
              'disconnect': [
                {'id': 'user-1'},
              ],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          expect(result.relationMutations.length, 1);
          expect(result.relationMutations[0].sql,
              contains('DELETE FROM "_SlotOfAppointmentToUser"'));
          expect(result.relationMutations[0].args, ['slot-123', 'user-1']);
        });

        test('compiles multiple disconnects', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.update)
              .where({'id': 'slot-123'})
              .data({
            'users': {
              'disconnect': [
                {'id': 'user-1'},
                {'id': 'user-2'},
                {'id': 'user-3'},
              ],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          expect(result.relationMutations.length, 3);
        });
      });

      group('mixed connect and disconnect', () {
        test('compiles both connect and disconnect in same mutation', () {
          final query = JsonQueryBuilder()
              .model('SlotOfAppointment')
              .action(QueryAction.update)
              .where({'id': 'slot-123'})
              .data({
            'users': {
              'connect': [
                {'id': 'user-new-1'},
                {'id': 'user-new-2'},
              ],
              'disconnect': [
                {'id': 'user-old'},
              ],
            },
          }).build();

          final result = compiler.compileWithRelations(query);

          // Should have 3 mutations: 2 connects + 1 disconnect
          expect(result.relationMutations.length, 3);

          // First 2 should be connects (INSERT)
          expect(result.relationMutations[0].sql, contains('INSERT'));
          expect(result.relationMutations[1].sql, contains('INSERT'));

          // Last should be disconnect (DELETE)
          expect(result.relationMutations[2].sql, contains('DELETE'));
        });
      });

      group('provider-specific SQL', () {
        test('PostgreSQL uses ON CONFLICT DO NOTHING', () {
          final pgCompiler = SqlCompiler(
            provider: 'postgresql',
            schema: schemaRegistry,
          );

          final query = _createConnectQuery();
          final result = pgCompiler.compileWithRelations(query);

          expect(result.relationMutations[0].sql,
              contains('ON CONFLICT DO NOTHING'));
        });

        test('Supabase uses ON CONFLICT DO NOTHING', () {
          final supabaseCompiler = SqlCompiler(
            provider: 'supabase',
            schema: schemaRegistry,
          );

          final query = _createConnectQuery();
          final result = supabaseCompiler.compileWithRelations(query);

          expect(result.relationMutations[0].sql,
              contains('ON CONFLICT DO NOTHING'));
        });

        test('MySQL uses INSERT IGNORE', () {
          final mysqlCompiler = SqlCompiler(
            provider: 'mysql',
            schema: schemaRegistry,
          );

          final query = _createConnectQuery();
          final result = mysqlCompiler.compileWithRelations(query);

          expect(result.relationMutations[0].sql, contains('INSERT IGNORE'));
        });

        test('SQLite uses INSERT OR IGNORE', () {
          final sqliteCompiler = SqlCompiler(
            provider: 'sqlite',
            schema: schemaRegistry,
          );

          final query = _createConnectQuery();
          final result = sqliteCompiler.compileWithRelations(query);

          expect(result.relationMutations[0].sql, contains('INSERT OR IGNORE'));
        });
      });
    });

    // =========================================================================
    // PHASE 2: `in:` Filter + Include Combination
    // =========================================================================
    group('Phase 2: in: Filter + Include Combination', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('in filter generates correct SQL', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.in_(['id1', 'id2', 'id3']),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('WHERE'));
        expect(result.sql, contains('IN'));
        expect(result.sql, contains('\$1'));
        expect(result.sql, contains('\$2'));
        expect(result.sql, contains('\$3'));
        expect(result.args, ['id1', 'id2', 'id3']);
      });

      test('in filter works with single include', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.in_(['cp1', 'cp2']),
        }).include({'user': true}).build();

        final result = compiler.compile(query);

        // Should have both WHERE IN and JOIN
        expect(result.sql, contains('WHERE'));
        expect(result.sql, contains('IN'));
        expect(result.sql, contains('LEFT JOIN'));
        expect(result.sql, contains('"users"'));
      });

      test('in filter with nested includes maintains parameter order', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.in_(['cp1', 'cp2', 'cp3']),
        }).include({
          'user': true,
          'domain': {'select': {'name': true}},
        }).build();

        final result = compiler.compile(query);

        // Parameters should be the in_ values
        expect(result.args, ['cp1', 'cp2', 'cp3']);

        // Should have multiple JOINs
        expect(result.sql, contains('LEFT JOIN'));
      });

      test('in filter with AND condition and include', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'AND': [
            {'id': FilterOperators.in_(['cp1', 'cp2'])},
            {'isVerified': true},
          ],
        }).include({'user': true}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('IN'));
        expect(result.sql, contains('AND'));
        expect(result.sql, contains('LEFT JOIN'));
      });

      test('large in filter (10+ items) compiles correctly', () {
        final ids = List.generate(15, (i) => 'id-$i');
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.in_(ids),
        }).build();

        final result = compiler.compile(query);

        expect(result.args.length, 15);
        expect(result.sql, contains('\$15'));
      });

      test('notIn filter works correctly', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.notIn(['id1', 'id2']),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('NOT IN'));
      });
    });

    // =========================================================================
    // PHASE 3: Deep Nesting Support
    // =========================================================================
    group('Phase 3: Deep Nesting Support', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('2-level deep includes compile correctly', () {
        final query = JsonQueryBuilder()
            .model('Appointment')
            .action(QueryAction.findMany)
            .include({
          'slots': {
            'include': {
              'meetingSession': true,
            },
          },
        }).build();

        final result = compiler.compile(query);

        // Should have multiple JOINs
        expect(result.sql, contains('LEFT JOIN'));
        expect(result.sql, contains('"slot_of_appointments"'));
      });

      test('3-level deep includes compile correctly', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({
          'user': {
            'include': {
              'consulteeProfile': {
                'include': {
                  'user': true,
                },
              },
            },
          },
        }).build();

        final result = compiler.compile(query);

        // Should compile without error
        expect(result.sql, contains('SELECT'));
        expect(result.sql, contains('LEFT JOIN'));
      });

      test('deep includes with select work correctly', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({
          'user': {
            'select': {'id': true, 'name': true},
          },
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT'));
      });
    });

    // =========================================================================
    // PHASE 4: M2M Support in relationPath Filter
    // =========================================================================
    group('Phase 4: M2M relationPath Filter', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('some operator works for one-to-many relations', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'consulteeProfile': FilterOperators.some({
            'id': FilterOperators.isNotNull(),
          }),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('EXISTS'));
      });

      test('every operator works for relations', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'consultationPlans': FilterOperators.every({
            'price': FilterOperators.gte(100),
          }),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('NOT EXISTS'));
      });

      test('noneMatch operator works for relations', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'consultationPlans': FilterOperators.noneMatch({
            'price': FilterOperators.lte(50),
          }),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('NOT EXISTS'));
      });
    });

    // =========================================================================
    // PHASE 5: @@map() Table Name Mapping
    // =========================================================================
    group('Phase 5: @@map() Table Name Mapping', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('@@map resolves for findMany', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        // User model is mapped to "users" table
        expect(result.sql, contains('FROM "users"'));
        expect(result.sql, isNot(contains('FROM "User"')));
      });

      test('@@map resolves for findUnique', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': '123'})
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('FROM "users"'));
      });

      test('@@map resolves for create', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.create)
            .data({'id': 'user-1', 'name': 'Test User'})
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('INSERT INTO "users"'));
      });

      test('@@map resolves for update', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.update)
            .where({'id': '123'})
            .data({'name': 'Updated'})
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('UPDATE "users"'));
      });

      test('@@map resolves for delete', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.delete)
            .where({'id': '123'})
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('DELETE FROM "users"'));
      });

      test('@@map works with includes', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({'user': true})
            .build();

        final result = compiler.compile(query);

        // Should use mapped table names in JOINs
        expect(result.sql, contains('"users"'));
      });

      test('@@map works with connect/disconnect', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-1',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': [{'id': 'user-1'}],
          },
        }).build();

        final result = compiler.compileWithRelations(query);

        // Main query should use mapped table name
        expect(result.mainQuery.sql, contains('"slot_of_appointments"'));
      });

      test('fallback to model name when not registered', () {
        final query = JsonQueryBuilder()
            .model('UnknownModel')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        // Should use model name as-is
        expect(result.sql, contains('"UnknownModel"'));
      });
    });

    // =========================================================================
    // EDGE CASES AND INTEGRATION
    // =========================================================================
    group('Edge Cases and Integration', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('CompiledMutation hasRelationMutations property', () {
        final queryWithRelations = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-1',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': [{'id': 'user-1'}],
          },
        }).build();

        final resultWithRelations =
            compiler.compileWithRelations(queryWithRelations);
        expect(resultWithRelations.hasRelationMutations, true);

        final queryWithoutRelations = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-1',
          'startsAt': '2024-01-01T10:00:00Z',
        }).build();

        final resultWithoutRelations =
            compiler.compileWithRelations(queryWithoutRelations);
        expect(resultWithoutRelations.hasRelationMutations, false);
      });

      test('compileWithRelations works with non-M2M relation data', () {
        // If data contains a relation that's not M2M, it should be ignored
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.create)
            .data({
          'id': 'cp-1',
          'userId': 'user-1',
          // user is a oneToOne relation, not M2M - should be ignored
          'user': {
            'connect': {'id': 'user-1'},
          },
        }).build();

        final result = compiler.compileWithRelations(query);

        // Should not generate relation mutations for non-M2M
        // (the oneToOne connect syntax is different from M2M)
        expect(result.mainQuery.sql, contains('INSERT'));
      });

      test('complex query with multiple features combined', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({
          'id': FilterOperators.in_(['cp1', 'cp2']),
          'isVerified': true,
        }).include({'user': true}).orderBy({'rating': 'desc'}).take(10).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('IN'));
        expect(result.sql, contains('LEFT JOIN'));
        expect(result.sql, contains('ORDER BY'));
        expect(result.sql, contains('LIMIT'));
      });
    });
  });
}

/// Helper to create a standard connect query for testing
JsonQuery _createConnectQuery() {
  return JsonQueryBuilder()
      .model('SlotOfAppointment')
      .action(QueryAction.create)
      .data({
    'id': 'slot-123',
    'startsAt': '2024-01-01T10:00:00Z',
    'users': {
      'connect': [
        {'id': 'user-1'},
      ],
    },
  }).build();
}

/// Register a comprehensive test schema
void _registerTestSchema(SchemaRegistry schema) {
  // User model - mapped to "users" table
  schema.registerModel(ModelSchema(
    name: 'User',
    tableName: 'users', // @@map("users")
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'name': const FieldInfo(name: 'name', columnName: 'name', type: 'String'),
      'email': const FieldInfo(name: 'email', columnName: 'email', type: 'String'),
    },
    relations: {
      'consultantProfile': RelationInfo.oneToOne(
        name: 'consultantProfile',
        targetModel: 'ConsultantProfile',
        foreignKey: 'id',
      ),
      'consulteeProfile': RelationInfo.oneToOne(
        name: 'consulteeProfile',
        targetModel: 'ConsulteeProfile',
        foreignKey: 'id',
      ),
    },
  ));

  // ConsultantProfile model
  schema.registerModel(ModelSchema(
    name: 'ConsultantProfile',
    tableName: 'consultant_profiles',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'userId': const FieldInfo(name: 'userId', columnName: 'userId', type: 'String'),
      'headline': const FieldInfo(name: 'headline', columnName: 'headline', type: 'String'),
      'rating': const FieldInfo(name: 'rating', columnName: 'rating', type: 'double'),
      'isVerified': const FieldInfo(name: 'isVerified', columnName: 'isVerified', type: 'bool'),
    },
    relations: {
      'user': RelationInfo.oneToOne(
        name: 'user',
        targetModel: 'User',
        foreignKey: 'userId',
      ),
      'domain': RelationInfo.oneToOne(
        name: 'domain',
        targetModel: 'Domain',
        foreignKey: 'domainId',
      ),
      'consultationPlans': RelationInfo.oneToMany(
        name: 'consultationPlans',
        targetModel: 'ConsultationPlan',
        foreignKey: 'consultantProfileId',
      ),
    },
  ));

  // ConsulteeProfile model
  schema.registerModel(ModelSchema(
    name: 'ConsulteeProfile',
    tableName: 'consultee_profiles',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'userId': const FieldInfo(name: 'userId', columnName: 'userId', type: 'String'),
    },
    relations: {
      'user': RelationInfo.oneToOne(
        name: 'user',
        targetModel: 'User',
        foreignKey: 'userId',
      ),
    },
  ));

  // Domain model
  schema.registerModel(ModelSchema(
    name: 'Domain',
    tableName: 'domains',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'name': const FieldInfo(name: 'name', columnName: 'name', type: 'String'),
    },
    relations: {},
  ));

  // ConsultationPlan model
  schema.registerModel(ModelSchema(
    name: 'ConsultationPlan',
    tableName: 'consultation_plans',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'consultantProfileId': const FieldInfo(
        name: 'consultantProfileId',
        columnName: 'consultantProfileId',
        type: 'String',
      ),
      'price': const FieldInfo(name: 'price', columnName: 'price', type: 'double'),
    },
    relations: {},
  ));

  // Appointment model
  schema.registerModel(ModelSchema(
    name: 'Appointment',
    tableName: 'appointments',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
    },
    relations: {
      'slots': RelationInfo.oneToMany(
        name: 'slots',
        targetModel: 'SlotOfAppointment',
        foreignKey: 'appointmentId',
      ),
    },
  ));

  // SlotOfAppointment model with M2M relation
  schema.registerModel(ModelSchema(
    name: 'SlotOfAppointment',
    tableName: 'slot_of_appointments',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'startsAt': const FieldInfo(name: 'startsAt', columnName: 'startsAt', type: 'DateTime'),
      'endsAt': const FieldInfo(name: 'endsAt', columnName: 'endsAt', type: 'DateTime'),
      'appointmentId': const FieldInfo(
        name: 'appointmentId',
        columnName: 'appointmentId',
        type: 'String',
      ),
    },
    relations: {
      'users': RelationInfo.manyToMany(
        name: 'users',
        targetModel: 'User',
        joinTable: '_SlotOfAppointmentToUser',
        joinColumn: 'A',
        inverseJoinColumn: 'B',
      ),
      'meetingSession': RelationInfo.oneToOne(
        name: 'meetingSession',
        targetModel: 'MeetingSession',
        foreignKey: 'id',
      ),
    },
  ));

  // MeetingSession model
  schema.registerModel(ModelSchema(
    name: 'MeetingSession',
    tableName: 'meeting_sessions',
    fields: {
      'id': FieldInfo.id(name: 'id', type: 'String'),
      'slotId': const FieldInfo(name: 'slotId', columnName: 'slotId', type: 'String'),
    },
    relations: {},
  ));
}
