import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

/// Runtime-level test for @@map/@map support: a hand-built SchemaRegistry
/// (mirroring what CbSchemaRegistryGenerator emits for a schema with
/// `@@map("users")` and `status String @map("requestStatus")`) is fed to
/// SqlCompiler and the compiled SQL is inspected.
///
/// What the compiler guarantees:
/// - Model → table resolution: model 'User' targets table "users".
/// - Field → column resolution in WHERE, INSERT columns, UPDATE SET, and
///   ORDER BY: Dart field 'status' targets column "requestStatus", with
///   pass-through for keys that are not registered field names (so legacy
///   JsonQueryBuilder callers using literal column names keep working).
void main() {
  late SchemaRegistry registry;

  setUp(() {
    registry = SchemaRegistry()
      ..registerModel(const ModelSchema(
        name: 'User',
        tableName: 'users',
        fields: {
          'id': FieldInfo(
            name: 'id',
            columnName: 'id',
            type: 'String',
            isId: true,
          ),
          'status': FieldInfo(
            name: 'status',
            columnName: 'requestStatus',
            type: 'String',
          ),
        },
      ));
  });

  group('SqlCompiler with @@map-ed registry (postgresql)', () {
    late SqlCompiler compiler;

    setUp(() {
      compiler = SqlCompiler(provider: 'postgresql', schema: registry);
    });

    test('findMany resolves model name to mapped table name', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .where({'status': 'PENDING'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('FROM "users"'));
      expect(result.sql, isNot(contains('"User"')));
      expect(result.args, ['PENDING']);
    });

    test('WHERE keys translate Dart field names to mapped columns', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .where({'status': 'PENDING'}).build();

      final result = compiler.compile(query);

      expect(result.sql, 'SELECT * FROM "users" WHERE "requestStatus" = \$1');
    });

    test('WHERE keys that are already column names pass through unchanged', () {
      // Legacy JsonQueryBuilder callers filter by the literal column name;
      // 'requestStatus' is not a registered field name so it passes through.
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .where({'requestStatus': 'PENDING'}).build();

      final result = compiler.compile(query);

      expect(result.sql, 'SELECT * FROM "users" WHERE "requestStatus" = \$1');
    });

    test('WHERE translation applies inside AND/OR/NOT recursion', () {
      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).where({
        'OR': [
          {'status': 'PENDING'},
          {'status': 'APPROVED'},
        ],
      }).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('"requestStatus" = \$1'));
      expect(result.sql, contains('"requestStatus" = \$2'));
      expect(result.sql, isNot(contains('"status"')));
    });

    test('INSERT columns translate Dart field names to mapped columns', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.create)
          .data({'id': 'u1', 'status': 'PENDING'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('INSERT INTO "users"'));
      expect(result.sql, contains('"requestStatus"'));
      expect(result.sql, isNot(contains('"status"')));
    });

    test('UPDATE SET keys translate Dart field names to mapped columns', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.update)
          .where({'id': 'u1'}).data({'status': 'APPROVED'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('UPDATE "users"'));
      expect(result.sql, contains('SET "requestStatus" = \$1'));
      expect(result.sql, isNot(contains('"status"')));
    });

    test('ORDER BY keys translate Dart field names to mapped columns', () {
      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .orderBy({'status': 'desc'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('ORDER BY "requestStatus" DESC'));
    });

    test('count and delete also resolve the mapped table name', () {
      final count = compiler.compile(
          JsonQueryBuilder().model('User').action(QueryAction.count).build());
      expect(count.sql, 'SELECT COUNT(*) FROM "users"');

      final delete = compiler.compile(JsonQueryBuilder()
          .model('User')
          .action(QueryAction.deleteMany)
          .where({'id': 'u1'}).build());
      expect(delete.sql, 'DELETE FROM "users" WHERE "id" = \$1');
    });

    test('strict validation rejects unregistered PascalCase models', () {
      final strict = SqlCompiler(
        provider: 'postgresql',
        schema: registry,
        strictModelValidation: true,
      );

      final query = JsonQueryBuilder()
          .model('Account')
          .action(QueryAction.findMany)
          .build();

      expect(() => strict.compile(query), throwsArgumentError);

      // Registered model compiles fine under strict validation
      final ok = strict.compile(JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .build());
      expect(ok.sql, 'SELECT * FROM "users"');
    });

    test('groupBy resolves @map field to column and aliases back', () {
      final q = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.groupBy)
          .groupByFields(['status']).aggregation({'_count': true}).build();
      final r = compiler.compile(q);
      // Dart field 'status' -> column "requestStatus"; SELECT aliases it back
      expect(r.sql, contains('"requestStatus" AS "status"'));
      expect(r.sql, contains('GROUP BY "requestStatus"'));
      expect(r.sql, contains('COUNT(*)'));
    });

    test('aggregate resolves @map field in function arg, aliases by field', () {
      final q = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.aggregate)
          .aggregation({
        '_count': true,
        '_min': {'status': true},
      }).build();
      final r = compiler.compile(q);
      // MIN over the DB column, alias keeps the Dart field name
      expect(r.sql, contains('MIN("requestStatus") AS "_min_status"'));
      expect(r.sql, contains('COUNT(*)'));
    });

    test('upsert resolves @map conflict + column names', () {
      final q = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.upsert)
          .where({'id': 'u1'}).data({
        'create': {'id': 'u1', 'status': 'PENDING'},
        'update': {'status': 'APPROVED'},
      }).build();
      final r = compiler.compile(q);
      expect(r.sql, contains('INSERT INTO "users"'));
      expect(r.sql, contains('"requestStatus"'));
      expect(r.sql, contains('ON CONFLICT ("id")'));
      expect(r.sql, isNot(contains('"status"')));
    });
  });

  group('SqlCompiler with @@map-ed registry (sqlite)', () {
    test('findMany resolves mapped table and column with ? placeholders', () {
      final compiler = SqlCompiler(provider: 'sqlite', schema: registry);

      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.findMany)
          .where({'status': 'PENDING'}).build();

      final result = compiler.compile(query);

      expect(result.sql, 'SELECT * FROM "users" WHERE "requestStatus" = ?');
      expect(result.args, ['PENDING']);
    });
  });

  group('SchemaRegistry column metadata', () {
    test(
        'ModelSchema.columnNames exposes mapped column names for SELECT '
        'lists', () {
      final model = registry.getModel('User');

      expect(model, isNotNull);
      expect(model!.columnNames, ['id', 'requestStatus']);
      expect(registry.getField('User', 'status')!.columnName, 'requestStatus');
      expect(registry.getTableName('User'), 'users');
    });
  });
}
