/// Sentry integration for the query pipeline.
///
/// Bundles Sentry error reporting into the connector without hijacking the
/// host application's Sentry setup: it only *captures* exceptions, and only
/// when Sentry has already been initialized (`Sentry.isEnabled`). Plug it in
/// via the executor's `logger`, e.g.:
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
/// If you want the connector to own Sentry initialization (standalone use,
/// e.g. tooling/examples), call [PrismaSentry.init] once at startup.
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

/// Convenience Sentry initialization for standalone connector usage.
///
/// Most apps (including the familiarise mobile backend) already call
/// `Sentry.init`/`SentryFlutter.init` themselves — in that case you do NOT
/// need this; just add [SentryQueryLogger] to the executor. Use this only when
/// the connector is the top-level owner of Sentry.
class PrismaSentry {
  PrismaSentry._();

  /// Default DSN for the prisma_flutter_connector Sentry project. Override via
  /// the `SENTRY_DSN` dart-define or the [dsn] argument.
  static const defaultDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue:
        'https://f7e4fda3e20074d189fd615518b38918@o4509348815372289.ingest.us.sentry.io/4511666594185216',
  );

  /// Initialize Sentry if it isn't already. Safe to call once at startup.
  static Future<void> init({
    String? dsn,
    bool sendDefaultPii = true,
    void Function(SentryOptions)? configure,
  }) async {
    if (Sentry.isEnabled) return;
    await Sentry.init((options) {
      options.dsn = dsn ?? defaultDsn;
      options.sendDefaultPii = sendDefaultPii;
      configure?.call(options);
    });
  }
}
