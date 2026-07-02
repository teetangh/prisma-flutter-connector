import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/logging/sentry_query_logger.dart';
import 'package:prisma_flutter_connector/src/runtime/logging/query_logger.dart';

void main() {
  group('SentryQueryLogger', () {
    test('is a no-op when Sentry is not enabled (safe to always include)', () {
      const logger = SentryQueryLogger();
      // Sentry.isEnabled is false in tests → these must not throw.
      expect(
        () => logger.onQueryError(QueryErrorEvent(
          sql: 'SELECT 1',
          parameters: const [],
          operation: 'findMany',
          model: 'User',
          duration: const Duration(milliseconds: 3),
          error: Exception('boom'),
        )),
        returnsNormally,
      );
      expect(
        () => logger.onQueryStart(QueryStartEvent(
            sql: 'x', parameters: const [], startTime: DateTime(2020))),
        returnsNormally,
      );
    });

    test('composes with other loggers via CompositeQueryLogger', () {
      final composite = CompositeQueryLogger(const [
        ConsoleQueryLogger(includeSql: false),
        SentryQueryLogger(),
      ]);
      expect(composite, isA<QueryLogger>());
    });
  });
}
