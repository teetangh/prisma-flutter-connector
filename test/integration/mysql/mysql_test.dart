import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/mysql_adapter.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';

/// Integration tests for MySQL
///
/// Prerequisites:
/// 1. Start MySQL: cd test/integration/mysql && docker-compose up -d
/// 2. Run migrations: cd test/integration/mysql && prisma migrate dev
///
/// Run: flutter test test/integration/mysql/mysql_test.dart
///
/// Environment variables:
/// - MYSQL_HOST (default: localhost)
/// - MYSQL_PORT (default: 3306)
/// - MYSQL_USER (default: root)
/// - MYSQL_PASSWORD (default: password)
/// - MYSQL_DATABASE (default: test_db)

void main() {
  group('MySQL Integration Tests', () {
    late MySQLAdapter adapter;

    setUpAll(() async {
      // Connect to MySQL using environment variables or defaults
      const host =
          String.fromEnvironment('MYSQL_HOST', defaultValue: 'localhost');
      const port = int.fromEnvironment('MYSQL_PORT', defaultValue: 3306);
      const user = String.fromEnvironment('MYSQL_USER', defaultValue: 'root');
      const password =
          String.fromEnvironment('MYSQL_PASSWORD', defaultValue: 'password');
      const database =
          String.fromEnvironment('MYSQL_DATABASE', defaultValue: 'test_db');

      adapter = await MySQLAdapter.connect(
        host: host,
        port: port,
        userName: user,
        password: password,
        databaseName: database,
        secure: false, // For local Docker testing
      );

      // Create test table
      await adapter.executeScript('''
        CREATE TABLE IF NOT EXISTS test_categories (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          description TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS test_products (
          id INT AUTO_INCREMENT PRIMARY KEY,
          name VARCHAR(255) NOT NULL,
          price DECIMAL(10, 2) NOT NULL,
          in_stock TINYINT(1) DEFAULT 1,
          metadata JSON,
          category_id INT,
          FOREIGN KEY (category_id) REFERENCES test_categories(id)
        );
      ''');

      // Clean up any existing test data
      await adapter.executeRaw(const SqlQuery(
        sql: 'DELETE FROM test_products',
        args: [],
        argTypes: [],
      ));
      await adapter.executeRaw(const SqlQuery(
        sql: 'DELETE FROM test_categories',
        args: [],
        argTypes: [],
      ));
    });

    tearDownAll(() async {
      // Drop test tables
      await adapter.executeScript('''
        DROP TABLE IF EXISTS test_products;
        DROP TABLE IF EXISTS test_categories;
      ''');
      await adapter.dispose();
    });

    test('should connect to MySQL database', () async {
      final result = await adapter.queryRaw(const SqlQuery(
        sql: 'SELECT 1 as test',
        args: [],
        argTypes: [],
      ));
      expect(result.rows.isNotEmpty, true);
      expect(result.columnNames, ['test']);
    });

    test('should return correct provider info', () {
      expect(adapter.provider, 'mysql');
      expect(adapter.adapterName, 'prisma_flutter_connector:mysql');
    });

    test('should return connection info', () {
      final info = adapter.getConnectionInfo();
      expect(info, isNotNull);
      expect(info!.maxBindValues, 65535);
      expect(info.supportsRelationJoins, true);
    });

    group('CRUD Operations', () {
      test('should create a category', () async {
        final result = await adapter.executeRaw(const SqlQuery(
          sql: 'INSERT INTO test_categories (name, description) VALUES (?, ?)',
          args: ['Electronics', 'Electronic products'],
          argTypes: [ArgType.string, ArgType.string],
        ));
        expect(result, greaterThan(0));
      });

      test('should query categories', () async {
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT * FROM test_categories WHERE name = ?',
          args: ['Electronics'],
          argTypes: [ArgType.string],
        ));
        expect(result.rows.isNotEmpty, true);
        expect(result.columnNames.contains('name'), true);
      });

      test('should handle Decimal price correctly', () async {
        // First get the category id
        final catResult = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT id FROM test_categories WHERE name = ?',
          args: ['Electronics'],
          argTypes: [ArgType.string],
        ));
        final categoryId = catResult.rows.first[0];

        // Insert product with decimal price
        await adapter.executeRaw(SqlQuery(
          sql:
              'INSERT INTO test_products (name, price, category_id) VALUES (?, ?, ?)',
          args: ['Laptop', '999.99', categoryId],
          argTypes: [ArgType.string, ArgType.decimal, ArgType.int32],
        ));

        // Query and verify
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT name, price FROM test_products WHERE name = ?',
          args: ['Laptop'],
          argTypes: [ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
        // Price should be returned (exact format depends on driver)
        expect(result.rows.first[1], isNotNull);
      });

      test('should handle boolean (TINYINT) correctly', () async {
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT in_stock FROM test_products WHERE name = ?',
          args: ['Laptop'],
          argTypes: [ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
        // TINYINT should be converted to boolean or remain as int
        final inStock = result.rows.first[0];
        expect(inStock == true || inStock == 1, true);
      });

      test('should handle JSON column', () async {
        await adapter.executeRaw(const SqlQuery(
          sql: 'UPDATE test_products SET metadata = ? WHERE name = ?',
          args: ['{"warranty": "2 years", "color": "silver"}', 'Laptop'],
          argTypes: [ArgType.json, ArgType.string],
        ));

        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT metadata FROM test_products WHERE name = ?',
          args: ['Laptop'],
          argTypes: [ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
        final metadata = result.rows.first[0];
        // JSON should be parsed or returned as string
        expect(metadata, isNotNull);
      });

      test('should handle DateTime correctly', () async {
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT created_at FROM test_categories WHERE name = ?',
          args: ['Electronics'],
          argTypes: [ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
        // DateTime should be returned
        expect(result.rows.first[0], isNotNull);
      });
    });

    group('Placeholder Conversion', () {
      test('should convert PostgreSQL-style placeholders to MySQL', () async {
        // This tests the internal _convertPlaceholders method indirectly
        final result = await adapter.queryRaw(const SqlQuery(
          sql: r'SELECT * FROM test_categories WHERE name = $1',
          args: ['Electronics'],
          argTypes: [ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
      });

      test('should handle multiple placeholders', () async {
        final result = await adapter.queryRaw(const SqlQuery(
          sql:
              r'SELECT * FROM test_categories WHERE name = $1 OR description LIKE $2',
          args: ['Electronics', '%products%'],
          argTypes: [ArgType.string, ArgType.string],
        ));

        expect(result.rows.isNotEmpty, true);
      });
    });

    group('Transactions', () {
      test('should commit transaction', () async {
        final tx = await adapter.startTransaction();

        await tx.executeRaw(const SqlQuery(
          sql: 'INSERT INTO test_categories (name) VALUES (?)',
          args: ['Transaction Test'],
          argTypes: [ArgType.string],
        ));

        await tx.commit();
        expect(tx.isActive, false);

        // Verify the insert was committed
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT * FROM test_categories WHERE name = ?',
          args: ['Transaction Test'],
          argTypes: [ArgType.string],
        ));
        expect(result.rows.isNotEmpty, true);
      });

      test('should rollback transaction', () async {
        final tx = await adapter.startTransaction();

        await tx.executeRaw(const SqlQuery(
          sql: 'INSERT INTO test_categories (name) VALUES (?)',
          args: ['Rollback Test'],
          argTypes: [ArgType.string],
        ));

        await tx.rollback();
        expect(tx.isActive, false);

        // Verify the insert was rolled back
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT * FROM test_categories WHERE name = ?',
          args: ['Rollback Test'],
          argTypes: [ArgType.string],
        ));
        expect(result.rows.isEmpty, true);
      });

      test('should throw error after commit', () async {
        final tx = await adapter.startTransaction();
        await tx.commit();

        expect(
          () => tx.executeRaw(const SqlQuery(
            sql: 'SELECT 1',
            args: [],
            argTypes: [],
          )),
          throwsA(isA<AdapterError>()),
        );
      });

      test('should support isolation levels', () async {
        final tx = await adapter.startTransaction(IsolationLevel.serializable);

        await tx.executeRaw(const SqlQuery(
          sql: 'INSERT INTO test_categories (name) VALUES (?)',
          args: ['Isolation Test'],
          argTypes: [ArgType.string],
        ));

        await tx.commit();

        // Verify
        final result = await adapter.queryRaw(const SqlQuery(
          sql: 'SELECT * FROM test_categories WHERE name = ?',
          args: ['Isolation Test'],
          argTypes: [ArgType.string],
        ));
        expect(result.rows.isNotEmpty, true);
      });
    });

    group('Error Handling', () {
      test('should throw AdapterError on invalid query', () async {
        expect(
          () => adapter.queryRaw(const SqlQuery(
            sql: 'SELECT * FROM nonexistent_table',
            args: [],
            argTypes: [],
          )),
          throwsA(isA<AdapterError>()),
        );
      });

      test('should throw AdapterError on syntax error', () async {
        expect(
          () => adapter.queryRaw(const SqlQuery(
            sql: 'SELEC * FROM test_categories',
            args: [],
            argTypes: [],
          )),
          throwsA(isA<AdapterError>()),
        );
      });
    });
  });
}
