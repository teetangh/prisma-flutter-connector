import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

/// @updatedAt columns are NOT NULL with no database default — Prisma clients
/// supply the timestamp on every create and refresh it on every update.
void main() {
  late SchemaRegistry registry;

  setUp(() {
    registry = SchemaRegistry()
      ..registerModel(const ModelSchema(
        name: 'Plan',
        tableName: 'Plan',
        fields: {
          'id': FieldInfo(
            name: 'id',
            columnName: 'id',
            type: 'String',
            isId: true,
            defaultValue: 'uuid()',
          ),
          'title':
              FieldInfo(name: 'title', columnName: 'title', type: 'String'),
          'createdAt': FieldInfo(
            name: 'createdAt',
            columnName: 'createdAt',
            type: 'DateTime',
            defaultValue: 'now()',
          ),
          'updatedAt': FieldInfo(
            name: 'updatedAt',
            columnName: 'updatedAt',
            type: 'DateTime',
            isUpdatedAt: true,
          ),
        },
      ));
  });

  group('CREATE fills @updatedAt (postgresql)', () {
    test('absent updatedAt is filled with NOW()', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.create)
          .data({'title': 'Mock interview'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('"updatedAt"'));
      expect(result.sql, contains('NOW()'));
      // id default and createdAt default also auto-filled
      expect(result.sql, contains('gen_random_uuid()'));
    });

    test('explicit updatedAt is respected (no duplicate column)', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query =
          JsonQueryBuilder().model('Plan').action(QueryAction.create).data({
        'title': 'Mock interview',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }).build();

      final result = compiler.compile(query);

      expect('"updatedAt"'.allMatches(result.sql).length, 1);
      expect(result.args, contains('2026-01-01T00:00:00.000Z'));
    });
  });

  group('CREATE fills @updatedAt (sqlite)', () {
    test('absent updatedAt is filled with a timestamp parameter', () {
      final compiler = SqlCompiler(provider: 'sqlite', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.create)
          .data({'title': 'Mock interview'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('"updatedAt"'));
      // value supplied as an ISO-8601 parameter, not raw SQL
      expect(
        result.args.whereType<String>().any((a) => a.contains('T')),
        isTrue,
      );
    });
  });

  group('UPSERT autofills @default + @updatedAt', () {
    test('create arm fills uuid id + createdAt + updatedAt', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.upsert)
          .where({'id': 'p1'}).data({
        'create': {'title': 'Mock'},
        'update': {'title': 'Renamed'},
      }).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('INSERT INTO "Plan"'));
      expect(result.sql, contains('gen_random_uuid()'));
      // updatedAt appears in both the INSERT values and the DO UPDATE SET
      expect('NOW()'.allMatches(result.sql).length, greaterThanOrEqualTo(2));
      expect(result.sql, contains('ON CONFLICT ("id")'));
      expect(result.sql, contains('DO UPDATE SET'));
    });

    test('update arm refreshes @updatedAt even when caller omits it', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.upsert)
          .where({'id': 'p1'}).data({
        'create': {'title': 'Mock'},
        'update': {'title': 'Renamed'},
      }).build();

      final result = compiler.compile(query);
      expect(result.sql, contains('"updatedAt" = NOW()'));
    });
  });

  group('UPDATE refreshes @updatedAt', () {
    test('absent updatedAt is auto-set in SET clause', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.update)
          .where({'id': 'p1'}).data({'title': 'Renamed'}).build();

      final result = compiler.compile(query);

      expect(result.sql, contains('"updatedAt" ='));
      expect(
        result.args.whereType<String>().any((a) => a.contains('T')),
        isTrue,
      );
    });

    test('explicit updatedAt is respected', () {
      final compiler = SqlCompiler(provider: 'postgresql', schema: registry);
      final query = JsonQueryBuilder()
          .model('Plan')
          .action(QueryAction.update)
          .where({'id': 'p1'}).data({
        'title': 'Renamed',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      }).build();

      final result = compiler.compile(query);

      expect('"updatedAt"'.allMatches(result.sql).length, 1);
      expect(result.args, contains('2026-01-01T00:00:00.000Z'));
    });
  });
}
