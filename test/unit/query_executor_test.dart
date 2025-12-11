import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/query_executor.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// Mock database adapter for testing.
class MockAdapter implements SqlDriverAdapter {
  final List<SqlQuery> executedQueries = [];
  SqlResultSet? nextQueryResult;
  int nextExecuteResult = 0;
  Exception? shouldThrow;
  MockTransaction? mockTransaction;

  @override
  String get provider => 'postgresql';

  @override
  String get adapterName => 'mock_adapter';

  void setNextQueryResult(SqlResultSet result) {
    nextQueryResult = result;
  }

  void setNextExecuteResult(int count) {
    nextExecuteResult = count;
  }

  void throwOnNextCall(Exception error) {
    shouldThrow = error;
  }

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    executedQueries.add(query);

    if (shouldThrow != null) {
      final error = shouldThrow!;
      shouldThrow = null;
      throw error;
    }

    return nextQueryResult ??
        const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        );
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    executedQueries.add(query);

    if (shouldThrow != null) {
      final error = shouldThrow!;
      shouldThrow = null;
      throw error;
    }

    return nextExecuteResult;
  }

  @override
  Future<void> executeScript(String script) async {}

  @override
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]) async {
    // Return pre-configured mock if set, otherwise create new one
    mockTransaction ??= MockTransaction();
    return mockTransaction!;
  }

  @override
  ConnectionInfo? getConnectionInfo() {
    return const ConnectionInfo(
      schemaName: 'public',
      maxBindValues: 32767,
      supportsRelationJoins: true,
    );
  }

  @override
  Future<void> dispose() async {}
}

/// Mock transaction for testing.
class MockTransaction implements Transaction {
  final List<SqlQuery> executedQueries = [];
  bool committed = false;
  bool rolledBack = false;
  bool _isActive = true;
  SqlResultSet? nextQueryResult;
  int nextExecuteResult = 0;
  Exception? shouldThrow;

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) async {
    executedQueries.add(query);

    if (shouldThrow != null) {
      final error = shouldThrow!;
      shouldThrow = null;
      throw error;
    }

    return nextQueryResult ??
        const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        );
  }

  @override
  Future<int> executeRaw(SqlQuery query) async {
    executedQueries.add(query);

    if (shouldThrow != null) {
      final error = shouldThrow!;
      shouldThrow = null;
      throw error;
    }

    return nextExecuteResult;
  }

  @override
  Future<void> commit() async {
    committed = true;
    _isActive = false;
  }

  @override
  Future<void> rollback() async {
    rolledBack = true;
    _isActive = false;
  }

  @override
  bool get isActive => _isActive;
}

