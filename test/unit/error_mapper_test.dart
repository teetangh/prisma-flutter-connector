import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/errors/prisma_exceptions.dart';
import 'package:prisma_flutter_connector/src/runtime/logging/query_logger.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';
import 'package:test/test.dart';

/// Fake PostgreSQL [pg.Result] for unit testing [PostgresAdapter] without a live DB.
class _FakePgResult extends ListBase<pg.ResultRow> implements pg.Result {
  @override
  final int affectedRows;
  final List<pg.ResultRow> _rows;

  _FakePgResult({this.affectedRows = 0, List<pg.ResultRow>? rows})
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

/// Fake [pg.Connection] that records executed SQL and parameters, can report
/// [isOpen], and can throw a configured exception (such as [pg.ServerException]).
class _FakePgConnection implements pg.Connection {
  @override
  bool isOpen;

  final List<String> executedSql = [];
  final List<Object?> executedParams = [];
  Object? errorToThrow;
  Object? commitErrorToThrow;
  bool wasClosed = false;

  _FakePgConnection({
    this.isOpen = true,
    this.errorToThrow,
    this.commitErrorToThrow,
  });

  @override
  Future<pg.Result> execute(
    Object query, {
    Object? parameters,
    bool ignoreRows = false,
    pg.QueryMode? queryMode,
    Duration? timeout,
  }) async {
    final sql = query.toString();
    executedSql.add(sql);
    executedParams.add(parameters);

    if (sql == 'COMMIT' && commitErrorToThrow != null) {
      throw commitErrorToThrow!;
    }
    if (sql != 'BEGIN' &&
        sql != 'COMMIT' &&
        sql != 'ROLLBACK' &&
        !sql.startsWith('SET TRANSACTION') &&
        errorToThrow != null) {
      throw errorToThrow!;
    }
    return _FakePgResult(affectedRows: 1);
  }

  @override
  Future<void> close({bool force = false}) async {
    wasClosed = true;
    isOpen = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake [pg.ServerException] with configurable SQLSTATE [code] and [constraintName].
class _FakeServerException implements pg.ServerException {
  @override
  final String? code;

  @override
  final String? constraintName;

  @override
  final String message;

  @override
  pg.Severity get severity => pg.Severity.error;

  _FakeServerException({
    required this.code,
    required this.message,
    this.constraintName,
  });

  @override
  String toString() => 'ServerException($code): $message';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Recording [QueryLogger] to verify that all executor operations emit events.
class _RecordingQueryLogger implements QueryLogger {
  final List<QueryStartEvent> starts = [];
  final List<QueryEndEvent> ends = [];
  final List<QueryErrorEvent> errors = [];

  @override
  void onQueryStart(QueryStartEvent event) => starts.add(event);

  @override
  void onQueryEnd(QueryEndEvent event) => ends.add(event);

  @override
  void onQueryError(QueryErrorEvent event) => errors.add(event);
}

void main() {
  group('PostgresAdapter & QueryExecutor Error Mapping', () {
    test('maps SQLSTATE 23505 to UniqueConstraintException in executeMutation', () async {
      final conn = _FakePgConnection(
        errorToThrow: _FakeServerException(
          code: '23505',
          message: 'duplicate key value violates unique constraint "users_email_key"',
          constraintName: 'users_email_key',
        ),
      );
      final logger = _RecordingQueryLogger();
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter, logger: logger);

      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.create)
          .data({'email': 'dup@example.com'})
          .build();

      await expectLater(
        () => executor.executeMutation(query),
        throwsA(
          isA<UniqueConstraintException>()
              .having((e) => e.code, 'code', 'P2002')
              .having((e) => e.constraintName, 'constraintName', 'users_email_key'),
        ),
      );
      expect(logger.starts, hasLength(1));
      expect(logger.errors, hasLength(1));
    });

    test('maps SQLSTATE 23503 to ForeignKeyException / ForeignKeyConstraintException', () async {
      final conn = _FakePgConnection(
        errorToThrow: _FakeServerException(
          code: '23503',
          message: 'insert or update on table "posts" violates foreign key constraint "posts_author_id_fkey"',
          constraintName: 'posts_author_id_fkey',
        ),
      );
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter);

      final query = JsonQueryBuilder()
          .model('Post')
          .action(QueryAction.update)
          .where({'id': 'p1'})
          .data({'authorId': 'missing-user'})
          .build();

      await expectLater(
        () => executor.executeMutationAsMap(query),
        throwsA(
          isA<ForeignKeyConstraintException>()
              .having((e) => e.code, 'code', 'P2003')
              .having((e) => e.constraintName, 'constraintName', 'posts_author_id_fkey'),
        ),
      );
    });

    test('maps SQLSTATE 23502 to ConstraintException (not_null)', () async {
      final conn = _FakePgConnection(
        errorToThrow: _FakeServerException(
          code: '23502',
          message: 'null value in column "email" violates not-null constraint',
        ),
      );
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter);

      final query = JsonQueryBuilder()
          .model('User')
          .action(QueryAction.update)
          .where({'id': 'u1'})
          .data({'email': null})
          .build();

      await expectLater(
        () => executor.executeMutation(query),
        throwsA(
          isA<ConstraintException>()
              .having((e) => e.code, 'code', 'P2004')
              .having((e) => e.constraintType, 'constraintType', 'not_null'),
        ),
      );
    });

    test('maps SQLSTATE 40001 (serialization failure) to TransactionException', () async {
      final conn = _FakePgConnection(
        errorToThrow: _FakeServerException(
          code: '40001',
          message: 'could not serialize access due to concurrent update',
        ),
      );
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter);

      await expectLater(
        () => executor.executeInTransaction((tx) async {
          final q = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.update)
              .where({'id': 'u1'})
              .data({'name': 'Concurrent'})
              .build();
          await tx.executeMutation(q);
        }),
        throwsA(
          isA<TransactionException>().having((e) => e.code, 'code', 'P2034'),
        ),
      );
    });

