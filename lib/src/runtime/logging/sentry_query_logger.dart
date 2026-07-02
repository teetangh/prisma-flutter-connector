/// Sentry integration for the query pipeline.
///
/// Bundles Sentry error reporting into the connector without owning Sentry
/// configuration: it only *captures* exceptions, and only when Sentry has
/// already been initialized by the host application (`Sentry.isEnabled`). Plug
/// it into the executor's `logger`, e.g.:
///
/// ```dart
/// QueryExecutor(
///   adapter: adapter,
///   logger: const CompositeQueryLogger([
///     ConsoleQueryLogger(),
///     SentryQueryLogger(),
///   ]),
/// );
/// ```
///
/// The connector does NOT ship a DSN or call `Sentry.init` — that is always the
/// host application's responsibility (init Sentry with your own DSN, e.g. via
/// `--dart-define=SENTRY_DSN=...`, then add this logger). This keeps each
/// consumer's errors flowing to their own Sentry project.
library;

import 'package:sentry/sentry.dart';

import 'package:prisma_flutter_connector/src/runtime/logging/query_logger.dart';

/// A [QueryLogger] that forwards failed queries to Sentry.
///
/// Successful queries are ignored; failures are reported via
/// [Sentry.captureException] with the SQL/operation/model attached as context.
/// No-ops when Sentry is not enabled, so it is always safe to include.
class SentryQueryLogger implements QueryLogger {
  /// Whether to attach bound parameters to the Sentry event. Off by default
  /// because parameters may contain PII / secrets.
  final bool includeParameters;

  const SentryQueryLogger({this.includeParameters = false});

  @override
  void onQueryStart(QueryStartEvent event) {}

  @override
  void onQueryEnd(QueryEndEvent event) {}

  @override
  void onQueryError(QueryErrorEvent event) {
    if (!Sentry.isEnabled) return;
    Sentry.captureException(
      event.error,
      stackTrace: event.stackTrace,
      withScope: (scope) {
        scope.setContexts('prisma_query', {
          if (event.operation != null) 'operation': event.operation,
          if (event.model != null) 'model': event.model,
          'sql': event.sql,
          'durationMs': event.duration.inMilliseconds,
          if (includeParameters) 'parameters': event.parameters.toString(),
        });
      },
    );
  }
}
