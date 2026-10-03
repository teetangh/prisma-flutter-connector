import 'package:prisma_flutter_connector/runtime.dart';
import 'package:test/test.dart';

/// Duck-typed sqflite-style executor for testing the dynamic bridge.
class _FakeSqfliteTransaction {
  final List<String> log;
  _FakeSqfliteTransaction(this.log);

  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    log.add('txn.rawQuery: $sql | $arguments');
    return [
      {'id': 'u1', 'name': 'Alice'},
    ];
  }

  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    log.add('txn.rawInsert: $sql | $arguments');
    return 1;
  }

  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    log.add('txn.rawUpdate: $sql | $arguments');
    return 2;
  }

  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    log.add('txn.rawDelete: $sql | $arguments');
    return 3;
  }

  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    log.add('txn.execute: $sql');
  }
}

class _FakeSqfliteDatabase extends _FakeSqfliteTransaction {
  bool committed = false;
  bool rolledBack = false;
  bool closed = false;

  _FakeSqfliteDatabase() : super([]);

  Future<T> transaction<T>(
    Future<T> Function(dynamic txn) action,
  ) async {
    log.add('BEGIN');
    try {
      final res = await action(_FakeSqfliteTransaction(log));
      committed = true;
      log.add('COMMIT');
      return res;
    } catch (e) {
      rolledBack = true;
      log.add('ROLLBACK');
      rethrow;
    }
  }

  Future<void> close() async {
    closed = true;
  }
}

void main() {
  group('SQLiteAdapter (#41, #42, #62)', () {
    test(
        'dispatches INSERT/UPDATE through rawUpdate (affected rows) and DELETE through rawDelete',
        () async {
      final db = _FakeSqfliteDatabase();
      final adapter = SQLiteAdapter(db);

      final insertRes = await adapter.executeRaw(
        const SqlQuery(
          sql: 'INSERT INTO "User" ("id", "name") VALUES (\$1, \$2)',
          args: ['u1', 'Alice'],
          argTypes: [ArgType.string, ArgType.string],
        ),
      );
      final updateRes = await adapter.executeRaw(
        const SqlQuery(
          sql: 'UPDATE "User" SET "name" = \$1 WHERE "id" = \$2',
          args: ['Bob', 'u1'],
          argTypes: [ArgType.string, ArgType.string],
        ),
      );
      final deleteRes = await adapter.executeRaw(
        const SqlQuery(
          sql: 'DELETE FROM "User" WHERE "id" = \$1',
          args: ['u1'],
          argTypes: [ArgType.string],
        ),
      );

      expect(insertRes, 2);
      expect(updateRes, 2);
      expect(deleteRes, 3);
      expect(
        db.log,
        containsAllInOrder([
          'txn.rawUpdate: INSERT INTO "User" ("id", "name") VALUES (?, ?) | [u1, Alice]',
          'txn.rawUpdate: UPDATE "User" SET "name" = ? WHERE "id" = ? | [Bob, u1]',
          'txn.rawDelete: DELETE FROM "User" WHERE "id" = ? | [u1]',
        ]),
      );
    });

    test(
        'executes statements directly inside SQLiteTransaction without deadlocking',
        () async {
      final db = _FakeSqfliteDatabase();
      final adapter = SQLiteAdapter(db);
      final executor = QueryExecutor(adapter: adapter);

      final rows = await executor.executeInTransaction((tx) async {
        final affected = await tx.transaction.executeRaw(
          const SqlQuery(
            sql: 'UPDATE "User" SET "name" = \$1 WHERE "id" = \$2',
            args: ['Alice', 'u1'],
            argTypes: [ArgType.string, ArgType.string],
          ),
        );
        expect(affected, 2);

        final result = await tx.transaction.queryRaw(
          const SqlQuery(
            sql: 'SELECT "id", "name" FROM "User" WHERE "id" = \$1',
            args: ['u1'],
            argTypes: [ArgType.string],
          ),
        );
        return result.rows;
      });

      expect(rows, [
        ['u1', 'Alice'],
      ]);
      expect(db.committed, isTrue);
      expect(db.rolledBack, isFalse);
    });

    test('rolls back SQLiteTransaction cleanly when callback throws', () async {
      final db = _FakeSqfliteDatabase();
      final adapter = SQLiteAdapter(db);
      final executor = QueryExecutor(adapter: adapter);

      await expectLater(
        () => executor.executeInTransaction((tx) async {
          await tx.transaction.executeRaw(
            const SqlQuery(
              sql: 'INSERT INTO "User" ("id") VALUES (\$1)',
              args: ['u1'],
              argTypes: [ArgType.string],
            ),
          );
          throw StateError('abort transaction');
        }),
        throwsA(isA<StateError>()),
      );

      expect(db.committed, isFalse);
      expect(db.rolledBack, isTrue);
    });

    test('supports SQLiteCallbackDatabase and nested SAVEPOINTs in pure Dart',
        () async {
      final statements = <String>[];
      final callbackDb = SQLiteCallbackDatabase(
        onQuery: (sql, args) async {
          statements.add('QUERY: $sql');
          return [
            {'id': '1', 'createdAt': '2026-01-01T00:00:00.000Z'},
          ];
        },
        onExecute: (sql, args) async {
          statements.add('EXEC: $sql');
          return 1;
        },
        onStatement: (sql, args) async {
          statements.add('STMT: $sql');
        },
      );

      final adapter = SQLiteAdapter(callbackDb);
      await adapter.executeScript(
          'CREATE TABLE t1 (id TEXT); CREATE TABLE t2 (id TEXT);');

      await callbackDb.transaction((outerTxn) async {
        await outerTxn.execute('INSERT INTO t1 VALUES ("outer")');
        await callbackDb.transaction((innerTxn) async {
          await innerTxn.execute('INSERT INTO t2 VALUES ("inner")');
        });
      });

      final res = await adapter.queryRaw(
        const SqlQuery(
          sql: 'SELECT * FROM t1 WHERE id = \$1',
          args: ['1'],
          argTypes: [ArgType.string],
        ),
      );

      expect(res.columnNames, ['id', 'createdAt']);
      expect(res.columnTypes, [ColumnType.string, ColumnType.dateTime]);
      expect(
        statements,
        containsAllInOrder([
          'STMT: BEGIN',
          'STMT: CREATE TABLE t1 (id TEXT)',
          'STMT: CREATE TABLE t2 (id TEXT)',
          'STMT: COMMIT',
          'STMT: BEGIN',
          'STMT: INSERT INTO t1 VALUES ("outer")',
          'STMT: SAVEPOINT sp_1',
          'STMT: INSERT INTO t2 VALUES ("inner")',
          'STMT: RELEASE SAVEPOINT sp_1',
          'STMT: COMMIT',
          'QUERY: SELECT * FROM t1 WHERE id = ?',
        ]),
      );
    });
  });
}
