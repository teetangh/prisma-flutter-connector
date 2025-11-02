/// Quick script to check what tables exist in Supabase
library;

import 'package:postgres/postgres.dart' as pg;

void main() async {
  final connection = await pg.Connection.open(
    pg.Endpoint(
      host: 'aws-0-ap-south-1.pooler.supabase.com',
      port: 6543,
      database: 'postgres',
      username: 'postgres.pzmbxqdgibfkhjwzeprf',
      password: 'wUScbMsQ0OsipiYv',
    ),
    settings: pg.ConnectionSettings(
      sslMode: pg.SslMode.require,
    ),
  );

  print('Checking tables...\n');

  final result = await connection.execute(
    '''
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
    ORDER BY table_name
    LIMIT 20
    ''',
  );

  print('Found ${result.length} tables:');
  for (final row in result) {
    final rowMap = row.toColumnMap();
    print('  - ${rowMap['table_name']}');
  }

  await connection.close();
}
