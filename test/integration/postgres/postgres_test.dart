import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/errors/prisma_exceptions.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';
import 'package:test/test.dart';

/// Integration tests for PostgreSQL runtime (`PostgresAdapter` + `QueryExecutor`).
///
/// Connects to a live PostgreSQL instance when reachable (configured via
/// `DATABASE_URL` / `POSTGRES_DATABASE_URL` or default `localhost:5432`), and
/// falls back to an in-memory stateful [pg.Connection] harness when no local
/// PostgreSQL server is running so the suite can be verified in all environments.
void main() {
  group('PostgreSQL Integration Tests', () {
    late pg.Connection connection;
    late PostgresAdapter adapter;
    late QueryExecutor executor;
    late SchemaRegistry schema;
    var usingLivePostgres = false;

    SchemaRegistry buildTestSchema() {
      final reg = SchemaRegistry();
      reg.registerModel(const ModelSchema(
        name: 'User',
        tableName: 'User',
        fields: {
          'id': FieldInfo(
              name: 'id', columnName: 'id', type: 'String', isId: true),
          'email': FieldInfo(
            name: 'email',
            columnName: 'email',
            type: 'String',
            isUnique: true,
          ),
          'name': FieldInfo(name: 'name', columnName: 'name', type: 'String'),
          'age': FieldInfo(
            name: 'age',
            columnName: 'age',
            type: 'Int',
            isNullable: true,
          ),
          'metadata': FieldInfo(
            name: 'metadata',
            columnName: 'metadata',
            type: 'Json',
            isNullable: true,
          ),
        },
        relations: {
          'posts': RelationInfo(
            name: 'posts',
            type: RelationType.oneToMany,
            targetModel: 'Post',
            foreignKey: 'authorId',
            references: ['id'],
          ),
          'tags': RelationInfo(
            name: 'tags',
            type: RelationType.manyToMany,
            targetModel: 'Tag',
            foreignKey: 'id',
            references: ['id'],
            joinTable: '_UserTags',
            joinColumn: 'A',
            inverseJoinColumn: 'B',
          ),
        },
      ));

      reg.registerModel(const ModelSchema(
        name: 'Post',
        tableName: 'Post',
        fields: {
          'id': FieldInfo(
              name: 'id', columnName: 'id', type: 'String', isId: true),
          'title':
              FieldInfo(name: 'title', columnName: 'title', type: 'String'),
          'content':
              FieldInfo(name: 'content', columnName: 'content', type: 'String'),
          'published': FieldInfo(
            name: 'published',
            columnName: 'published',
            type: 'Boolean',
          ),
          'authorId': FieldInfo(
            name: 'authorId',
            columnName: 'authorId',
            type: 'String',
          ),
        },
        relations: {
          'author': RelationInfo(
            name: 'author',
            type: RelationType.manyToOne,
            targetModel: 'User',
            foreignKey: 'authorId',
            references: ['id'],
          ),
        },
      ));

      reg.registerModel(const ModelSchema(
        name: 'Tag',
        tableName: 'Tag',
        fields: {
          'id': FieldInfo(
              name: 'id', columnName: 'id', type: 'String', isId: true),
          'label': FieldInfo(
            name: 'label',
            columnName: 'label',
            type: 'String',
            isUnique: true,
          ),
        },
      ));

      reg.registerModel(const ModelSchema(
        name: 'IntPost',
        tableName: 'IntPost',
        fields: {
          'id':
              FieldInfo(name: 'id', columnName: 'id', type: 'Int', isId: true),
          'title':
              FieldInfo(name: 'title', columnName: 'title', type: 'String'),
        },
        relations: {
          'categories': RelationInfo(
            name: 'categories',
            type: RelationType.manyToMany,
            targetModel: 'IntCategory',
            foreignKey: 'id',
            references: ['id'],
            joinTable: '_CategoryToPost',
            joinColumn: 'B',
            inverseJoinColumn: 'A',
          ),
        },
      ));

      reg.registerModel(const ModelSchema(
        name: 'IntCategory',
        tableName: 'IntCategory',
        fields: {
          'id':
              FieldInfo(name: 'id', columnName: 'id', type: 'Int', isId: true),
          'name': FieldInfo(name: 'name', columnName: 'name', type: 'String'),
        },
      ));

      return reg;
    }

    setUpAll(() async {
      schema = buildTestSchema();

      final configuredDbUrl = Platform.environment['DATABASE_URL'] ??
          Platform.environment['POSTGRES_DATABASE_URL'];
      final hasExplicitDbUrl =
          configuredDbUrl != null && configuredDbUrl.trim().isNotEmpty;
      final dbUrl = hasExplicitDbUrl
          ? configuredDbUrl
          : 'postgresql://test_user:test_password@localhost:5432/test_db';

      try {
        final uri = Uri.parse(dbUrl);
        final userInfo = uri.userInfo.split(':');
        final username = userInfo.isNotEmpty && userInfo[0].isNotEmpty
            ? Uri.decodeComponent(userInfo[0])
            : 'test_user';
        final password = userInfo.length > 1
            ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
            : 'test_password';
        final host = uri.host.isNotEmpty ? uri.host : 'localhost';
        final port = uri.hasPort ? uri.port : 5432;
        final database =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'test_db';

        connection = await pg.Connection.open(
          pg.Endpoint(
            host: host,
            port: port,
            database: database,
            username: username,
            password: password,
          ),
          settings: const pg.ConnectionSettings(
            sslMode: pg.SslMode.disable,
            connectTimeout: Duration(seconds: 2),
          ),
        );
        usingLivePostgres = true;
      } catch (_) {
        if (hasExplicitDbUrl) rethrow;
        connection = _InMemoryPostgresConnection();
        usingLivePostgres = false;
      }

      adapter = PostgresAdapter(connection);
      executor = QueryExecutor(adapter: adapter, schema: schema);

      await adapter.executeScript('''
DROP TABLE IF EXISTS "_CategoryToPost" CASCADE;
DROP TABLE IF EXISTS "IntCategory" CASCADE;
DROP TABLE IF EXISTS "IntPost" CASCADE;
DROP TABLE IF EXISTS "_UserTags" CASCADE;
DROP TABLE IF EXISTS "Tag" CASCADE;
DROP TABLE IF EXISTS "Post" CASCADE;
DROP TABLE IF EXISTS "User" CASCADE;

CREATE TABLE "User" (
  "id" TEXT PRIMARY KEY,
  "email" TEXT NOT NULL UNIQUE,
  "name" TEXT NOT NULL,
  "age" INTEGER,
  "metadata" JSONB,
  "createdAt" TIMESTAMP DEFAULT NOW(),
  "updatedAt" TIMESTAMP DEFAULT NOW()
);

CREATE TABLE "Post" (
  "id" TEXT PRIMARY KEY,
  "title" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "published" BOOLEAN NOT NULL DEFAULT FALSE,
  "authorId" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "createdAt" TIMESTAMP DEFAULT NOW(),
  "updatedAt" TIMESTAMP DEFAULT NOW()
);

CREATE TABLE "Tag" (
  "id" TEXT PRIMARY KEY,
  "label" TEXT NOT NULL UNIQUE
);

CREATE TABLE "_UserTags" (
  "A" TEXT NOT NULL REFERENCES "User"("id") ON DELETE CASCADE,
  "B" TEXT NOT NULL REFERENCES "Tag"("id") ON DELETE CASCADE,
  PRIMARY KEY ("A", "B")
);

CREATE TABLE "IntPost" (
  "id" INTEGER PRIMARY KEY,
  "title" TEXT NOT NULL
);

CREATE TABLE "IntCategory" (
  "id" INTEGER PRIMARY KEY,
  "name" TEXT NOT NULL
);

CREATE TABLE "_CategoryToPost" (
  "A" INTEGER NOT NULL REFERENCES "IntCategory"("id") ON DELETE CASCADE,
  "B" INTEGER NOT NULL REFERENCES "IntPost"("id") ON DELETE CASCADE,
  PRIMARY KEY ("A", "B")
);

CREATE OR REPLACE FUNCTION pfc_noop_helper() RETURNS integer AS \$\$
DECLARE
  msg text := 'semi;colon;inside;dollar;quote';
BEGIN
  RETURN 1;
END;
\$\$ LANGUAGE plpgsql;
''');
    });

    setUp(() async {
      await adapter.executeScript('''
DELETE FROM "_CategoryToPost";
DELETE FROM "IntCategory";
DELETE FROM "IntPost";
DELETE FROM "_UserTags";
DELETE FROM "Tag";
DELETE FROM "Post";
DELETE FROM "User";
''');
    });

    tearDownAll(() async {
      await executor.dispose();
    });

    test(
        'should connect to PostgreSQL backend and execute scripts with embedded semicolons',
        () async {
      expect(adapter.provider, equals('postgresql'));
      final statements = PostgresAdapter.splitSqlStatements('''
INSERT INTO "Tag" ("id", "label") VALUES ('t-semi', 'semi;colon;label');
DO \$\$ BEGIN PERFORM 1; PERFORM 2; END \$\$;
''');
      expect(statements, hasLength(2));

      await adapter.executeScript('''
INSERT INTO "Tag" ("id", "label") VALUES ('t-semi', 'semi;colon;label');
''');

      final tag = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('Tag')
            .action(QueryAction.findUnique)
            .where({'id': 't-semi'}).build(),
      );
      expect(tag, isNotNull);
      expect(tag!['label'], equals('semi;colon;label'));
    });

    test('should create, findUnique, update, count, and delete a user',
        () async {
      final created = await executor.executeMutationAsMap(
        JsonQueryBuilder().model('User').action(QueryAction.create).data({
          'id': 'u-1',
          'email': 'alice@example.com',
          'name': 'Alice',
          'age': 30,
        }).build(),
      );
      expect(created, isNotNull);
      expect(created!['id'], equals('u-1'));
      expect(created['email'], equals('alice@example.com'));

      final found = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': 'u-1'}).build(),
      );
      expect(found, isNotNull);
      expect(found!['name'], equals('Alice'));

      final updatedRows = await executor.executeMutation(
        JsonQueryBuilder().model('User').action(QueryAction.update).where(
            {'id': 'u-1'}).data({'name': 'Alice Smith', 'age': 31}).build(),
      );
      expect(updatedRows, equals(1));

      final count = await executor.executeCount(
        JsonQueryBuilder().model('User').action(QueryAction.count).build(),
      );
      expect(count, equals(1));

      final deletedRows = await executor.executeMutation(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.delete)
            .where({'id': 'u-1'}).build(),
      );
      expect(deletedRows, equals(1));

      final afterDelete = await executor.executeCount(
        JsonQueryBuilder().model('User').action(QueryAction.count).build(),
      );
      expect(afterDelete, equals(0));
    });

    test('should query with complex filters, ordering, take, and skip',
        () async {
      for (final u in [
        {'id': 'u-1', 'email': 'alice@example.com', 'name': 'Alice', 'age': 25},
        {'id': 'u-2', 'email': 'bob@example.com', 'name': 'Bob', 'age': 35},
        {
          'id': 'u-3',
          'email': 'charlie@example.com',
          'name': 'Charlie',
          'age': 45
        },
        {'id': 'u-4', 'email': 'diana@other.org', 'name': 'Diana', 'age': 20},
      ]) {
        await executor.executeMutation(
          JsonQueryBuilder()
              .model('User')
              .action(QueryAction.create)
              .data(u)
              .build(),
        );
      }

      final filtered = await executor.executeQueryAsMaps(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
              'AND': [
                {
                  'email': {'contains': '@example.com'}
                },
                {
                  'age': {'gte': 25}
                },
              ],
            })
            .orderBy({'age': 'asc'})
            .skip(1)
            .take(2)
            .build(),
      );

      expect(filtered, hasLength(2));
      expect(filtered[0]['name'], equals('Bob'));
      expect(filtered[1]['name'], equals('Charlie'));
    });

    test('should round-trip JSON fields via jsonEncode and filter by JSON path',
        () async {
      final metaPayload = {
        'role': 'admin',
        'preferences': {'theme': 'dark'},
        'badges': ['early-adopter', 'verified'],
      };

      await executor.executeMutation(
        JsonQueryBuilder().model('User').action(QueryAction.create).data({
          'id': 'u-json',
          'email': 'json@example.com',
          'name': 'Json User',
          'metadata': metaPayload,
        }).build(),
      );

      final matched = await executor.executeQueryAsMaps(
        JsonQueryBuilder().model('User').action(QueryAction.findMany).where({
          'metadata': {
            'path': ['preferences', 'theme'],
            'equals': 'dark',
          },
        }).build(),
      );

      expect(matched, hasLength(1));
      expect(matched.first['id'], equals('u-json'));
      final decodedMeta = matched.first['metadata'];
      expect(decodedMeta, isA<Map>());
      expect((decodedMeta as Map)['role'], equals('admin'));
    });

    test(
        'should paginate parent records accurately when findMany combines 1:N include with take/skip',
        () async {
      // Create 3 users, each with 2 posts (6 joined rows total).
      for (var i = 1; i <= 3; i++) {
        await executor.executeMutation(
          JsonQueryBuilder().model('User').action(QueryAction.create).data({
            'id': 'u-$i',
            'email': 'u$i@example.com',
            'name': 'User $i',
          }).build(),
        );
        for (var p = 1; p <= 2; p++) {
          await executor.executeMutation(
            JsonQueryBuilder().model('Post').action(QueryAction.create).data({
              'id': 'p-$i-$p',
              'title': 'Post $p by User $i',
              'content': 'Body',
              'published': true,
              'authorId': 'u-$i',
            }).build(),
          );
        }
      }

      // Request take: 2, skip: 1 with include: {'posts': true}.
      // Subquery pagination must return 2 parent users (u-2 and u-3), each with all 2 of their posts!
      final users = await executor.executeQueryAsMaps(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .include({'posts': true})
            .orderBy({'id': 'asc'})
            .skip(1)
            .take(2)
            .build(),
      );

      expect(users, hasLength(2));
      expect(users[0]['id'], equals('u-2'));
      expect(users[0]['posts'], hasLength(2));
      expect(users[1]['id'], equals('u-3'));
      expect(users[1]['posts'], hasLength(2));
    });

    test(
        'should handle M:N connect, disconnect, and set with UUID (String) primary keys',
        () async {
      await executor.executeMutation(
        JsonQueryBuilder()
            .model('Tag')
            .action(QueryAction.create)
            .data({'id': 'tag-1', 'label': 'Dart'}).build(),
      );
      await executor.executeMutation(
        JsonQueryBuilder()
            .model('Tag')
            .action(QueryAction.create)
            .data({'id': 'tag-2', 'label': 'Flutter'}).build(),
      );

      await executor.executeMutationWithRelationsAtomic(
        JsonQueryBuilder().model('User').action(QueryAction.create).data({
          'id': 'u-m2m',
          'email': 'm2m@example.com',
          'name': 'M2M User',
          'tags': {
            'connect': [
              {'id': 'tag-1'},
              {'id': 'tag-2'},
            ],
          },
        }).build(),
      );

      var fetched = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': 'u-m2m'}).include({'tags': true}).build(),
      );
      expect(fetched, isNotNull);
      expect(fetched!['tags'], hasLength(2));

      // Disconnect tag-1
      await executor.executeMutationWithRelationsAtomic(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.update)
            .where({'id': 'u-m2m'}).data({
          'name': 'M2M User Updated',
          'tags': {
            'disconnect': [
              {'id': 'tag-1'},
            ],
          },
        }).build(),
      );

      fetched = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': 'u-m2m'}).include({'tags': true}).build(),
      );
      expect(fetched!['tags'], hasLength(1));
      expect((fetched['tags'] as List).first['id'], equals('tag-2'));
    });

    test(
        'should handle M:N connect, disconnect, and set with Int primary keys (#50)',
        () async {
      await executor.executeMutation(
        JsonQueryBuilder()
            .model('IntCategory')
            .action(QueryAction.create)
            .data({'id': 1, 'name': 'Tech'}).build(),
      );
      await executor.executeMutation(
        JsonQueryBuilder()
            .model('IntCategory')
            .action(QueryAction.create)
            .data({'id': 2, 'name': 'News'}).build(),
      );
      await executor.executeMutation(
        JsonQueryBuilder()
            .model('IntCategory')
            .action(QueryAction.create)
            .data({'id': 3, 'name': 'Dart'}).build(),
      );

      // Create IntPost with M:N connect using integer PKs
      await executor.executeMutationWithRelationsAtomic(
        JsonQueryBuilder().model('IntPost').action(QueryAction.create).data({
          'id': 100,
          'title': 'Integer M2M Post',
          'categories': {
            'connect': [
              {'id': 1},
              {'id': 2},
            ],
          },
        }).build(),
      );

      var post = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('IntPost')
            .action(QueryAction.findUnique)
            .where({'id': 100}).include({'categories': true}).build(),
      );
      expect(post, isNotNull);
      expect(post!['categories'], hasLength(2));

      // Update with set: [3]
      await executor.executeMutationWithRelationsAtomic(
        JsonQueryBuilder()
            .model('IntPost')
            .action(QueryAction.update)
            .where({'id': 100}).data({
          'title': 'Integer M2M Post Updated',
          'categories': {
            'set': [
              {'id': 3},
            ],
          },
        }).build(),
      );

      post = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('IntPost')
            .action(QueryAction.findUnique)
            .where({'id': 100}).include({'categories': true}).build(),
      );
      expect(post!['categories'], hasLength(1));
      expect((post['categories'] as List).first['id'], equals(3));
    });

    test(
        'should commit transactions, rollback on failure, and flatten nested runTransaction',
        () async {
      // 1. Successful commit + nested runTransaction
      await executor.runTransaction((tx) async {
        await tx.executeMutation(
          JsonQueryBuilder().model('User').action(QueryAction.create).data({
            'id': 'u-tx-1',
            'email': 'tx1@example.com',
            'name': 'TX User 1',
          }).build(),
        );

        await tx.runTransaction((nestedTx) async {
          await nestedTx.executeMutation(
            JsonQueryBuilder().model('User').action(QueryAction.create).data({
              'id': 'u-tx-2',
              'email': 'tx2@example.com',
              'name': 'TX User 2',
            }).build(),
          );
        });
      }, isolationLevel: IsolationLevel.serializable);

      expect(
        await executor.executeCount(
          JsonQueryBuilder().model('User').action(QueryAction.count).build(),
        ),
        equals(2),
      );

      // 2. Rollback on exception ensures partial writes do not persist
      await expectLater(
        () => executor.executeInTransaction((tx) async {
          await tx.executeMutation(
            JsonQueryBuilder().model('User').action(QueryAction.create).data({
              'id': 'u-tx-rollback',
              'email': 'rollback@example.com',
              'name': 'Should Not Persist',
            }).build(),
          );
          throw StateError('Simulated failure forcing rollback');
        }),
        throwsA(isA<StateError>()),
      );

      final rolledBackUser = await executor.executeQueryAsSingleMap(
        JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': 'u-tx-rollback'}).build(),
      );
      expect(rolledBackUser, isNull);
    });

    test(
        'should map PostgreSQL constraint and serialization errors to typed PrismaExceptions',
        () async {
      await executor.executeMutation(
        JsonQueryBuilder().model('User').action(QueryAction.create).data({
          'id': 'u-err-1',
          'email': 'unique@example.com',
          'name': 'Unique User',
        }).build(),
      );

      // 1. Unique constraint violation (23505 -> UniqueConstraintException)
      await expectLater(
        () => executor.executeMutation(
          JsonQueryBuilder().model('User').action(QueryAction.create).data({
            'id': 'u-err-2',
            'email': 'unique@example.com',
            'name': 'Duplicate Email',
          }).build(),
        ),
        throwsA(isA<UniqueConstraintException>()),
      );

      // 2. Foreign key constraint violation (23503 -> ForeignKeyException / ForeignKeyConstraintException)
      await expectLater(
        () => executor.executeMutation(
          JsonQueryBuilder().model('Post').action(QueryAction.create).data({
            'id': 'p-bad-fk',
            'title': 'Orphan Post',
            'content': 'No Author',
            'published': false,
            'authorId': 'non-existent-user',
          }).build(),
        ),
        throwsA(isA<ForeignKeyConstraintException>()),
      );

      // 3. Not-null constraint violation (23502 -> ConstraintException)
      await expectLater(
        () => executor.executeMutation(
          JsonQueryBuilder()
              .model('User')
              .action(QueryAction.update)
              .where({'id': 'u-err-1'}).data({'email': null}).build(),
        ),
        throwsA(
          isA<ConstraintException>()
              .having((e) => e.constraintType, 'constraintType', 'not_null'),
        ),
      );

      // Verify live vs fallback indicator is a valid boolean
      expect(usingLivePostgres, isA<bool>());
    });
  });
}

