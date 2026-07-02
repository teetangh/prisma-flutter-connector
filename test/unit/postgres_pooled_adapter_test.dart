import 'package:test/test.dart';
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';

/// Unit-level checks for the pooled adapter (#70). Live pool behaviour
/// (borrow/pin/return per transaction) is covered by the integration suite;
/// here we only assert construction + mode flags without opening sockets.
void main() {
  group('PostgresAdapter.pooled (#70)', () {
    late pg.Pool pool;

    setUp(() {
      // withEndpoints is lazy — no connection is opened until a query runs.
      pool = pg.Pool.withEndpoints([
        pg.Endpoint(host: 'localhost', database: 'db', username: 'u'),
      ]);
    });

    tearDown(() async {
      await pool.close(force: true);
    });

    test('reports pooled mode and postgres provider', () {
      final adapter = PostgresAdapter.pooled(pool);
      expect(adapter.isPooled, isTrue);
      expect(adapter.provider, 'postgresql');
    });

    test('exposes the default connection info', () {
      final adapter = PostgresAdapter.pooled(pool);
      final info = adapter.getConnectionInfo();
      expect(info, isNotNull);
      expect(info!.supportsRelationJoins, isTrue);
    });
  });
}