    test('maps SQLSTATE 40001 on transaction commit to TransactionException', () async {
      final conn = _FakePgConnection(
        commitErrorToThrow: _FakeServerException(
          code: '40001',
          message: 'could not serialize access due to read/write dependencies among transactions',
        ),
      );
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter);

      await expectLater(
        () => executor.executeInTransaction((tx) async {
          final q = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .build();
          await tx.executeQueryAsMaps(q);
        }),
        throwsA(
          isA<TransactionException>().having((e) => e.code, 'code', 'P2034'),
        ),
      );
    });

    test('maps errors in TransactionExecutor.executeMutationAsMap and executeRaw', () async {
      final conn = _FakePgConnection(
        errorToThrow: _FakeServerException(
          code: '23505',
          message: 'duplicate key value violates unique constraint',
        ),
      );
      final logger = _RecordingQueryLogger();
      final adapter = PostgresAdapter(conn);
      final executor = QueryExecutor(adapter: adapter, logger: logger);

      await expectLater(
        () => executor.executeInTransaction((tx) async {
          final q = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.create)
              .data({'email': 'tx@example.com'})
              .build();
          await tx.executeMutationAsMap(q);
        }),
        throwsA(isA<UniqueConstraintException>()),
      );
      expect(logger.errors, hasLength(1));
    });
  });

  group('PostgresAdapter Hardening', () {
    test('encodes ArgType.json Map and List values via jsonEncode instead of toString', () async {
      final conn = _FakePgConnection();
      final adapter = PostgresAdapter(conn);

      final payloadMap = {'theme': 'dark', 'count': 3, 'nested': ['a', 'b']};
      final payloadList = [
        {'k': 'v'},
        42,
      ];

      await adapter.executeRaw(SqlQuery(
        sql: 'INSERT INTO "events" ("meta", "items") VALUES (\$1, \$2)',
        args: [payloadMap, payloadList],
        argTypes: [ArgType.json, ArgType.json],
      ));

      expect(conn.executedParams, hasLength(1));
      final params = conn.executedParams.first as List<dynamic>;
      expect(params[0], equals(jsonEncode(payloadMap)));
      expect(jsonDecode(params[0] as String), equals(payloadMap));
      expect(params[1], equals(jsonEncode(payloadList)));
      expect(jsonDecode(params[1] as String), equals(payloadList));
    });

    test('_ensureConnected does not execute SELECT 1 when connection is open', () async {
      final conn = _FakePgConnection(isOpen: true);
      var factoryCalls = 0;
      final adapter = PostgresAdapter(
        conn,
        connectionFactory: () async {
          factoryCalls++;
          return _FakePgConnection(isOpen: true);
        },
      );

      await adapter.queryRaw(const SqlQuery(
        sql: 'SELECT * FROM "users"',
        args: [],
        argTypes: [],
      ));
      await adapter.executeRaw(const SqlQuery(
        sql: 'DELETE FROM "users" WHERE "id" = \$1',
        args: ['u1'],
        argTypes: [ArgType.string],
      ));

      expect(conn.executedSql, isNot(contains('SELECT 1')));
      expect(conn.executedSql, hasLength(2));
      expect(factoryCalls, equals(0));
    });

    test('_ensureConnected reconnects via connectionFactory when connection is closed', () async {
      final deadConn = _FakePgConnection(isOpen: false);
      final freshConn = _FakePgConnection(isOpen: true);
      var factoryCalls = 0;
      final adapter = PostgresAdapter(
        deadConn,
        connectionFactory: () async {
          factoryCalls++;
          return freshConn;
        },
      );

      await adapter.queryRaw(const SqlQuery(
        sql: 'SELECT * FROM "users"',
        args: [],
        argTypes: [],
      ));

      expect(factoryCalls, equals(1));
      expect(deadConn.wasClosed, isTrue);
      expect(freshConn.executedSql, equals(['SELECT * FROM "users"']));
    });

    test('executeScript ignores semicolons inside single quotes and dollar-quoted blocks', () async {
      final conn = _FakePgConnection();
      final adapter = PostgresAdapter(conn);

      const script = '''
INSERT INTO "notes" ("body") VALUES ('first;part;still_string');
INSERT INTO "notes" ("body") VALUES ('escaped ''quote;inside'' literal');
CREATE OR REPLACE FUNCTION notify_trigger() RETURNS trigger AS \$\$
BEGIN
  PERFORM pg_notify('chan', 'payload;with;semicolons');
  RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION tagged_fn() RETURNS int AS \$body\$
DECLARE
  v int := 1;
BEGIN
  RETURN v;
END;
\$body\$ LANGUAGE plpgsql;
SELECT 1;
''';

      await adapter.executeScript(script);

      expect(conn.executedSql, hasLength(5));
      expect(
        conn.executedSql[0],
        equals('INSERT INTO "notes" ("body") VALUES (\'first;part;still_string\')'),
      );
      expect(
        conn.executedSql[1],
        equals('INSERT INTO "notes" ("body") VALUES (\'escaped \'\'quote;inside\'\' literal\')'),
      );
      expect(conn.executedSql[2], contains('PERFORM pg_notify(\'chan\', \'payload;with;semicolons\');'));
      expect(conn.executedSql[2], endsWith(r'$$ LANGUAGE plpgsql'));
      expect(conn.executedSql[3], contains(r'$body$'));
      expect(conn.executedSql[3], endsWith(r'$body$ LANGUAGE plpgsql'));
      expect(conn.executedSql[4], equals('SELECT 1'));
    });

    test('_ensureConnected serializes concurrent reconnects into a single factory call', () async {
      final deadConn = _FakePgConnection(isOpen: false);
      final freshConn = _FakePgConnection(isOpen: true);
      var factoryCalls = 0;
      final adapter = PostgresAdapter(
        deadConn,
        connectionFactory: () async {
          factoryCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return freshConn;
        },
      );

      await Future.wait([
        adapter.queryRaw(const SqlQuery(
          sql: 'SELECT 1',
          args: [],
          argTypes: [],
        )),
        adapter.queryRaw(const SqlQuery(
          sql: 'SELECT 2',
          args: [],
          argTypes: [],
        )),
      ]);

      expect(factoryCalls, equals(1));
      expect(freshConn.executedSql, containsAll(['SELECT 1', 'SELECT 2']));
    });

    test('splitSqlStatements handles E-escaped strings and dollar signs in identifiers', () {
      const script = r"""
INSERT INTO "notes" ("body") VALUES (E'backslash \'quote;inside\' literal');
SELECT col$tag$1 FROM "tbl";
SELECT 'still;one;statement';
""";
      final statements = PostgresAdapter.splitSqlStatements(script);
      expect(statements, hasLength(3));
      expect(
        statements[0],
        equals(r'''INSERT INTO "notes" ("body") VALUES (E'backslash \'quote;inside\' literal')'''),
      );
      expect(statements[1], equals(r'SELECT col$tag$1 FROM "tbl"'));
      expect(statements[2], equals("SELECT 'still;one;statement'"));
    });
  });
}