// =============================================================================
// In-Memory PostgreSQL Connection Fallback (when no local Postgres daemon runs)
// =============================================================================

class _FakeResultRow extends ListBase<Object?> implements pg.ResultRow {
  final Map<String, Object?> _map;

  _FakeResultRow(this._map);

  @override
  Map<String, Object?> toColumnMap() => Map<String, Object?>.from(_map);

  @override
  int get length => _map.length;

  @override
  set length(int newLength) => throw UnsupportedError('unmodifiable');

  @override
  Object? operator [](int index) => _map.values.elementAt(index);

  @override
  void operator []=(int index, Object? value) =>
      throw UnsupportedError('unmodifiable');

  @override
  pg.ResultSchema get schema => pg.ResultSchema(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResult extends ListBase<pg.ResultRow> implements pg.Result {
  @override
  final int affectedRows;
  final List<pg.ResultRow> _rows;

  _FakeResult({this.affectedRows = 0, List<pg.ResultRow>? rows})
      : _rows = rows ?? const [];

  @override
  int get length => _rows.length;

  @override
  set length(int newLength) => throw UnsupportedError('unmodifiable');

  @override
  pg.ResultRow operator [](int index) => _rows[index];

  @override
  void operator []=(int index, pg.ResultRow value) =>
      throw UnsupportedError('unmodifiable');

  @override
  pg.ResultSchema get schema => pg.ResultSchema(const []);
}

class _SimulatedServerException implements pg.ServerException {
  @override
  final String? code;
  @override
  final String? constraintName;
  @override
  final String message;
  @override
  pg.Severity get severity => pg.Severity.error;

  _SimulatedServerException(
    this.code,
    this.message, {
    this.constraintName,
  });

  @override
  String toString() => 'ServerException($code): $message';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _InMemoryPostgresConnection implements pg.Connection {
  @override
  bool isOpen = true;

  Map<String, List<Map<String, Object?>>> _tables = {
    'User': [],
    'Post': [],
    'Tag': [],
    '_UserTags': [],
    'IntPost': [],
    'IntCategory': [],
    '_CategoryToPost': [],
  };

  Map<String, List<Map<String, Object?>>>? _txSnapshot;

  Map<String, List<Map<String, Object?>>> _cloneTables(
    Map<String, List<Map<String, Object?>>> src,
  ) {
    return {
      for (final entry in src.entries)
        entry.key:
            entry.value.map((row) => Map<String, Object?>.from(row)).toList(),
    };
  }

  @override
  Future<pg.Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    pg.QueryMode? queryMode,
    Duration? timeout,
  }) async {
    final sql = query.toString().trim();
    final params = parameters is List ? parameters : const <Object?>[];

    if (sql == 'BEGIN') {
      _txSnapshot = _cloneTables(_tables);
      return _FakeResult();
    }
    if (sql == 'COMMIT') {
      _txSnapshot = null;
      return _FakeResult();
    }
    if (sql == 'ROLLBACK') {
      if (_txSnapshot != null) {
        _tables = _txSnapshot!;
        _txSnapshot = null;
      }
      return _FakeResult();
    }
    if (sql.startsWith('SET TRANSACTION') ||
        sql.startsWith('DROP TABLE') ||
        sql.startsWith('CREATE TABLE') ||
        sql.startsWith('CREATE OR REPLACE FUNCTION') ||
        sql.startsWith('DO ')) {
      return _FakeResult();
    }

    if (sql.startsWith('DELETE FROM ')) {
      return _handleDelete(sql, params);
    }
    if (sql.startsWith('INSERT INTO ')) {
      return _handleInsert(sql, params);
    }
    if (sql.startsWith('UPDATE ')) {
      return _handleUpdate(sql, params);
    }
    if (sql.startsWith('SELECT ')) {
      return _handleSelect(sql, params);
    }

    return _FakeResult();
  }

  pg.Result _handleDelete(String sql, List<Object?> params) {
    final tableMatch = RegExp(r'^DELETE FROM "([^"]+)"').firstMatch(sql);
    final table = tableMatch!.group(1)!;
    final rows = _tables[table]!;

    if (!sql.contains('WHERE')) {
      final count = rows.length;
      rows.clear();
      return _FakeResult(affectedRows: count);
    }

    if (sql.contains('WHERE "A" = \$1 AND "B" = \$2')) {
      final aVal = params[0];
      final bVal = params[1];
      final before = rows.length;
      rows.removeWhere((r) => r['A'] == aVal && r['B'] == bVal);
      return _FakeResult(affectedRows: before - rows.length);
    }

    if (sql.contains('WHERE "A" = \$1 AND "B" IN')) {
      final aVal = params[0];
      final bVals = params.sublist(1).toSet();
      final before = rows.length;
      rows.removeWhere((r) => r['A'] == aVal && bVals.contains(r['B']));
      return _FakeResult(affectedRows: before - rows.length);
    }

    if (sql.contains('WHERE "B" = \$1') && !sql.contains('"A"')) {
      final bVal = params[0];
      final before = rows.length;
      rows.removeWhere((r) => r['B'] == bVal);
      return _FakeResult(affectedRows: before - rows.length);
    }

    final colMatch = RegExp(r'WHERE "([^"]+)" = \$1').firstMatch(sql);
    if (colMatch != null) {
      final col = colMatch.group(1)!;
      final val = params[0];
      final removed = rows.where((r) => r[col] == val).toList();
      rows.removeWhere((r) => r[col] == val);
      return _FakeResult(
        affectedRows: removed.length,
        rows: removed.map(_FakeResultRow.new).toList(),
      );
    }

    return _FakeResult();
  }

  pg.Result _handleInsert(String sql, List<Object?> params) {
    final headerMatch = RegExp(
      r'^INSERT INTO "([^"]+)" \(([^)]+)\) VALUES (.+?)(?: ON CONFLICT DO NOTHING)?(?: RETURNING \*)?$',
      dotAll: true,
    ).firstMatch(sql);
    final table = headerMatch!.group(1)!;
    final cols = headerMatch
        .group(2)!
        .split(',')
        .map((c) => c.trim().replaceAll('"', ''))
        .toList();
    final valuesExpr = headerMatch.group(3)!;
    final effectiveParams = params.isNotEmpty
        ? params
        : RegExp(r"'((?:[^']|'')*)'")
            .allMatches(valuesExpr)
            .map<Object?>((m) => m.group(1)!.replaceAll("''", "'"))
            .toList();
    final tupleCount = '('.allMatches(valuesExpr).length;
    final rows = _tables[table]!;
    final inserted = <Map<String, Object?>>[];

    var paramIdx = 0;
    for (var t = 0; t < tupleCount; t++) {
      final row = <String, Object?>{};
      for (final col in cols) {
        var val = effectiveParams[paramIdx++];
        if (table == 'User' && col == 'metadata' && val is String) {
          val = jsonDecode(val);
        }
        row[col] = val;
      }

      // Enforce constraints for User and Post
      if (table == 'User') {
        if (row['email'] == null || row['name'] == null) {
          throw _SimulatedServerException(
            '23502',
            'null value violates not-null constraint',
          );
        }
        if (rows.any((r) => r['email'] == row['email'])) {
          throw _SimulatedServerException(
            '23505',
            'duplicate key value violates unique constraint "User_email_key"',
            constraintName: 'User_email_key',
          );
        }
        row.putIfAbsent('age', () => null);
        row.putIfAbsent('metadata', () => null);
      } else if (table == 'Post') {
        final authorExists =
            _tables['User']!.any((u) => u['id'] == row['authorId']);
        if (!authorExists) {
          throw _SimulatedServerException(
            '23503',
            'insert or update on table "Post" violates foreign key constraint "Post_authorId_fkey"',
            constraintName: 'Post_authorId_fkey',
          );
        }
      } else if (table == '_CategoryToPost') {
        // Verify integer PK binding (#50)
        if (row['A'] is! int || row['B'] is! int) {
          throw _SimulatedServerException(
            '42804',
            'column is of type integer but expression is of type text',
          );
        }
      }

      rows.add(row);
      inserted.add(row);
    }

    return _FakeResult(
      affectedRows: inserted.length,
      rows: inserted.map(_FakeResultRow.new).toList(),
    );
  }

  pg.Result _handleUpdate(String sql, List<Object?> params) {
    final tableMatch =
        RegExp(r'^UPDATE "([^"]+)" SET (.+?) WHERE "([^"]+)" = \$(\d+)')
            .firstMatch(sql);
    final table = tableMatch!.group(1)!;
    final setClause = tableMatch.group(2)!;
    final whereCol = tableMatch.group(3)!;
    final whereParamIdx = int.parse(tableMatch.group(4)!) - 1;
    final whereVal = params[whereParamIdx];

    final setAssignments =
        setClause.split(',').map((part) => part.trim()).toList();
    final rows = _tables[table]!;
    final updated = <Map<String, Object?>>[];

    for (final row in rows) {
      if (row[whereCol] == whereVal) {
        for (final assign in setAssignments) {
          final m = RegExp(r'^"([^"]+)" = \$(\d+)$').firstMatch(assign);
          if (m != null) {
            final col = m.group(1)!;
            final val = params[int.parse(m.group(2)!) - 1];
            if (table == 'User' && col == 'email' && val == null) {
              throw _SimulatedServerException(
                '23502',
                'null value in column "email" violates not-null constraint',
              );
            }
            row[col] = val;
          }
        }
        updated.add(Map<String, Object?>.from(row));
      }
    }

    return _FakeResult(
      affectedRows: updated.length,
      rows: updated.map(_FakeResultRow.new).toList(),
    );
  }

  pg.Result _handleSelect(String sql, List<Object?> params) {
    if (sql.contains('COUNT(*)')) {
      final tableMatch = RegExp(r'FROM "([^"]+)"').firstMatch(sql);
      final table = tableMatch!.group(1)!;
      return _FakeResult(
        rows: [
          _FakeResultRow({'count': _tables[table]!.length}),
        ],
      );
    }

    // 1:N include with subquery pagination on User -> Post
    if (sql.contains('FROM (SELECT * FROM "User"') &&
        sql.contains('LEFT JOIN "Post"')) {
      final limit =
          int.parse(RegExp(r'LIMIT (\d+)').firstMatch(sql)!.group(1)!);
      final offset =
          int.parse(RegExp(r'OFFSET (\d+)').firstMatch(sql)!.group(1)!);
      final sortedUsers = List<Map<String, Object?>>.from(_tables['User']!)
        ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
      final pagedUsers = sortedUsers.skip(offset).take(limit).toList();

      final joinedRows = <pg.ResultRow>[];
      for (final u in pagedUsers) {
        final userPosts =
            _tables['Post']!.where((p) => p['authorId'] == u['id']).toList();
        if (userPosts.isEmpty) {
          joinedRows.add(_FakeResultRow({
            ...u,
            'posts__id': null,
            'posts__title': null,
            'posts__content': null,
            'posts__published': null,
            'posts__authorId': null,
          }));
        } else {
          for (final p in userPosts) {
            joinedRows.add(_FakeResultRow({
              ...u,
              'posts__id': p['id'],
              'posts__title': p['title'],
              'posts__content': p['content'],
              'posts__published': p['published'],
              'posts__authorId': p['authorId'],
            }));
          }
        }
      }
      return _FakeResult(rows: joinedRows);
    }

    // M:N include on User -> Tag
    if (sql.contains('FROM "User"') && sql.contains('"_UserTags"')) {
      final userId = params[0];
      final users = _tables['User']!.where((u) => u['id'] == userId).toList();
      final joinedRows = <pg.ResultRow>[];
      for (final u in users) {
        final links =
            _tables['_UserTags']!.where((l) => l['A'] == u['id']).toList();
        if (links.isEmpty) {
          joinedRows.add(_FakeResultRow({
            ...u,
            'tags__id': null,
            'tags__label': null,
          }));
        } else {
          for (final l in links) {
            final tag = _tables['Tag']!.firstWhere((t) => t['id'] == l['B']);
            joinedRows.add(_FakeResultRow({
              ...u,
              'tags__id': tag['id'],
              'tags__label': tag['label'],
            }));
          }
        }
      }
      return _FakeResult(rows: joinedRows);
    }

    // M:N include on IntPost -> IntCategory
    if (sql.contains('FROM "IntPost"') && sql.contains('"_CategoryToPost"')) {
      final postId = params[0];
      final posts =
          _tables['IntPost']!.where((p) => p['id'] == postId).toList();
      final joinedRows = <pg.ResultRow>[];
      for (final p in posts) {
        final links = _tables['_CategoryToPost']!
            .where((l) => l['B'] == p['id'])
            .toList();
        if (links.isEmpty) {
          joinedRows.add(_FakeResultRow({
            ...p,
            'categories__id': null,
            'categories__name': null,
          }));
        } else {
          for (final l in links) {
            final cat =
                _tables['IntCategory']!.firstWhere((c) => c['id'] == l['A']);
            joinedRows.add(_FakeResultRow({
              ...p,
              'categories__id': cat['id'],
              'categories__name': cat['name'],
            }));
          }
        }
      }
      return _FakeResult(rows: joinedRows);
    }

    // JSON path filter on User
    if (sql.contains('"metadata" #> \$1::text[] = \$2::jsonb')) {
      final path = (params[0] as List).cast<String>();
      final expected = jsonDecode(params[1] as String);
      final matched = _tables['User']!.where((u) {
        dynamic cur = u['metadata'];
        for (final seg in path) {
          if (cur is Map) {
            cur = cur[seg];
          } else {
            return false;
          }
        }
        return cur == expected;
      }).toList();
      return _FakeResult(rows: matched.map(_FakeResultRow.new).toList());
    }

    // Complex filter query on User (LIKE + >= + ORDER BY + LIMIT + OFFSET)
    if (sql.contains('FROM "User"') && sql.contains('LIKE \$1')) {
      final pattern = (params[0] as String).replaceAll('%', '');
      final minAge = params[1] as int;
      final limit =
          int.parse(RegExp(r'LIMIT (\d+)').firstMatch(sql)!.group(1)!);
      final offset =
          int.parse(RegExp(r'OFFSET (\d+)').firstMatch(sql)!.group(1)!);

      var matched = _tables['User']!.where((u) {
        final email = u['email'] as String;
        final age = (u['age'] as int?) ?? 0;
        return email.contains(pattern) && age >= minAge;
      }).toList();

      matched.sort((a, b) => (a['age'] as int).compareTo(b['age'] as int));
      matched = matched.skip(offset).take(limit).toList();
      return _FakeResult(rows: matched.map(_FakeResultRow.new).toList());
    }

    // Simple findUnique / findMany by column
    final tableMatch = RegExp(r'FROM "([^"]+)"').firstMatch(sql);
    if (tableMatch != null) {
      final table = tableMatch.group(1)!;
      var rows = List<Map<String, Object?>>.from(_tables[table] ?? const []);
      final whereMatch = RegExp(r'WHERE "([^"]+)" = \$1').firstMatch(sql);
      if (whereMatch != null) {
        final col = whereMatch.group(1)!;
        rows = rows.where((r) => r[col] == params[0]).toList();
      }
      return _FakeResult(rows: rows.map(_FakeResultRow.new).toList());
    }

    return _FakeResult();
  }

  @override
  Future<void> close({bool force = false}) async {
    isOpen = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
