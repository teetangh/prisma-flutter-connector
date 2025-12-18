/// Query logging system for Prisma operations.
///
/// Provides hooks for logging SQL queries, their parameters, execution time,
/// and results. Useful for debugging during development and monitoring
/// in production.
library;

import 'dart:collection';

/// Event data for a query that is about to be executed.
class QueryStartEvent {
  /// The SQL query being executed
  final String sql;

  /// Parameters bound to the query
  final List<dynamic> parameters;

  /// Name of the model being queried (if known)
  final String? model;

  /// Type of operation (findMany, create, update, etc.)
  final String? operation;

  /// Timestamp when the query started
  final DateTime startTime;

  const QueryStartEvent({
    required this.sql,
    required this.parameters,
    this.model,
    this.operation,
    required this.startTime,
  });

  @override
  String toString() {
    final op = operation != null ? '[$operation] ' : '';
    return '${op}SQL: $sql\nParams: $parameters';
  }
}

/// Event data for a completed query.
class QueryEndEvent {
  /// The SQL query that was executed
  final String sql;

  /// Parameters that were bound to the query
  final List<dynamic> parameters;

  /// Name of the model being queried (if known)
  final String? model;

  /// Type of operation (findMany, create, update, etc.)
  final String? operation;

  /// How long the query took to execute
  final Duration duration;

  /// Number of rows returned (for SELECT) or affected (for INSERT/UPDATE/DELETE)
  final int rowCount;

  const QueryEndEvent({
    required this.sql,
    required this.parameters,
    this.model,
    this.operation,
    required this.duration,
    required this.rowCount,
  });

  @override
  String toString() {
    final op = operation != null ? '[$operation] ' : '';
    return '$op[${duration.inMilliseconds}ms] $sql → $rowCount rows';
  }
}

/// Event data for a failed query.
class QueryErrorEvent {
  /// The SQL query that failed
  final String sql;

  /// Parameters that were bound to the query
  final List<dynamic> parameters;

  /// Name of the model being queried (if known)
  final String? model;

  /// Type of operation (findMany, create, update, etc.)
  final String? operation;

  /// How long before the error occurred
  final Duration duration;

  /// The error that occurred
  final Object error;

  /// Stack trace (if available)
  final StackTrace? stackTrace;

  const QueryErrorEvent({
    required this.sql,
    required this.parameters,
    this.model,
    this.operation,
    required this.duration,
    required this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    final op = operation != null ? '[$operation] ' : '';
    return '$op[${duration.inMilliseconds}ms] ERROR: $error\nSQL: $sql';
  }
}

/// Interface for query logging.
///
/// Implement this interface to receive notifications about query execution.
/// This is useful for debugging, performance monitoring, and audit logging.
///
/// Example:
/// ```dart
/// class MyLogger implements QueryLogger {
///   @override
///   void onQueryStart(QueryStartEvent event) {
///     print('Starting: ${event.sql}');
///   }
///
///   @override
///   void onQueryEnd(QueryEndEvent event) {
///     print('[${event.duration.inMilliseconds}ms] ${event.sql}');
///   }
///
///   @override
///   void onQueryError(QueryErrorEvent event) {
///     print('ERROR: ${event.error}');
///   }
/// }
/// ```
abstract interface class QueryLogger {
  /// Called before a query is executed.
  void onQueryStart(QueryStartEvent event);

  /// Called after a query completes successfully.
  void onQueryEnd(QueryEndEvent event);

  /// Called when a query fails.
  void onQueryError(QueryErrorEvent event);
}

/// A query logger that prints to the console.
///
/// Useful for development and debugging. Shows SQL, parameters, and timing.
///
/// Example output:
/// ```
/// [findMany] Starting: SELECT * FROM "User" WHERE "email" = $1
/// [findMany] [15ms] SELECT * FROM "User" WHERE "email" = $1 → 1 row
/// ```
class ConsoleQueryLogger implements QueryLogger {
  /// Whether to include parameters in the output (may contain sensitive data)
  final bool includeParameters;

  /// Whether to include the SQL query in the output
  final bool includeSql;

  /// Minimum duration to log (queries faster than this are not logged)
  /// Set to Duration.zero to log all queries.
  final Duration threshold;

  /// Whether to colorize output (ANSI escape codes)
  final bool colorize;

  const ConsoleQueryLogger({
    this.includeParameters = false,
    this.includeSql = true,
    this.threshold = Duration.zero,
    this.colorize = true,
  });

  @override
  void onQueryStart(QueryStartEvent event) {
    // Optional: only log if verbose mode is enabled
  }

  @override
  void onQueryEnd(QueryEndEvent event) {
    if (event.duration < threshold) return;

    final buffer = StringBuffer();

    // Colorize duration based on time
    final ms = event.duration.inMilliseconds;
    final durationStr = '${ms}ms';
    final coloredDuration =
        colorize ? _colorDuration(durationStr, ms) : durationStr;

    // Operation prefix
    if (event.operation != null) {
      final opColor = colorize ? '\x1B[36m' : ''; // Cyan
      final reset = colorize ? '\x1B[0m' : '';
      final op = event.operation;
      buffer.write('$opColor[$op]$reset ');
    }

    buffer.write('[$coloredDuration] ');

    if (includeSql) {
      buffer.write(_truncateSql(event.sql));
    }

    buffer.write(' → ${event.rowCount} row${event.rowCount == 1 ? '' : 's'}');

    if (includeParameters && event.parameters.isNotEmpty) {
      buffer.write('\n  Params: ${_sanitizeParams(event.parameters)}');
    }

    print(buffer.toString());
  }

