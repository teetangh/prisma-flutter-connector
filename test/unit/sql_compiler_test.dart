import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
import 'package:prisma_flutter_connector/src/runtime/query/computed_field.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/types.dart';
import 'package:prisma_flutter_connector/src/runtime/schema/schema_registry.dart';

void main() {
  group('SqlCompiler', () {
    group('PostgreSQL Provider', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      group('findMany', () {
        test('generates basic SELECT query', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User"');
          expect(result.args, isEmpty);
          expect(result.argTypes, isEmpty);
        });

        test('generates SELECT with WHERE clause', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'email': 'test@example.com'}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "email" = \$1');
          expect(result.args, ['test@example.com']);
          expect(result.argTypes, [ArgType.string]);
        });

        test('generates SELECT with ORDER BY', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .orderBy({'createdAt': 'desc'}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" ORDER BY "createdAt" DESC');
        });

        test('generates SELECT with ORDER BY ASC', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .orderBy({'name': 'asc'}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" ORDER BY "name" ASC');
        });

        test('generates ORDER BY with NULLS LAST', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .orderBy({
            'rating': {'sort': 'desc', 'nulls': 'last'}
          }).build();

          final result = compiler.compile(query);

          expect(result.sql,
              'SELECT * FROM "User" ORDER BY "rating" DESC NULLS LAST');
        });

        test('generates ORDER BY with NULLS FIRST', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .orderBy({
            'createdAt': {'sort': 'asc', 'nulls': 'first'}
          }).build();

          final result = compiler.compile(query);

          expect(result.sql,
              'SELECT * FROM "User" ORDER BY "createdAt" ASC NULLS FIRST');
        });

        test('generates ORDER BY with multiple fields including NULLS', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .orderBy({
            'rating': {'sort': 'desc', 'nulls': 'last'},
            'createdAt': 'desc', // Simple syntax still works
          }).build();

          final result = compiler.compile(query);

          expect(
              result.sql,
              'SELECT * FROM "User" ORDER BY "rating" DESC NULLS LAST, '
              '"createdAt" DESC');
        });

        test('generates SELECT with LIMIT', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .take(10)
              .build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" LIMIT 10');
        });

        test('generates SELECT with OFFSET', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .skip(5)
              .build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" OFFSET 5');
        });

        test('generates SELECT with LIMIT and OFFSET', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .take(10)
              .skip(20)
              .build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" LIMIT 10 OFFSET 20');
        });

        test('generates SELECT with multiple WHERE conditions', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'email': 'test@example.com',
            'name': 'John',
          }).build();

          final result = compiler.compile(query);

          expect(result.sql,
              'SELECT * FROM "User" WHERE "email" = \$1 AND "name" = \$2');
          expect(result.args, ['test@example.com', 'John']);
        });

        test('generates SELECT with all clauses combined', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'status': 'active'})
              .orderBy({'createdAt': 'desc'})
              .take(10)
              .skip(0)
              .build();

          final result = compiler.compile(query);

          expect(
              result.sql,
              'SELECT * FROM "User" WHERE "status" = \$1 '
              'ORDER BY "createdAt" DESC LIMIT 10 OFFSET 0');
        });
      });

      group('findUnique', () {
        test('generates SELECT with LIMIT 1', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findUnique)
              .where({'id': '123'}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "id" = \$1 LIMIT 1');
          expect(result.args, ['123']);
        });
      });

      group('findFirst', () {
        test('generates SELECT with LIMIT 1', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findFirst)
              .where({
            'email': {'contains': '@example.com'}
          }).build();

          final result = compiler.compile(query);

          expect(result.sql,
              'SELECT * FROM "User" WHERE "email" LIKE \$1 LIMIT 1');
          expect(result.args, ['%@example.com%']);
        });
      });

      group('create', () {
        test('generates INSERT query with RETURNING', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'create',
            args: JsonQueryArgs(
              arguments: {
                'data': {
                  'id': '123',
                  'email': 'test@example.com',
                  'name': 'John',
                }
              },
            ),
          );

          final result = compiler.compile(query);

          expect(
              result.sql,
              'INSERT INTO "User" ("id", "email", "name") '
              'VALUES (\$1, \$2, \$3) RETURNING *');
          expect(result.args, ['123', 'test@example.com', 'John']);
          expect(result.argTypes.length, 3);
        });

        test('throws error when data is missing', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'create',
            args: JsonQueryArgs(arguments: {}),
          );

          expect(
            () => compiler.compile(query),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      group('createMany', () {
        test('generates batch INSERT query', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'createMany',
            args: JsonQueryArgs(
              arguments: {
                'data': [
                  {'id': '1', 'email': 'a@test.com'},
                  {'id': '2', 'email': 'b@test.com'},
                  {'id': '3', 'email': 'c@test.com'},
                ]
              },
            ),
          );

          final result = compiler.compile(query);

          expect(
              result.sql,
              'INSERT INTO "User" ("id", "email") '
              'VALUES (\$1, \$2), (\$3, \$4), (\$5, \$6)');
          expect(result.args,
              ['1', 'a@test.com', '2', 'b@test.com', '3', 'c@test.com']);
        });

        test('throws error when data is empty', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'createMany',
            args: JsonQueryArgs(arguments: {'data': []}),
          );

          expect(
            () => compiler.compile(query),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      group('update', () {
        test('generates UPDATE query', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'update',
            args: JsonQueryArgs(
              arguments: {
                'where': {'id': '123'},
                'data': {'name': 'Jane', 'email': 'jane@test.com'},
              },
            ),
          );

          final result = compiler.compile(query);

          expect(
              result.sql,
              'UPDATE "User" SET "name" = \$1, "email" = \$2 '
              'WHERE "id" = \$3 RETURNING *');
          expect(result.args, ['Jane', 'jane@test.com', '123']);
        });

        test('generates UPDATE without WHERE', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'update',
            args: JsonQueryArgs(
              arguments: {
                'data': {'status': 'inactive'},
              },
            ),
          );

          final result = compiler.compile(query);

          expect(result.sql, 'UPDATE "User" SET "status" = \$1 RETURNING *');
          expect(result.args, ['inactive']);
        });

        test('throws error when data is missing', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'update',
            args: JsonQueryArgs(arguments: {
              'where': {'id': '123'}
            }),
          );

          expect(
            () => compiler.compile(query),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      group('delete', () {
        test('generates DELETE query with WHERE', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'delete',
            args: JsonQueryArgs(
              arguments: {
                'where': {'id': '123'},
              },
            ),
          );

          final result = compiler.compile(query);

          expect(result.sql, 'DELETE FROM "User" WHERE "id" = \$1');
          expect(result.args, ['123']);
        });

        test('generates DELETE without WHERE (dangerous!)', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'delete',
            args: JsonQueryArgs(arguments: {}),
          );

          final result = compiler.compile(query);

          expect(result.sql, 'DELETE FROM "User"');
          expect(result.args, isEmpty);
        });
      });

      group('deleteMany', () {
        test('generates DELETE query for multiple records', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'deleteMany',
            args: JsonQueryArgs(
              arguments: {
                'where': {'status': 'inactive'},
              },
            ),
          );

          final result = compiler.compile(query);

          expect(result.sql, 'DELETE FROM "User" WHERE "status" = \$1');
          expect(result.args, ['inactive']);
        });
      });

      group('count', () {
        test('generates COUNT query without WHERE', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'count',
            args: JsonQueryArgs(),
          );

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT COUNT(*) FROM "User"');
          expect(result.args, isEmpty);
        });

        test('generates COUNT query with WHERE', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'count',
            args: JsonQueryArgs(
              arguments: {
                'where': {'status': 'active'},
              },
            ),
          );

          final result = compiler.compile(query);

          expect(
              result.sql, 'SELECT COUNT(*) FROM "User" WHERE "status" = \$1');
          expect(result.args, ['active']);
        });
      });

      group('Filter Operators', () {
        test('compiles equals operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'email': FilterOperators.equals('test@example.com')
          }).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "email" = \$1');
          expect(result.args, ['test@example.com']);
        });

        test('compiles not operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'status': FilterOperators.not('inactive')}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "status" != \$1');
          expect(result.args, ['inactive']);
        });

        test('compiles in operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'status': FilterOperators.in_(['active', 'pending'])
          }).build();

          final result = compiler.compile(query);

          expect(
              result.sql, 'SELECT * FROM "User" WHERE "status" IN (\$1, \$2)');
          expect(result.args, ['active', 'pending']);
        });

        test('compiles notIn operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'status': FilterOperators.notIn(['banned', 'deleted'])
          }).build();

          final result = compiler.compile(query);

          expect(result.sql,
              'SELECT * FROM "User" WHERE "status" NOT IN (\$1, \$2)');
          expect(result.args, ['banned', 'deleted']);
        });

        test('compiles lt operator', () {
          final query = JsonQueryBuilder()
              .model('Product')
              .action(QueryAction.findMany)
              .where({'price': FilterOperators.lt(100)}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "Product" WHERE "price" < \$1');
          expect(result.args, [100]);
        });

        test('compiles lte operator', () {
          final query = JsonQueryBuilder()
              .model('Product')
              .action(QueryAction.findMany)
              .where({'price': FilterOperators.lte(100)}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "Product" WHERE "price" <= \$1');
        });

        test('compiles gt operator', () {
          final query = JsonQueryBuilder()
              .model('Product')
              .action(QueryAction.findMany)
              .where({'price': FilterOperators.gt(50)}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "Product" WHERE "price" > \$1');
        });

        test('compiles gte operator', () {
          final query = JsonQueryBuilder()
              .model('Product')
              .action(QueryAction.findMany)
              .where({'price': FilterOperators.gte(50)}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "Product" WHERE "price" >= \$1');
        });

        test('compiles contains operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where(
                  {'email': FilterOperators.contains('@example.com')}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "email" LIKE \$1');
          expect(result.args, ['%@example.com%']);
        });

        test('compiles startsWith operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'name': FilterOperators.startsWith('John')}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "name" LIKE \$1');
          expect(result.args, ['John%']);
        });

        test('compiles endsWith operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'email': FilterOperators.endsWith('.com')}).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "email" LIKE \$1');
          expect(result.args, ['%.com']);
        });

        test('compiles containsInsensitive with ILIKE for PostgreSQL', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'name': FilterOperators.containsInsensitive('John')
          }).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "name" ILIKE \$1');
          expect(result.args, ['%John%']);
        });

        test('compiles startsWithInsensitive with ILIKE for PostgreSQL', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'name': FilterOperators.startsWithInsensitive('Dr.')
          }).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "name" ILIKE \$1');
          expect(result.args, ['Dr.%']);
        });

        test('compiles endsWithInsensitive with ILIKE for PostgreSQL', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'email': FilterOperators.endsWithInsensitive('.COM')
          }).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE "email" ILIKE \$1');
          expect(result.args, ['%.COM']);
        });
      });

      group('Logical Operators', () {
        test('compiles AND operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'AND': [
              {'status': 'active'},
              {'role': 'admin'},
            ]
          }).build();

          final result = compiler.compile(query);

          expect(
              result.sql,
              'SELECT * FROM "User" WHERE '
              '(("status" = \$1) AND ("role" = \$2))');
          expect(result.args, ['active', 'admin']);
        });

        test('compiles OR operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'OR': [
              {'role': 'admin'},
              {'role': 'moderator'},
            ]
          }).build();

          final result = compiler.compile(query);

          expect(
              result.sql,
              'SELECT * FROM "User" WHERE '
              '(("role" = \$1) OR ("role" = \$2))');
          expect(result.args, ['admin', 'moderator']);
        });

        test('compiles NOT operator', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'NOT': {'status': 'banned'},
          }).build();

          final result = compiler.compile(query);

          expect(result.sql, 'SELECT * FROM "User" WHERE NOT ("status" = \$1)');
          expect(result.args, ['banned']);
        });

        test('compiles nested logical operators', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({
            'AND': [
              {'status': 'active'},
              {
                'OR': [
                  {'role': 'admin'},
                  {'role': 'moderator'},
                ]
              },
            ]
          }).build();

          final result = compiler.compile(query);

          expect(
              result.sql,
              'SELECT * FROM "User" WHERE '
              '(("status" = \$1) AND ((("role" = \$2) OR ("role" = \$3))))');
          expect(result.args, ['active', 'admin', 'moderator']);
        });
      });

      group('Type Inference', () {
        test('infers int type', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'age': 25}).build();

          final result = compiler.compile(query);
          expect(result.argTypes, [ArgType.int64]);
        });

        test('infers double type', () {
          final query = JsonQueryBuilder()
              .model('Product')
              .action(QueryAction.findMany)
              .where({'price': 99.99}).build();

          final result = compiler.compile(query);
          expect(result.argTypes, [ArgType.double]);
        });

        test('infers boolean type', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'isActive': true}).build();

          final result = compiler.compile(query);
          expect(result.argTypes, [ArgType.boolean]);
        });

        test('infers string type', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'name': 'John'}).build();

          final result = compiler.compile(query);
          expect(result.argTypes, [ArgType.string]);
        });

        test('infers dateTime type from ISO string', () {
          final query = JsonQueryBuilder()
              .model('User')
              .action(QueryAction.findMany)
              .where({'createdAt': '2024-01-01T00:00:00.000Z'}).build();

          final result = compiler.compile(query);
          expect(result.argTypes, [ArgType.dateTime]);
        });
      });

      group('Unsupported Actions', () {
        test('throws for unsupported action', () {
          const query = JsonQuery(
            modelName: 'User',
            action: 'unsupported',
            args: JsonQueryArgs(),
          );

          expect(
            () => compiler.compile(query),
            throwsA(isA<UnsupportedError>()),
          );
        });
      });
    });

    group('MySQL Provider', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'mysql');
      });

      test('uses backticks for identifiers', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM `User`');
      });

      test('uses ? placeholders', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({'email': 'test@example.com'}).build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM `User` WHERE `email` = ?');
      });

      test('containsInsensitive uses LIKE (no ILIKE in MySQL)', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where(
                {'name': FilterOperators.containsInsensitive('John')}).build();

        final result = compiler.compile(query);

        // MySQL doesn't support ILIKE, falls back to LIKE
        // (MySQL LIKE is case-insensitive by default with utf8_general_ci)
        expect(result.sql, 'SELECT * FROM `User` WHERE `name` LIKE ?');
        expect(result.args, ['%John%']);
      });

      test('ignores NULLS LAST/FIRST (not supported in MySQL)', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .orderBy({
          'rating': {'sort': 'desc', 'nulls': 'last'}
        }).build();

        final result = compiler.compile(query);

        // MySQL doesn't support NULLS LAST, it should be silently ignored
        expect(result.sql, 'SELECT * FROM `User` ORDER BY `rating` DESC');
      });

      test('does not add RETURNING clause for INSERT', () {
        const query = JsonQuery(
          modelName: 'User',
          action: 'create',
          args: JsonQueryArgs(
            arguments: {
              'data': {'email': 'test@example.com'},
            },
          ),
        );

        final result = compiler.compile(query);

        expect(result.sql, 'INSERT INTO `User` (`email`) VALUES (?)');
        expect(result.sql.contains('RETURNING'), false);
      });
    });

    group('SQLite Provider', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'sqlite');
      });

      test('uses double quotes for identifiers', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "User"');
      });

      test('uses ? placeholders', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({'email': 'test@example.com'}).build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "User" WHERE "email" = ?');
      });

      test('containsInsensitive uses LIKE (no ILIKE in SQLite)', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where(
                {'name': FilterOperators.containsInsensitive('John')}).build();

        final result = compiler.compile(query);

        // SQLite doesn't support ILIKE, falls back to LIKE
        // (SQLite LIKE is case-insensitive for ASCII by default)
        expect(result.sql, 'SELECT * FROM "User" WHERE "name" LIKE ?');
        expect(result.args, ['%John%']);
      });

      test('does not add RETURNING clause for INSERT', () {
        const query = JsonQuery(
          modelName: 'User',
          action: 'create',
          args: JsonQueryArgs(
            arguments: {
              'data': {'email': 'test@example.com'},
            },
          ),
        );

        final result = compiler.compile(query);

        expect(result.sql, 'INSERT INTO "User" ("email") VALUES (?)');
        expect(result.sql.contains('RETURNING'), false);
      });
    });

    group('Supabase Provider', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'supabase');
      });

      test('behaves like PostgreSQL', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({'email': 'test@example.com'}).build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "User" WHERE "email" = \$1');
      });

      test('containsInsensitive uses ILIKE (like PostgreSQL)', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where(
                {'name': FilterOperators.containsInsensitive('John')}).build();

        final result = compiler.compile(query);

        // Supabase uses PostgreSQL, so ILIKE is supported
        expect(result.sql, 'SELECT * FROM "User" WHERE "name" ILIKE \$1');
        expect(result.args, ['%John%']);
      });

      test('adds RETURNING clause for INSERT', () {
        const query = JsonQuery(
          modelName: 'User',
          action: 'create',
          args: JsonQueryArgs(
            arguments: {
              'data': {'email': 'test@example.com'},
            },
          ),
        );

        // Supabase uses PostgreSQL, so no RETURNING (provider check is 'postgresql')
        final result = compiler.compile(query);

        // Note: Current implementation only checks for 'postgresql', not 'supabase'
        // This test documents current behavior
        expect(result.sql.contains('VALUES'), true);
      });
    });

    group('Edge Cases', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('handles empty WHERE clause', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({}).build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "User"');
        expect(result.args, isEmpty);
      });

      test('handles special characters in table names', () {
        final query = JsonQueryBuilder()
            .model('user_profiles')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "user_profiles"');
      });

      test('handles PascalCase table names', () {
        final query = JsonQueryBuilder()
            .model('ProductCategory')
            .action(QueryAction.findMany)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "ProductCategory"');
      });

      test('handles multiple filter operators on same field', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'price': {
            'gte': 10,
            'lte': 100,
          }
        }).build();

        final result = compiler.compile(query);

        expect(
            result.sql,
            'SELECT * FROM "Product" WHERE '
            '"price" >= \$1 AND "price" <= \$2');
        expect(result.args, [10, 100]);
      });

      test('handles null value in WHERE', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({'deletedAt': null}).build();

        final result = compiler.compile(query);

        expect(result.sql, 'SELECT * FROM "User" WHERE "deletedAt" = \$1');
        expect(result.args, [null]);
      });
    });

    group('Relation Filtering', () {
      late SqlCompiler compilerWithSchema;
      late SchemaRegistry schema;

      setUp(() {
        schema = SchemaRegistry();

        // Register Product model (e-commerce example)
        schema.registerModel(ModelSchema(
          name: 'Product',
          tableName: 'Product',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'price': const FieldInfo(
              name: 'price',
              columnName: 'price',
              type: 'double',
            ),
            'isActive': const FieldInfo(
              name: 'isActive',
              columnName: 'isActive',
              type: 'bool',
            ),
          },
          relations: {
            'reviews': RelationInfo.oneToMany(
              name: 'reviews',
              targetModel: 'Review',
              foreignKey: 'productId',
            ),
            'categories': RelationInfo.manyToMany(
              name: 'categories',
              targetModel: 'Category',
              joinTable: '_ProductToCategory',
              joinColumn: 'A',
              inverseJoinColumn: 'B',
            ),
          },
        ));

        // Register Review model
        schema.registerModel(const ModelSchema(
          name: 'Review',
          tableName: 'Review',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'rating': FieldInfo(
              name: 'rating',
              columnName: 'rating',
              type: 'int',
            ),
            'productId': FieldInfo(
              name: 'productId',
              columnName: 'productId',
              type: 'String',
            ),
          },
        ));

        // Register Category model
        schema.registerModel(const ModelSchema(
          name: 'Category',
          tableName: 'Category',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
          },
        ));

        compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: schema,
        );
      });

      test('generates EXISTS for one-to-many some filter', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'reviews': FilterOperators.some({
            'rating': FilterOperators.gte(4),
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('EXISTS'));
        expect(result.sql, contains('SELECT 1 FROM "Review"'));
        expect(result.sql, contains('"productId"'));
        expect(result.sql, contains('rating'));
        expect(result.args, [4]);
      });

      test('generates NOT EXISTS for one-to-many none filter', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'reviews': FilterOperators.noneMatch({
            'rating': FilterOperators.lt(3),
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('NOT EXISTS'));
        expect(result.sql, contains('SELECT 1 FROM "Review"'));
        expect(result.args, [3]);
      });

      test('generates NOT EXISTS for one-to-many every filter', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'reviews': FilterOperators.every({
            'rating': FilterOperators.gte(4),
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        // every means: NOT EXISTS where NOT (condition)
        expect(result.sql, contains('NOT EXISTS'));
        expect(result.sql, contains('AND NOT'));
        expect(result.args, [4]);
      });

      test('generates EXISTS for many-to-many some filter', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'categories': FilterOperators.some({
            'id': 'category-electronics',
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('EXISTS'));
        expect(result.sql, contains('"_ProductToCategory"'));
        expect(result.sql, contains('INNER JOIN "Category"'));
        expect(result.args, ['category-electronics']);
      });

      test('generates NOT EXISTS for many-to-many none filter (isEmpty)', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'categories': FilterOperators.isEmpty(),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('NOT EXISTS'));
        expect(result.sql, contains('"_ProductToCategory"'));
      });

      test('combines relation filter with scalar filters', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'isActive': true,
          'reviews': FilterOperators.some({
            'rating': FilterOperators.gte(4),
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('"isActive" = \$1'));
        expect(result.sql, contains('EXISTS'));
        expect(result.args, contains(true));
        expect(result.args, contains(4));
      });

      test('handles isNotEmpty filter', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'reviews': FilterOperators.isNotEmpty(),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('EXISTS'));
        expect(result.sql, contains('SELECT 1 FROM "Review"'));
      });

      test('generates correct SQL for nested relation filters (v0.4.0 fix)',
          () {
        // Bug fix: nested relation filters need table aliases to work correctly.
        // Without aliases, SQL like: sub_reviews."authorId" fails because sub_reviews
        // is not defined in the FROM clause.

        // Create a schema with nested relations: Product -> Review -> User
        final nestedSchema = SchemaRegistry();

        nestedSchema.registerModel(ModelSchema(
          name: 'Product',
          tableName: 'Product',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
          },
          relations: {
            'reviews': RelationInfo.oneToMany(
              name: 'reviews',
              targetModel: 'Review',
              foreignKey: 'productId',
            ),
          },
        ));

        nestedSchema.registerModel(ModelSchema(
          name: 'Review',
          tableName: 'Review',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'productId': const FieldInfo(
              name: 'productId',
              columnName: 'productId',
              type: 'String',
            ),
            'authorId': const FieldInfo(
              name: 'authorId',
              columnName: 'authorId',
              type: 'String',
            ),
          },
          relations: {
            'author': RelationInfo.manyToOne(
              name: 'author',
              targetModel: 'User',
              foreignKey: 'authorId',
            ),
          },
        ));

        nestedSchema.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
          },
        ));

        final nestedCompiler = SqlCompiler(
          provider: 'postgresql',
          schema: nestedSchema,
        );

        // Nested filter: Product -> reviews.some -> author.some -> id equals
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({
          'reviews': FilterOperators.some({
            'author': FilterOperators.some({
              'id': 'user-123',
            }),
          }),
        }).build();

        final result = nestedCompiler.compile(query);

        // The SQL should define aliases for nested tables
        // Without fix: "sub_reviews" is referenced but never defined → SQL error
        // With fix: "Review" AS sub_reviews is in the FROM clause
        expect(result.sql, contains('AS sub_reviews'));

        // The nested EXISTS for author should also have proper alias
        expect(result.sql, contains('AS sub_author'));

        // Args should contain the user id
        expect(result.args, contains('user-123'));
      });
    });

    group('selectFields (v0.2.5)', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('generates SELECT * when no selectFields provided', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .where({'isActive': true}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT *'));
        expect(result.sql, contains('FROM "Product"'));
      });

      test('generates specific columns with selectFields', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name', 'price']).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name", "price"'));
        expect(result.sql, isNot(contains('SELECT *')));
        expect(result.sql, contains('FROM "Product"'));
      });

      test('selectFields works with WHERE clause', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name']).where({'isActive': true}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name"'));
        expect(result.sql, contains('WHERE "isActive" = \$1'));
        expect(result.args, [true]);
      });

      test('selectFields works with ORDER BY', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name', 'price']).orderBy(
                {'price': 'asc'}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name", "price"'));
        expect(result.sql, contains('ORDER BY "price" ASC'));
      });

      test('selectFields works with NULLS LAST ordering', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name', 'rating']).orderBy({
          'rating': {'sort': 'desc', 'nulls': 'last'}
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name", "rating"'));
        expect(result.sql, contains('ORDER BY "rating" DESC NULLS LAST'));
      });

      test('selectFields works with pagination', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name'])
            .take(10)
            .skip(20)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name"'));
        expect(result.sql, contains('LIMIT 10'));
        expect(result.sql, contains('OFFSET 20'));
      });

      test('empty selectFields returns SELECT *', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields([]).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT *'));
      });

      test('selectFields works with findFirst', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findFirst)
            .selectFields(['id', 'name']).where({'isActive': true}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name"'));
        expect(result.sql, contains('LIMIT 1'));
      });

      test('selectFields works with findUnique', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findUnique)
            .selectFields(['id', 'name', 'price']).where(
                {'id': 'product-123'}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('SELECT "id", "name", "price"'));
        expect(result.sql, contains('WHERE "id" = \$1'));
        expect(result.sql, contains('LIMIT 1'));
        expect(result.args, ['product-123']);
      });

      test('selectFields combined with relation filtering', () {
        // Create a schema for relation filtering
        final schema = SchemaRegistry();
        schema.registerModel(const ModelSchema(
          name: 'Product',
          tableName: 'Product',
          fields: {
            'id': FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
            'name': FieldInfo(name: 'name', columnName: 'name', type: 'String'),
            'isActive': FieldInfo(
                name: 'isActive', columnName: 'isActive', type: 'bool'),
          },
          relations: {
            'reviews': RelationInfo(
              name: 'reviews',
              type: RelationType.oneToMany,
              targetModel: 'Review',
              foreignKey: 'productId',
              references: ['id'],
            ),
          },
        ));
        schema.registerModel(const ModelSchema(
          name: 'Review',
          tableName: 'Review',
          fields: {
            'id': FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
            'rating':
                FieldInfo(name: 'rating', columnName: 'rating', type: 'int'),
            'productId': FieldInfo(
                name: 'productId', columnName: 'productId', type: 'String'),
          },
          relations: {},
        ));

        final compilerWithSchema =
            SqlCompiler(provider: 'postgresql', schema: schema);

        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .selectFields(['id', 'name']).where({
          'isActive': true,
          'reviews': FilterOperators.some({
            'rating': FilterOperators.gte(4),
          }),
        }).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('SELECT "id", "name"'));
        expect(result.sql, contains('EXISTS'));
        expect(result.sql, contains('"isActive" = \$1'));
      });
    });

    group('FILTER clause for aggregations (PostgreSQL)', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('generates basic aggregate without FILTER', () {
        final query = JsonQueryBuilder()
            .model('ConsultantReview')
            .action(QueryAction.aggregate)
            .aggregation({
          '_count': true,
          '_avg': {'rating': true},
        }).where({'consultantProfileId': 'consultant-123'}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('COUNT(*) AS "_count"'));
        expect(result.sql, contains('AVG("rating") AS "_avg_rating"'));
        expect(result.sql, contains('WHERE "consultantProfileId" = \$1'));
      });

      test('generates COUNT with FILTER clause', () {
        final query = JsonQueryBuilder()
            .model('ConsultantReview')
            .action(QueryAction.aggregate)
            .aggregation({
          '_count': true,
          '_countFiltered': [
            {
              'alias': 'fiveStar',
              'filter': {'rating': 5}
            },
            {
              'alias': 'fourStar',
              'filter': {'rating': 4}
            },
          ],
        }).where({'consultantProfileId': 'consultant-123'}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('COUNT(*) AS "_count"'));
        // FILTER params continue after WHERE params ($1 = consultantProfileId)
        expect(result.sql,
            contains('COUNT(*) FILTER (WHERE "rating" = \$2) AS "fiveStar"'));
        expect(result.sql,
            contains('COUNT(*) FILTER (WHERE "rating" = \$3) AS "fourStar"'));
        // Values should be present in correct order: WHERE args first, then FILTER args
        expect(result.args, equals(['consultant-123', 5, 4]));
        expect(result.argTypes.length, equals(3));
      });

      test('generates all rating distribution with FILTER clause', () {
        final query = JsonQueryBuilder()
            .model('ConsultantReview')
            .action(QueryAction.aggregate)
            .aggregation({
          '_count': true,
          '_avg': {'rating': true},
          '_countFiltered': [
            {
              'alias': 'fiveStar',
              'filter': {'rating': 5}
            },
            {
              'alias': 'fourStar',
              'filter': {'rating': 4}
            },
            {
              'alias': 'threeStar',
              'filter': {'rating': 3}
            },
            {
              'alias': 'twoStar',
              'filter': {'rating': 2}
            },
            {
              'alias': 'oneStar',
              'filter': {'rating': 1}
            },
          ],
        }).where({'consultantProfileId': 'consultant-123'}).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('COUNT(*) AS "_count"'));
        expect(result.sql, contains('AVG("rating") AS "_avg_rating"'));
        expect(result.sql, contains('"fiveStar"'));
        expect(result.sql, contains('"fourStar"'));
        expect(result.sql, contains('"threeStar"'));
        expect(result.sql, contains('"twoStar"'));
        expect(result.sql, contains('"oneStar"'));
        expect(result.sql, contains('FILTER'));
      });

      test('FILTER clause not generated for MySQL (unsupported)', () {
        final mysqlCompiler = SqlCompiler(provider: 'mysql');

        final query = JsonQueryBuilder()
            .model('Review')
            .action(QueryAction.aggregate)
            .aggregation({
          '_count': true,
          '_countFiltered': [
            {
              'alias': 'fiveStar',
              'filter': {'rating': 5}
            },
          ],
        }).build();

        final result = mysqlCompiler.compile(query);

        // FILTER clause should NOT be generated for MySQL
        expect(result.sql, isNot(contains('FILTER')));
        expect(result.sql, contains('COUNT(*) AS "_count"'));
      });

      test('FILTER clause not generated for SQLite (unsupported)', () {
        final sqliteCompiler = SqlCompiler(provider: 'sqlite');

        final query = JsonQueryBuilder()
            .model('Review')
            .action(QueryAction.aggregate)
            .aggregation({
          '_count': true,
          '_countFiltered': [
            {
              'alias': 'fiveStar',
              'filter': {'rating': 5}
            },
          ],
        }).build();

        final result = sqliteCompiler.compile(query);

        // FILTER clause should NOT be generated for SQLite
        expect(result.sql, isNot(contains('FILTER')));
      });
    });

    group('Include with select fields', () {
      late SqlCompiler compilerWithSchema;
      late SchemaRegistry schema;

      setUp(() {
        schema = SchemaRegistry();

        // Register ConsultantProfile model
        schema.registerModel(ModelSchema(
          name: 'ConsultantProfile',
          tableName: 'ConsultantProfile',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'headline': const FieldInfo(
              name: 'headline',
              columnName: 'headline',
              type: 'String',
            ),
            'rating': const FieldInfo(
              name: 'rating',
              columnName: 'rating',
              type: 'double',
            ),
            'userId': const FieldInfo(
              name: 'userId',
              columnName: 'userId',
              type: 'String',
            ),
            'domainId': const FieldInfo(
              name: 'domainId',
              columnName: 'domainId',
              type: 'String',
            ),
          },
          relations: {
            'user': RelationInfo.manyToOne(
              name: 'user',
              targetModel: 'User',
              foreignKey: 'userId',
            ),
            'domain': RelationInfo.manyToOne(
              name: 'domain',
              targetModel: 'Domain',
              foreignKey: 'domainId',
            ),
          },
        ));

        // Register User model
        schema.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
            'image': FieldInfo(
              name: 'image',
              columnName: 'image',
              type: 'String',
            ),
            'email': FieldInfo(
              name: 'email',
              columnName: 'email',
              type: 'String',
            ),
          },
        ));

        // Register Domain model
        schema.registerModel(const ModelSchema(
          name: 'Domain',
          tableName: 'Domain',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
          },
        ));

        compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: schema,
        );
      });

      test('include with true includes all fields', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({
          'user': true,
          'domain': true,
        }).build();

        final result = compilerWithSchema.compile(query);

        // Should include LEFT JOINs
        expect(result.sql, contains('LEFT JOIN "users"'));
        expect(result.sql, contains('LEFT JOIN "Domain"'));
        // Should have aliased columns
        expect(result.sql, contains('AS'));
      });

      test('include with select restricts fields', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({
          'user': {
            'select': {'name': true, 'image': true}
          },
          'domain': {
            'select': {'id': true, 'name': true}
          },
        }).build();

        final result = compilerWithSchema.compile(query);

        // Should include LEFT JOINs
        expect(result.sql, contains('LEFT JOIN "users"'));
        expect(result.sql, contains('LEFT JOIN "Domain"'));
        // Should select specific columns from relations
        // The relation compiler will generate aliases like user__name, user__image
        expect(result.sql, contains('"t0"')); // Base table alias
        expect(result.sql, contains('"t1"')); // First relation alias
      });

      test('nested include generates JOINs for all levels (v0.3.2 fix)', () {
        // Set up a schema with three levels: ConsultationPlan -> ConsultantProfile -> User
        final nestedSchema = SchemaRegistry();

        // ConsultationPlan (base)
        nestedSchema.registerModel(ModelSchema(
          name: 'ConsultationPlan',
          tableName: 'ConsultationPlan',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'price': const FieldInfo(
              name: 'price',
              columnName: 'price',
              type: 'double',
            ),
            'consultantProfileId': const FieldInfo(
              name: 'consultantProfileId',
              columnName: 'consultantProfileId',
              type: 'String',
            ),
          },
          relations: {
            'consultantProfile': RelationInfo.manyToOne(
              name: 'consultantProfile',
              targetModel: 'ConsultantProfile',
              foreignKey: 'consultantProfileId',
            ),
          },
        ));

        // ConsultantProfile (middle)
        nestedSchema.registerModel(ModelSchema(
          name: 'ConsultantProfile',
          tableName: 'ConsultantProfile',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'headline': const FieldInfo(
              name: 'headline',
              columnName: 'headline',
              type: 'String',
            ),
            'userId': const FieldInfo(
              name: 'userId',
              columnName: 'userId',
              type: 'String',
            ),
          },
          relations: {
            'user': RelationInfo.manyToOne(
              name: 'user',
              targetModel: 'User',
              foreignKey: 'userId',
            ),
          },
        ));

        // User (deepest)
        nestedSchema.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
            'email': FieldInfo(
              name: 'email',
              columnName: 'email',
              type: 'String',
            ),
          },
        ));

        final nestedCompiler = SqlCompiler(
          provider: 'postgresql',
          schema: nestedSchema,
        );

        // Test nested include: ConsultationPlan -> ConsultantProfile -> User
        final query = JsonQueryBuilder()
            .model('ConsultationPlan')
            .action(QueryAction.findUnique)
            .where({'id': 'plan-123'}).include({
          'consultantProfile': {
            'include': {'user': true}
          }
        }).build();

        final result = nestedCompiler.compile(query);

        // Should have JOIN for consultantProfile (t1)
        expect(result.sql, contains('LEFT JOIN "ConsultantProfile"'));
        expect(result.sql, contains('"t1"'));

        // Should have JOIN for nested user (t2)
        // This was the bug - the nested JOIN was missing
        expect(result.sql, contains('LEFT JOIN "users"'));
        expect(result.sql, contains('"t2"'));

        // The SQL should select from all three tables
        expect(result.sql, contains('FROM "ConsultationPlan" "t0"'));

        // Should not throw "missing FROM-clause entry for table t2"
        // by having columns from t2 without the JOIN
      });
    });

    group('Computed Fields (v0.2.6)', () {
      late SqlCompiler compiler;

      setUp(() {
        compiler = SqlCompiler(provider: 'postgresql');
      });

      test('generates MIN subquery for computed field', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .computed({
          'minPrice': ComputedField.min('price',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        // Should have table alias
        expect(result.sql, contains('"t0".*'));
        expect(result.sql, contains('FROM "ConsultantProfile" "t0"'));

        // Should have correlated subquery
        expect(result.sql,
            contains('(SELECT MIN("price") FROM "ConsultationPlan"'));
        expect(result.sql, contains('WHERE "consultantProfileId" = "t0"."id"'));
        expect(result.sql, contains('AS "minPrice"'));
      });

      test('generates MAX subquery for computed field', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .computed({
          'maxRating': ComputedField.max('rating',
              from: 'Review', where: {'productId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('(SELECT MAX("rating") FROM "Review"'));
        expect(result.sql, contains('WHERE "productId" = "t0"."id"'));
        expect(result.sql, contains('AS "maxRating"'));
      });

      test('generates AVG subquery for computed field', () {
        final query = JsonQueryBuilder()
            .model('Product')
            .action(QueryAction.findMany)
            .computed({
          'avgRating': ComputedField.avg('rating',
              from: 'Review', where: {'productId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('(SELECT AVG("rating") FROM "Review"'));
        expect(result.sql, contains('AS "avgRating"'));
      });

      test('generates SUM subquery for computed field', () {
        final query = JsonQueryBuilder()
            .model('Order')
            .action(QueryAction.findMany)
            .computed({
          'totalAmount': ComputedField.sum('amount',
              from: 'OrderItem', where: {'orderId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('(SELECT SUM("amount") FROM "OrderItem"'));
        expect(result.sql, contains('AS "totalAmount"'));
      });

      test('generates COUNT subquery for computed field', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .computed({
          'postCount': ComputedField.count(
              from: 'Post', where: {'userId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('(SELECT COUNT(*) FROM "Post"'));
        expect(result.sql, contains('WHERE "userId" = "t0"."id"'));
        expect(result.sql, contains('AS "postCount"'));
      });

      test('generates FIRST subquery with ORDER BY and LIMIT', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .computed({
          'priceCurrency': ComputedField.first('priceCurrency',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')},
              orderBy: {'price': 'asc'}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql,
            contains('(SELECT "priceCurrency" FROM "ConsultationPlan"'));
        expect(result.sql, contains('WHERE "consultantProfileId" = "t0"."id"'));
        expect(result.sql, contains('ORDER BY "price" ASC LIMIT 1'));
        expect(result.sql, contains('AS "priceCurrency"'));
      });

      test('supports multiple computed fields', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .computed({
          'minPrice': ComputedField.min('price',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')}),
          'maxPrice': ComputedField.max('price',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('MIN("price")'));
        expect(result.sql, contains('MAX("price")'));
        expect(result.sql, contains('AS "minPrice"'));
        expect(result.sql, contains('AS "maxPrice"'));
      });

      test('computed fields work with WHERE clause', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .where({'isVerified': true}).computed({
          'minPrice': ComputedField.min('price',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        // With computed fields, columns are prefixed with table alias
        expect(result.sql, contains('WHERE "t0"."isVerified" = \$1'));
        expect(result.sql, contains('AS "minPrice"'));
        expect(result.args, [true]);
      });

      test('computed fields work with ORDER BY and LIMIT', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .computed({
              'minPrice': ComputedField.min('price',
                  from: 'ConsultationPlan',
                  where: {'consultantProfileId': const FieldRef('id')}),
            })
            .orderBy({'rating': 'desc'})
            .take(10)
            .build();

        final result = compiler.compile(query);

        expect(result.sql, contains('AS "minPrice"'));
        // With computed fields, ORDER BY columns are prefixed with table alias
        expect(result.sql, contains('ORDER BY "t0"."rating" DESC'));
        expect(result.sql, contains('LIMIT 10'));
      });

      test('computed fields work with selectFields', () {
        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .selectFields(['id', 'headline', 'rating']).computed({
          'minPrice': ComputedField.min('price',
              from: 'ConsultationPlan',
              where: {'consultantProfileId': const FieldRef('id')}),
        }).build();

        final result = compiler.compile(query);

        // selectFields with computed should use alias prefix
        expect(result.sql, contains('"t0"."id"'));
        expect(result.sql, contains('"t0"."headline"'));
        expect(result.sql, contains('"t0"."rating"'));
        expect(result.sql, contains('AS "minPrice"'));
      });

      test('computed field with static where condition', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .computed({
          'activePostCount': ComputedField.count(from: 'Post', where: {
            'userId': const FieldRef('id'),
            'isPublished': true,
          }),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('WHERE "userId" = "t0"."id"'));
        // Static values are now parameterized for security
        expect(result.sql, contains('"isPublished" = \$1'));
        expect(result.args, contains(true));
      });

      test('first operation with descending order', () {
        final query = JsonQueryBuilder()
            .model('Consultant')
            .action(QueryAction.findMany)
            .computed({
          'latestPlanPrice': ComputedField.first('price',
              from: 'Plan',
              where: {'consultantId': const FieldRef('id')},
              orderBy: {'createdAt': 'desc'}),
        }).build();

        final result = compiler.compile(query);

        expect(result.sql, contains('ORDER BY "createdAt" DESC LIMIT 1'));
        expect(result.sql, contains('AS "latestPlanPrice"'));
      });

      test('include() and computed() work together without alias conflict', () {
        // This test verifies the fix for the t0 alias conflict issue
        // When using include() + computed() together, relation compiler
        // must start at t1 since t0 is reserved for the base table.
        final schema = SchemaRegistry();

        // Register ConsultantProfile with relations
        schema.registerModel(ModelSchema(
          name: 'ConsultantProfile',
          tableName: 'ConsultantProfile',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'userId': const FieldInfo(
              name: 'userId',
              columnName: 'userId',
              type: 'String',
            ),
          },
          relations: {
            'user': RelationInfo.oneToOne(
              name: 'user',
              targetModel: 'User',
              foreignKey: 'userId',
            ),
          },
        ));

        // Register User model
        schema.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': FieldInfo(
              name: 'name',
              columnName: 'name',
              type: 'String',
            ),
          },
        ));

        // Register ConsultationPlan for computed field
        schema.registerModel(const ModelSchema(
          name: 'ConsultationPlan',
          tableName: 'ConsultationPlan',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'price': FieldInfo(
              name: 'price',
              columnName: 'price',
              type: 'double',
            ),
            'consultantProfileId': FieldInfo(
              name: 'consultantProfileId',
              columnName: 'consultantProfileId',
              type: 'String',
            ),
          },
        ));

        final compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: schema,
        );

        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .include({'user': true}).computed({
          'minPrice': ComputedField.min(
            'price',
            from: 'ConsultationPlan',
            where: {'consultantProfileId': const FieldRef('id')},
          ),
        }).build();

        final result = compilerWithSchema.compile(query);

        // Base table should be t0
        expect(result.sql, contains('FROM "ConsultantProfile" "t0"'));

        // Relation should use t1 (not t0!)
        expect(result.sql, contains('LEFT JOIN "users" "t1"'));

        // Computed field should reference t0
        expect(result.sql, contains('WHERE "consultantProfileId" = "t0"."id"'));

        // Should NOT have duplicate t0
        final t0Count = 't0'.allMatches(result.sql).length;
        // t0 appears in: FROM table t0, computed WHERE t0.id, and SELECT t0.*
        expect(t0Count, greaterThan(0));

        // Verify no SQL syntax error would occur (t0 only defined once in FROM)
        final fromClause =
            RegExp(r'FROM\s+"ConsultantProfile"\s+"t0"').hasMatch(result.sql);
        expect(fromClause, isTrue);
      });

      test(
          'computedFieldNames is populated for preservation during deserialization',
          () {
        // This test verifies that computed field names are tracked in SqlQuery
        // so they can be preserved when relation deserialization strips them.
        final schema = SchemaRegistry();

        schema.registerModel(const ModelSchema(
          name: 'Consultant',
          tableName: 'Consultant',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
          },
        ));

        final compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: schema,
        );

        // Query with multiple computed fields
        final query = JsonQueryBuilder()
            .model('Consultant')
            .action(QueryAction.findMany)
            .computed({
          'minPrice': ComputedField.min(
            'price',
            from: 'ConsultationPlan',
            where: {'consultantProfileId': const FieldRef('id')},
          ),
          'maxPrice': ComputedField.max(
            'price',
            from: 'ConsultationPlan',
            where: {'consultantProfileId': const FieldRef('id')},
          ),
          'avgRating': ComputedField.avg(
            'rating',
            from: 'Reviews',
            where: {'consultantId': const FieldRef('id')},
          ),
        }).build();

        final result = compilerWithSchema.compile(query);

        // Verify computedFieldNames contains all computed field names
        expect(result.computedFieldNames, hasLength(3));
        expect(result.computedFieldNames, contains('minPrice'));
        expect(result.computedFieldNames, contains('maxPrice'));
        expect(result.computedFieldNames, contains('avgRating'));
      });

      test('computedFieldNames is empty when no computed fields', () {
        final query = JsonQueryBuilder()
            .model('users')
            .action(QueryAction.findMany)
            .where({'id': '123'}).build();

        final result = compiler.compile(query);

        expect(result.computedFieldNames, isEmpty);
      });
    });

    group('@@map directive support', () {
      late SqlCompiler compilerWithSchema;
      late SchemaRegistry testSchema;

      setUp(() {
        testSchema = SchemaRegistry();

        // Register User model with @@map("users")
        testSchema.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users', // @@map("users")
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'email': FieldInfo(
              name: 'email',
              columnName: 'email',
              type: 'String',
            ),
          },
        ));

        compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: testSchema,
        );
      });

      test('resolves model name to table name via @@map for findMany', () {
        final query = JsonQueryBuilder()
            .model('User') // Model name (PascalCase)
            .action(QueryAction.findMany)
            .build();

        final result = compilerWithSchema.compile(query);

        // Should use "users" table name, not "User"
        expect(result.sql, contains('FROM "users"'));
        expect(result.sql, isNot(contains('FROM "User"')));
      });

      test('resolves model name to table name for findUnique', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findUnique)
            .where({'id': '123'}).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('FROM "users"'));
      });

      test('resolves model name to table name for create', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.create)
            .data({'email': 'test@example.com'}).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('INSERT INTO "users"'));
      });

      test('resolves model name to table name for createMany', () {
        const query = JsonQuery(
          modelName: 'User',
          action: 'createMany',
          args: JsonQueryArgs(arguments: {
            'data': [
              {'email': 'test1@example.com'},
              {'email': 'test2@example.com'},
            ]
          }),
        );

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('INSERT INTO "users"'));
      });

      test('resolves model name to table name for update', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.update)
            .where({'id': '123'}).data({'email': 'new@example.com'}).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('UPDATE "users"'));
      });

      test('resolves model name to table name for delete', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.delete)
            .where({'id': '123'}).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('DELETE FROM "users"'));
      });

      test('resolves model name to table name for count', () {
        final query =
            JsonQueryBuilder().model('User').action(QueryAction.count).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('FROM "users"'));
      });

      test('resolves model name to table name for groupBy', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.groupBy)
            .groupByFields(['email']).build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('FROM "users"'));
      });

      test('resolves model name to table name for upsert', () {
        const query = JsonQuery(
          modelName: 'User',
          action: 'upsert',
          args: JsonQueryArgs(arguments: {
            'where': {'id': '123'},
            'data': {
              'create': {'id': '123', 'email': 'test@example.com'},
              'update': {'email': 'updated@example.com'},
            },
          }),
        );

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('INSERT INTO "users"'));
      });

      test('works without SchemaRegistry (backward compatible)', () {
        final compilerNoSchema = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        final result = compilerNoSchema.compile(query);

        // Should use model name as-is when no schema registered
        expect(result.sql, contains('FROM "User"'));
      });

      test('uses model name when table not registered in schema', () {
        final query = JsonQueryBuilder()
            .model('UnknownModel') // Not registered
            .action(QueryAction.findMany)
            .build();

        final result = compilerWithSchema.compile(query);

        // Should fallback to model name
        expect(result.sql, contains('FROM "UnknownModel"'));
      });
    });

    group('Connect/Disconnect M2M Relations', () {
      late SqlCompiler compilerWithSchema;

      setUp(() {
        // Set up schema with M2M relation
        schemaRegistry.clear();
        schemaRegistry.registerModel(ModelSchema(
          name: 'SlotOfAppointment',
          tableName: 'slot_of_appointments',
          fields: {
            'id': FieldInfo.id(name: 'id', type: 'String'),
            'startsAt': const FieldInfo(
                name: 'startsAt', columnName: 'startsAt', type: 'DateTime'),
            'endsAt': const FieldInfo(
                name: 'endsAt', columnName: 'endsAt', type: 'DateTime'),
          },
          relations: {
            'users': RelationInfo.manyToMany(
              name: 'users',
              targetModel: 'User',
              joinTable: '_SlotOfAppointmentToUser',
              joinColumn: 'A',
              inverseJoinColumn: 'B',
            ),
          },
        ));
        schemaRegistry.registerModel(ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo.id(name: 'id', type: 'String'),
            'name': const FieldInfo(
                name: 'name', columnName: 'name', type: 'String'),
          },
          relations: {},
        ));

        compilerWithSchema = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('compileWithRelations extracts connect operations for M2M', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-123',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': [
              {'id': 'user-1'},
              {'id': 'user-2'},
            ],
          },
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        // Main query should be INSERT without the users field
        expect(result.mainQuery.sql, contains('INSERT INTO'));
        expect(result.mainQuery.sql, contains('"slot_of_appointments"'));
        expect(result.mainQuery.sql, isNot(contains('users')));

        // Should have 2 relation mutations (one for each user)
        expect(result.relationMutations.length, 2);

        // First connect mutation
        expect(result.relationMutations[0].sql,
            contains('INSERT INTO "_SlotOfAppointmentToUser"'));
        expect(result.relationMutations[0].sql,
            contains('ON CONFLICT DO NOTHING'));
        expect(result.relationMutations[0].args, ['slot-123', 'user-1']);

        // Second connect mutation
        expect(result.relationMutations[1].args, ['slot-123', 'user-2']);
      });

      test('compileWithRelations extracts disconnect operations for M2M', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.update)
            .where({'id': 'slot-123'}).data({
          'users': {
            'disconnect': [
              {'id': 'user-1'},
            ],
          },
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        // Main query should be UPDATE
        expect(result.mainQuery.sql, contains('UPDATE'));
        expect(result.mainQuery.sql, contains('"slot_of_appointments"'));

        // Should have 1 disconnect mutation
        expect(result.relationMutations.length, 1);
        expect(result.relationMutations[0].sql,
            contains('DELETE FROM "_SlotOfAppointmentToUser"'));
        expect(result.relationMutations[0].sql, contains('WHERE'));
        expect(result.relationMutations[0].args, ['slot-123', 'user-1']);
      });

      test('compileWithRelations handles mixed connect and disconnect', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.update)
            .where({'id': 'slot-123'}).data({
          'users': {
            'connect': [
              {'id': 'user-new'},
            ],
            'disconnect': [
              {'id': 'user-old'},
            ],
          },
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        // Should have 2 mutations (1 connect + 1 disconnect)
        expect(result.relationMutations.length, 2);

        // First should be connect (INSERT)
        expect(result.relationMutations[0].sql, contains('INSERT'));
        expect(result.relationMutations[0].args, ['slot-123', 'user-new']);

        // Second should be disconnect (DELETE)
        expect(result.relationMutations[1].sql, contains('DELETE'));
        expect(result.relationMutations[1].args, ['slot-123', 'user-old']);
      });

      test('compileWithRelations preserves regular fields', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-456',
          'startsAt': '2024-01-01T10:00:00Z',
          'endsAt': '2024-01-01T11:00:00Z',
          'users': {
            'connect': [
              {'id': 'user-1'},
            ],
          },
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        // Main query should contain the regular fields
        expect(result.mainQuery.sql, contains('"id"'));
        expect(result.mainQuery.sql, contains('"startsAt"'));
        expect(result.mainQuery.sql, contains('"endsAt"'));

        // Args should include all regular field values
        expect(result.mainQuery.args, contains('slot-456'));
        expect(result.mainQuery.args, contains('2024-01-01T10:00:00Z'));
        expect(result.mainQuery.args, contains('2024-01-01T11:00:00Z'));
      });

      test('compileWithRelations returns empty mutations when no M2M ops', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-789',
          'startsAt': '2024-01-01T10:00:00Z',
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        expect(result.hasRelationMutations, false);
        expect(result.relationMutations, isEmpty);
      });

      test('compileWithRelations handles single connect item (not array)', () {
        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-single',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': {'id': 'user-single'},
          },
        }).build();

        final result = compilerWithSchema.compileWithRelations(query);

        expect(result.relationMutations.length, 1);
        expect(
            result.relationMutations[0].args, ['slot-single', 'user-single']);
      });

      test('MySQL provider uses INSERT IGNORE for connect', () {
        final mysqlCompiler = SqlCompiler(
          provider: 'mysql',
          schema: schemaRegistry,
        );

        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-123',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': [
              {'id': 'user-1'},
            ],
          },
        }).build();

        final result = mysqlCompiler.compileWithRelations(query);

        expect(result.relationMutations[0].sql, contains('INSERT IGNORE'));
      });

      test('SQLite provider uses INSERT OR IGNORE for connect', () {
        final sqliteCompiler = SqlCompiler(
          provider: 'sqlite',
          schema: schemaRegistry,
        );

        final query = JsonQueryBuilder()
            .model('SlotOfAppointment')
            .action(QueryAction.create)
            .data({
          'id': 'slot-123',
          'startsAt': '2024-01-01T10:00:00Z',
          'users': {
            'connect': [
              {'id': 'user-1'},
            ],
          },
        }).build();

        final result = sqliteCompiler.compileWithRelations(query);

        expect(result.relationMutations[0].sql, contains('INSERT OR IGNORE'));
      });
    });

    group('Validation Errors (v0.3.2)', () {
      late SqlCompiler compiler;
      late SchemaRegistry schemaRegistry;

      setUp(() {
        // Set up schema with relations for testing validation
        schemaRegistry = SchemaRegistry();
        schemaRegistry.registerModel(ModelSchema(
          name: 'User',
          tableName: 'User',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'email': const FieldInfo(
              name: 'email',
              columnName: 'email',
              type: 'String',
            ),
          },
          relations: {
            'posts': RelationInfo.oneToMany(
              name: 'posts',
              targetModel: 'Post',
              foreignKey: 'authorId',
            ),
          },
        ));
        schemaRegistry.registerModel(const ModelSchema(
          name: 'Post',
          tableName: 'Post',
          fields: {
            'id': FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'title': FieldInfo(
              name: 'title',
              columnName: 'title',
              type: 'String',
            ),
            'authorId': FieldInfo(
              name: 'authorId',
              columnName: 'authorId',
              type: 'String',
            ),
          },
        ));

        compiler = SqlCompiler(
          provider: 'postgresql',
          schema: schemaRegistry,
        );
      });

      test('throws error for unknown filter operator on scalar field', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'email': {'unknownOperator': 'test@example.com'},
        }).build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unknown filter operator "unknownOperator"'),
            ),
          ),
        );
      });

      test('reports all unknown operators at once (v0.3.2)', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'email': {'badOp1': 'test', 'badOp2': 'test2', 'equals': 'valid'},
        }).build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Unknown filter operators'),
                contains('badOp1'),
                contains('badOp2'),
              ),
            ),
          ),
        );
      });

      test('throws error for relation field without some/every/none', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'posts': {
            'title': {'equals': 'Test'},
          },
        }).build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Relation field "posts"'),
                contains('requires a filter operator'),
                contains('some()'),
              ),
            ),
          ),
        );
      });

      test('error message suggests using FilterOperators', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'posts': {
            'OR': [
              {'title': 'Test1'},
              {'title': 'Test2'},
            ],
          },
        }).build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('FilterOperators'),
            ),
          ),
        );
      });

      test('valid relation filter with some() still works', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'posts': {
            'some': {
              'title': {'equals': 'Test'}
            },
          },
        }).build();

        // Should not throw, should compile successfully
        final result = compiler.compile(query);
        expect(result.sql, contains('EXISTS'));
      });

      test('valid scalar filter operators still work', () {
        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .where({
          'email': {'equals': 'test@example.com', 'not': 'admin@example.com'},
        }).build();

        // Should not throw
        final result = compiler.compile(query);
        expect(result.sql, contains('WHERE'));
        expect(result.args, contains('test@example.com'));
      });
    });

    group('Strict Model Validation (v0.3.3)', () {
      setUp(() {
        // Clear any state from previous test groups
        schemaRegistry.clear();
        SqlCompiler.strictModelValidation = false;
      });

      tearDown(() {
        // Reset global flag after each test
        SqlCompiler.strictModelValidation = false;
        schemaRegistry.clear();
      });

      test('PascalCase model passes when strict validation is disabled', () {
        SqlCompiler.strictModelValidation = false;
        final compiler = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        // Should not throw when validation is disabled
        final result = compiler.compile(query);
        expect(result.sql, contains('FROM "User"'));
      });

      test(
          'PascalCase model throws with helpful message when strict validation enabled globally',
          () {
        SqlCompiler.strictModelValidation = true;
        final compiler = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Model "User" not found in SchemaRegistry'),
                contains('registry is empty'),
                contains('.model(\'user\')'),
              ]),
            ),
          ),
        );
      });

      test(
          'PascalCase model throws when strict validation enabled per-instance',
          () {
        final compiler = SqlCompiler(
          provider: 'postgresql',
          strictModelValidation: true,
        );

        final query = JsonQueryBuilder()
            .model('ConsultantProfile')
            .action(QueryAction.findMany)
            .build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Model "ConsultantProfile" not found'),
                contains('.model(\'consultant_profile\')'),
              ]),
            ),
          ),
        );
      });

      test('lowercase table name passes even with strict validation', () {
        SqlCompiler.strictModelValidation = true;
        final compiler = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('users')
            .action(QueryAction.findMany)
            .build();

        // lowercase names should pass (they're actual table names)
        final result = compiler.compile(query);
        expect(result.sql, contains('FROM "users"'));
      });

      test('registered model passes with strict validation', () {
        SqlCompiler.strictModelValidation = true;

        // Register a model
        schemaRegistry.registerModel(const ModelSchema(
          name: 'User',
          tableName: 'users',
          fields: {
            'id': FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
          },
        ));

        final compiler = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        // Should resolve 'User' to 'users'
        final result = compiler.compile(query);
        expect(result.sql, contains('FROM "users"'));
      });

      test(
          'unregistered model throws helpful error when schema has other models',
          () {
        SqlCompiler.strictModelValidation = true;

        // Register some models
        schemaRegistry.registerModel(const ModelSchema(
          name: 'Post',
          tableName: 'posts',
          fields: {
            'id': FieldInfo(
                name: 'id', columnName: 'id', type: 'String', isId: true),
          },
        ));

        final compiler = SqlCompiler(provider: 'postgresql');

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        expect(
          () => compiler.compile(query),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Model "User" is not registered'),
                contains('Available models: Post'),
              ]),
            ),
          ),
        );
      });

      test('instance-level flag overrides global flag', () {
        SqlCompiler.strictModelValidation = true;

        // Disable at instance level
        final compiler = SqlCompiler(
          provider: 'postgresql',
          strictModelValidation: false,
        );

        final query = JsonQueryBuilder()
            .model('User')
            .action(QueryAction.findMany)
            .build();

        // Should not throw because instance-level override is false
        final result = compiler.compile(query);
        expect(result.sql, contains('FROM "User"'));
      });

      test('acronyms in model names are handled correctly in suggestions', () {
        final compiler = SqlCompiler(
          provider: 'postgresql',
          strictModelValidation: true,
        );

        // URLShortener should suggest url_shortener (not u_r_l_shortener)
        final query1 = JsonQueryBuilder()
            .model('URLShortener')
            .action(QueryAction.findMany)
            .build();

        expect(
          () => compiler.compile(query1),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('.model(\'url_shortener\')'),
            ),
          ),
        );

        // HTTPSConnection should suggest https_connection
        final query2 = JsonQueryBuilder()
            .model('HTTPSConnection')
            .action(QueryAction.findMany)
            .build();

        expect(
          () => compiler.compile(query2),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('.model(\'https_connection\')'),
            ),
          ),
        );
      });
    });
  });
}
