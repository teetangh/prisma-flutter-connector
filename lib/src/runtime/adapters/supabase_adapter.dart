/// Supabase database adapter implementation.
///
/// Connects to Supabase PostgreSQL (direct or Supavisor/PgBouncer pooled)
/// using the pure-Dart `postgres` package without requiring `supabase_flutter`
/// or the Flutter SDK.
library;

import 'dart:async';
import 'package:postgres/postgres.dart' as pg;
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';

/// Supabase database adapter using direct or pooled PostgreSQL connections.
///
/// Example usage:
/// ```dart
/// final connection = await pg.Connection.open(
///   pg.Endpoint(
///     host: 'aws-0-ap-south-1.pooler.supabase.com',
///     port: 6543, // Pooler port
///     database: 'postgres',
///     username: 'postgres.projectid',
///     password: 'your-password',
///   ),
/// );
///
/// final adapter = SupabaseAdapter(connection);
/// final prisma = PrismaClient(adapter: adapter);
/// ```
class SupabaseAdapter implements SqlDriverAdapter {
  final PostgresAdapter _pgAdapter;

  SupabaseAdapter(pg.Connection connection, {ConnectionInfo? connectionInfo})
      : _pgAdapter =
            PostgresAdapter(connection, connectionInfo: connectionInfo);

  /// Create a pooled Supabase adapter backed by [pg.Pool].
  SupabaseAdapter.pooled(pg.Pool pool, {ConnectionInfo? connectionInfo})
      : _pgAdapter = PostgresAdapter.pooled(
          pool,
          connectionInfo: connectionInfo,
        );

  /// Create Supabase adapter from connection string.
  ///
  /// Supports both pooled and direct connections:
  /// - Pooled: `postgresql://user:pass@host:6543/db?pgbouncer=true`
  /// - Direct: `postgresql://user:pass@host:5432/db`
  static Future<SupabaseAdapter> fromConnectionString(
    String connectionString, {
    ConnectionInfo? connectionInfo,
  }) async {
    final uri = Uri.parse(connectionString);

    final connection = await pg.Connection.open(
      pg.Endpoint(
        host: uri.host,
        port: uri.port,
        database:
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres',
        username: uri.userInfo.split(':').first,
        password: uri.userInfo.split(':').last,
      ),
      settings: const pg.ConnectionSettings(
        sslMode: pg.SslMode.require,
      ),
    );

    return SupabaseAdapter(connection, connectionInfo: connectionInfo);
  }

  @override
  String get provider => 'postgresql'; // Supabase uses PostgreSQL

  @override
  String get adapterName => 'prisma_flutter_connector:supabase';

  @override
  Future<SqlResultSet> queryRaw(SqlQuery query) => _pgAdapter.queryRaw(query);

  @override
  Future<int> executeRaw(SqlQuery query) => _pgAdapter.executeRaw(query);

  @override
  Future<void> executeScript(String script) => _pgAdapter.executeScript(script);

  @override
  Future<Transaction> startTransaction([IsolationLevel? isolationLevel]) =>
      _pgAdapter.startTransaction(isolationLevel);

  @override
  ConnectionInfo? getConnectionInfo() {
    return _pgAdapter.getConnectionInfo() ??
        const ConnectionInfo(
          maxBindValues: 32767,
          supportsRelationJoins: true,
        );
  }

  @override
  Future<void> dispose() => _pgAdapter.dispose();
}