  @override
  void onQueryError(QueryErrorEvent event) {
    final buffer = StringBuffer();

    final errorColor = colorize ? '\x1B[31m' : ''; // Red
    final reset = colorize ? '\x1B[0m' : '';

    if (event.operation != null) {
      final op = event.operation;
      buffer.write('[$op] ');
    }

    buffer.write('$errorColor[ERROR]$reset ');
    buffer.write('[${event.duration.inMilliseconds}ms] ');
    buffer.write(event.error);

    if (includeSql) {
      buffer.write('\n  SQL: ${_truncateSql(event.sql)}');
    }

    if (includeParameters && event.parameters.isNotEmpty) {
      buffer.write('\n  Params: ${_sanitizeParams(event.parameters)}');
    }

    print(buffer.toString());
  }

  String _colorDuration(String duration, int ms) {
    if (!colorize) return duration;

    if (ms < 10) {
      return '\x1B[32m$duration\x1B[0m'; // Green - fast
    } else if (ms < 100) {
      return '\x1B[33m$duration\x1B[0m'; // Yellow - moderate
    } else {
      return '\x1B[31m$duration\x1B[0m'; // Red - slow
    }
  }

  String _truncateSql(String sql, [int maxLength = 200]) {
    final singleLine = sql.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= maxLength) return singleLine;
    return '${singleLine.substring(0, maxLength)}...';
  }

  List<dynamic> _sanitizeParams(List<dynamic> params) {
    // Replace potentially sensitive values
    return params.map((p) {
      if (p is String && p.length > 50) {
        return '${p.substring(0, 50)}... [truncated]';
      }
      return p;
    }).toList();
  }
}

/// A query logger that collects metrics.
///
/// Useful for monitoring performance and identifying slow queries.
class MetricsQueryLogger implements QueryLogger {
  final Queue<QueryMetric> _metrics = Queue();
  final int _maxMetrics;

  MetricsQueryLogger({int maxMetrics = 1000}) : _maxMetrics = maxMetrics;

  /// All collected metrics
  List<QueryMetric> get metrics => _metrics.toList();

  /// Total number of queries executed
  int get totalQueries => _metrics.length;

  /// Total execution time
  Duration get totalDuration => _metrics.fold(
        Duration.zero,
        (sum, m) => sum + m.duration,
      );

  /// Average query duration
  Duration get averageDuration {
    if (_metrics.isEmpty) return Duration.zero;
    return Duration(
      microseconds: totalDuration.inMicroseconds ~/ _metrics.length,
    );
  }

  /// Slowest query
  QueryMetric? get slowestQuery {
    if (_metrics.isEmpty) return null;
    return _metrics.reduce((a, b) => a.duration > b.duration ? a : b);
  }

  /// Queries grouped by operation
  Map<String, List<QueryMetric>> get byOperation {
    final result = <String, List<QueryMetric>>{};
    for (final m in _metrics) {
      (result[m.operation ?? 'unknown'] ??= []).add(m);
    }
    return result;
  }

  /// Clear all collected metrics
  void clear() => _metrics.clear();

  @override
  void onQueryStart(QueryStartEvent event) {
    // No-op for metrics logger
  }

  @override
  void onQueryEnd(QueryEndEvent event) {
    _addMetric(QueryMetric(
      sql: event.sql,
      operation: event.operation,
      duration: event.duration,
      rowCount: event.rowCount,
      success: true,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void onQueryError(QueryErrorEvent event) {
    _addMetric(QueryMetric(
      sql: event.sql,
      operation: event.operation,
      duration: event.duration,
      rowCount: 0,
      success: false,
      error: event.error.toString(),
      timestamp: DateTime.now(),
    ));
  }

  void _addMetric(QueryMetric metric) {
    _metrics.add(metric);
    // Evict old metrics if over limit (O(1) with Queue.removeFirst)
    while (_metrics.length > _maxMetrics) {
      _metrics.removeFirst();
    }
  }
}

/// A single query execution metric.
class QueryMetric {
  final String sql;
  final String? operation;
  final Duration duration;
  final int rowCount;
  final bool success;
  final String? error;
  final DateTime timestamp;

  const QueryMetric({
    required this.sql,
    this.operation,
    required this.duration,
    required this.rowCount,
    required this.success,
    this.error,
    required this.timestamp,
  });
}

/// A composite logger that delegates to multiple loggers.
class CompositeQueryLogger implements QueryLogger {
  final List<QueryLogger> _loggers;

  CompositeQueryLogger(this._loggers);

  @override
  void onQueryStart(QueryStartEvent event) {
    for (final logger in _loggers) {
      logger.onQueryStart(event);
    }
  }

  @override
  void onQueryEnd(QueryEndEvent event) {
    for (final logger in _loggers) {
      logger.onQueryEnd(event);
    }
  }

  @override
  void onQueryError(QueryErrorEvent event) {
    for (final logger in _loggers) {
      logger.onQueryError(event);
    }
  }
}

/// A logger that does nothing.
///
/// Use this when you want to disable logging.
class NoOpQueryLogger implements QueryLogger {
  const NoOpQueryLogger();

  @override
  void onQueryStart(QueryStartEvent event) {}

  @override
  void onQueryEnd(QueryEndEvent event) {}

  @override
  void onQueryError(QueryErrorEvent event) {}
}