void main() {
  group('QueryExecutor', () {
    late MockAdapter mockAdapter;
    late QueryExecutor executor;

    setUp(() {
      mockAdapter = MockAdapter();
      executor = QueryExecutor(adapter: mockAdapter);
    });

    group('executeQuery', () {
      test('compiles and executes JSON query', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id', 'name'],
          columnTypes: [ColumnType.string, ColumnType.string],
          rows: [
            ['1', 'John'],
            ['2', 'Jane'],
          ],
        ));

        final result = await executor.executeQuery(query);

        expect(mockAdapter.executedQueries.length, 1);
        expect(mockAdapter.executedQueries.first.sql, 'SELECT * FROM "User"');
        expect(result.rows.length, 2);
      });

      test('passes WHERE clause to SQL', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({'email': 'test@example.com'}).build();

        await executor.executeQuery(query);

        expect(mockAdapter.executedQueries.first.sql,
            'SELECT * FROM "User" WHERE "email" = \$1');
        expect(mockAdapter.executedQueries.first.args, ['test@example.com']);
      });
    });

    group('executeMutation', () {
      test('returns 1 for successful CREATE', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'create',
          args: JsonQueryArgs(
            arguments: {
              'data': {'id': '1', 'email': 'test@example.com'},
            },
          ),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id', 'email'],
          columnTypes: [ColumnType.string, ColumnType.string],
          rows: [
            ['1', 'test@example.com']
          ],
        ));

        final result = await executor.executeMutation(query);

        expect(result, 1);
        expect(mockAdapter.executedQueries.first.sql.contains('INSERT'), true);
      });

      test('returns 0 for CREATE with no result', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'create',
          args: JsonQueryArgs(
            arguments: {
              'data': {'id': '1'},
            },
          ),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: [],
          columnTypes: [],
          rows: [],
        ));

        final result = await executor.executeMutation(query);

        expect(result, 0);
      });

      test('returns affected rows for UPDATE', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'update',
          args: JsonQueryArgs(
            arguments: {
              'where': {'id': '1'},
              'data': {'name': 'Updated'},
            },
          ),
        );

        mockAdapter.setNextExecuteResult(1);

        final result = await executor.executeMutation(query);

        expect(result, 1);
      });

      test('returns affected rows for DELETE', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'delete',
          args: JsonQueryArgs(
            arguments: {
              'where': {'id': '1'},
            },
          ),
        );

        mockAdapter.setNextExecuteResult(1);

        final result = await executor.executeMutation(query);

        expect(result, 1);
      });
    });

    group('executeQueryAsMaps', () {
      test('converts result set to list of maps', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id', 'name', 'email'],
          columnTypes: [
            ColumnType.string,
            ColumnType.string,
            ColumnType.string
          ],
          rows: [
            ['1', 'John', 'john@example.com'],
            ['2', 'Jane', 'jane@example.com'],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result.length, 2);
        expect(result[0]['id'], '1');
        expect(result[0]['name'], 'John');
        expect(result[0]['email'], 'john@example.com');
        expect(result[1]['id'], '2');
        expect(result[1]['name'], 'Jane');
      });

      test('returns empty list for empty result', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id'],
          columnTypes: [ColumnType.string],
          rows: [],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result, isEmpty);
      });

      test('converts snake_case columns to camelCase', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['user_id', 'first_name', 'created_at'],
          columnTypes: [
            ColumnType.string,
            ColumnType.string,
            ColumnType.dateTime
          ],
          rows: [
            ['1', 'John', '2024-01-01T00:00:00.000Z'],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0].containsKey('userId'), true);
        expect(result[0].containsKey('firstName'), true);
        expect(result[0].containsKey('createdAt'), true);
        expect(result[0].containsKey('user_id'), false);
      });

      test('deserializes DateTime values', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['created_at'],
          columnTypes: [ColumnType.dateTime],
          rows: [
            ['2024-01-15T10:30:00.000Z'],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0]['createdAt'], isA<DateTime>());
        final date = result[0]['createdAt'] as DateTime;
        expect(date.year, 2024);
        expect(date.month, 1);
        expect(date.day, 15);
      });

      test('handles DateTime objects directly', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        final testDate = DateTime(2024, 3, 15, 12, 0);
        mockAdapter.setNextQueryResult(SqlResultSet(
          columnNames: const ['created_at'],
          columnTypes: const [ColumnType.dateTime],
          rows: [
            [testDate],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0]['createdAt'], testDate);
      });

      test('deserializes date values', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['birth_date'],
          columnTypes: [ColumnType.date],
          rows: [
            ['1990-05-20'],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0]['birthDate'], isA<DateTime>());
      });

      test('converts SQLite boolean (int to bool)', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['is_active'],
          columnTypes: [ColumnType.boolean],
          rows: [
            [1],
            [0],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0]['isActive'], true);
        expect(result[1]['isActive'], false);
      });

      test('handles null values', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id', 'name', 'bio'],
          columnTypes: [
            ColumnType.string,
            ColumnType.string,
            ColumnType.string
          ],
          rows: [
            ['1', 'John', null],
          ],
        ));

        final result = await executor.executeQueryAsMaps(query);

        expect(result[0]['bio'], isNull);
      });
    });

    group('executeQueryAsSingleMap', () {
      test('returns first result when multiple exist', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': '1'}).build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id', 'name'],
          columnTypes: [ColumnType.string, ColumnType.string],
          rows: [
            ['1', 'John'],
          ],
        ));

        final result = await executor.executeQueryAsSingleMap(query);

        expect(result, isNotNull);
        expect(result!['id'], '1');
        expect(result['name'], 'John');
      });

      test('returns null for empty result', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': 'nonexistent'}).build();

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['id'],
          columnTypes: [ColumnType.string],
          rows: [],
        ));

        final result = await executor.executeQueryAsSingleMap(query);

        expect(result, isNull);
      });
    });

    group('executeCount', () {
      test('returns count as int', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'count',
          args: JsonQueryArgs(),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['count'],
          columnTypes: [ColumnType.int64],
          rows: [
            [42],
          ],
        ));

        final result = await executor.executeCount(query);

        expect(result, 42);
      });

      test('returns count from string', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'count',
          args: JsonQueryArgs(),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['count'],
          columnTypes: [ColumnType.string],
          rows: [
            ['100'],
          ],
        ));

        final result = await executor.executeCount(query);

        expect(result, 100);
      });

      test('returns 0 for empty result', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'count',
          args: JsonQueryArgs(),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['count'],
          columnTypes: [ColumnType.int64],
          rows: [],
        ));

        final result = await executor.executeCount(query);

        expect(result, 0);
      });

      test('returns count with WHERE clause', () async {
        const query = JsonQuery(
          modelName: 'User',
          action: 'count',
          args: JsonQueryArgs(
            arguments: {
              'where': {'status': 'active'},
            },
          ),
        );

        mockAdapter.setNextQueryResult(const SqlResultSet(
          columnNames: ['count'],
          columnTypes: [ColumnType.int64],
          rows: [
            [15],
          ],
        ));

        final result = await executor.executeCount(query);

        expect(result, 15);
        expect(mockAdapter.executedQueries.first.sql.contains('WHERE'), true);
      });
    });

    group('executeInTransaction', () {
      test('commits transaction on success', () async {
        final result = await executor.executeInTransaction((tx) async {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .build();
          await tx.executeQuery(query);
          return 'success';
        });

        expect(result, 'success');
        expect(mockAdapter.mockTransaction!.committed, true);
        expect(mockAdapter.mockTransaction!.rolledBack, false);
      });

      test('rolls back transaction on error', () async {
        // Pre-configure the error before starting transaction
        final txMock = MockTransaction();
        txMock.shouldThrow = Exception('Database error');
        mockAdapter.mockTransaction = txMock;

        try {
          await executor.executeInTransaction((tx) async {
            final query = JsonQueryBuilder()
                .model('User')
                .action(QueryAction.findMany)
                .build();
            await tx.executeQuery(query);
            return 'success';
          });
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        expect(mockAdapter.mockTransaction!.rolledBack, true);
        expect(mockAdapter.mockTransaction!.committed, false);
      });

      test('executes multiple queries in transaction', () async {
        await executor.executeInTransaction((tx) async {
          const query1 = JsonQuery(
            modelName: 'User',
            action: 'create',
            args: JsonQueryArgs(
              arguments: {
                'data': {'email': 'test@example.com'},
              },
            ),
          );

          const query2 = JsonQuery(
            modelName: 'Profile',
            action: 'create',
            args: JsonQueryArgs(
              arguments: {
                'data': {'userId': '1'},
              },
            ),
          );

          await tx.executeMutation(query1);
          await tx.executeMutation(query2);
          return null;
        });

        expect(mockAdapter.mockTransaction!.executedQueries.length, 2);
        expect(mockAdapter.mockTransaction!.committed, true);
      });
    });

    group('TransactionExecutor', () {
      test('executeQueryAsMaps works within transaction', () async {
        // Pre-configure the mock transaction before executor uses it
        final txMock = MockTransaction();
        txMock.nextQueryResult = const SqlResultSet(
          columnNames: ['id', 'name'],
          columnTypes: [ColumnType.string, ColumnType.string],
          rows: [
            ['1', 'John'],
          ],
        );
        mockAdapter.mockTransaction = txMock;

        List<Map<String, dynamic>>? result;

        await executor.executeInTransaction((tx) async {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .build();
          result = await tx.executeQueryAsMaps(query);
          return null;
        });

        expect(result, isNotNull);
        expect(result!.length, 1);
        expect(result![0]['id'], '1');
        expect(result![0]['name'], 'John');
      });

      test('executeQueryAsSingleMap works within transaction', () async {
        final txMock = MockTransaction();
        txMock.nextQueryResult = const SqlResultSet(
          columnNames: ['id'],
          columnTypes: [ColumnType.string],
          rows: [
            ['1']
          ],
        );
        mockAdapter.mockTransaction = txMock;

        Map<String, dynamic>? result;

        await executor.executeInTransaction((tx) async {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findUnique)
              .where({'id': '1'}).build();
          result = await tx.executeQueryAsSingleMap(query);
          return null;
        });

        expect(result, isNotNull);
        expect(result!['id'], '1');
      });

      test('executeQueryAsSingleMap returns null for empty result', () async {
        final txMock = MockTransaction();
        txMock.nextQueryResult = const SqlResultSet(
          columnNames: ['id'],
          columnTypes: [ColumnType.string],
          rows: [],
        );
        mockAdapter.mockTransaction = txMock;

        Map<String, dynamic>? result;

        await executor.executeInTransaction((tx) async {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findUnique)
              .where({'id': 'nonexistent'}).build();
          result = await tx.executeQueryAsSingleMap(query);
          return null;
        });

        expect(result, isNull);
      });

      test('converts snake_case to camelCase in transaction', () async {
        final txMock = MockTransaction();
        txMock.nextQueryResult = const SqlResultSet(
          columnNames: ['user_id', 'created_at'],
          columnTypes: [ColumnType.string, ColumnType.string],
          rows: [
            ['1', '2024-01-01'],
          ],
        );
        mockAdapter.mockTransaction = txMock;

        List<Map<String, dynamic>>? result;

        await executor.executeInTransaction((tx) async {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .build();
          result = await tx.executeQueryAsMaps(query);
          return null;
        });

        expect(result![0].containsKey('userId'), true);
        expect(result![0].containsKey('createdAt'), true);
      });
    });

    group('Error Handling', () {
      test('propagates adapter errors', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.throwOnNextCall(
          const AdapterError('Connection failed', code: 'CONNECTION_ERROR'),
        );

        expect(
          () => executor.executeQuery(query),
          throwsA(isA<AdapterError>()),
        );
      });

      test('propagates generic exceptions', () async {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        mockAdapter.throwOnNextCall(Exception('Unknown error'));

        expect(
          () => executor.executeQuery(query),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('dispose', () {
      test('disposes the adapter', () async {
        // Just verify it doesn't throw
        await executor.dispose();
      });
    });
  });

  group('CamelCase Conversion', () {
    late MockAdapter mockAdapter;
    late QueryExecutor executor;

    setUp(() {
      mockAdapter = MockAdapter();
      executor = QueryExecutor(adapter: mockAdapter);
    });

    test('handles single word columns', () async {
      mockAdapter.setNextQueryResult(const SqlResultSet(
        columnNames: ['id', 'name', 'email'],
        columnTypes: [ColumnType.string, ColumnType.string, ColumnType.string],
        rows: [
          ['1', 'John', 'john@example.com']
        ],
      ));

      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).build();

      final result = await executor.executeQueryAsMaps(query);

      expect(result[0].containsKey('id'), true);
      expect(result[0].containsKey('name'), true);
      expect(result[0].containsKey('email'), true);
    });

    test('handles multiple underscores', () async {
      mockAdapter.setNextQueryResult(const SqlResultSet(
        columnNames: ['user_profile_picture_url'],
        columnTypes: [ColumnType.string],
        rows: [
          ['https://example.com/pic.jpg']
        ],
      ));

      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).build();

      final result = await executor.executeQueryAsMaps(query);

      expect(result[0].containsKey('userProfilePictureUrl'), true);
    });

    test('handles already camelCase columns', () async {
      mockAdapter.setNextQueryResult(const SqlResultSet(
        columnNames: ['userId', 'createdAt'],
        columnTypes: [ColumnType.string, ColumnType.string],
        rows: [
          ['1', '2024-01-01']
        ],
      ));

      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).build();

      final result = await executor.executeQueryAsMaps(query);

      expect(result[0].containsKey('userId'), true);
      expect(result[0].containsKey('createdAt'), true);
    });

    test('handles empty column name', () async {
      mockAdapter.setNextQueryResult(const SqlResultSet(
        columnNames: [''],
        columnTypes: [ColumnType.string],
        rows: [
          ['value']
        ],
      ));

      final query =
          JsonQueryBuilder().model('User').action(QueryAction.findMany).build();

      final result = await executor.executeQueryAsMaps(query);

      expect(result[0].containsKey(''), true);
    });
  });
}
