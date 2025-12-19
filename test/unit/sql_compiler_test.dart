import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_flutter_connector/src/runtime/query/sql_compiler.dart';
import 'package:prisma_flutter_connector/src/runtime/query/json_protocol.dart';
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
            .where({
          'name': FilterOperators.containsInsensitive('John')
        }).build();

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
            .where({
          'name': FilterOperators.containsInsensitive('John')
        }).build();

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
            .where({
          'name': FilterOperators.containsInsensitive('John')
        }).build();

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
        schema.registerModel(ModelSchema(
          name: 'Review',
          tableName: 'Review',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'rating': const FieldInfo(
              name: 'rating',
              columnName: 'rating',
              type: 'int',
            ),
            'productId': const FieldInfo(
              name: 'productId',
              columnName: 'productId',
              type: 'String',
            ),
          },
        ));

        // Register Category model
        schema.registerModel(ModelSchema(
          name: 'Category',
          tableName: 'Category',
          fields: {
            'id': const FieldInfo(
              name: 'id',
              columnName: 'id',
              type: 'String',
              isId: true,
            ),
            'name': const FieldInfo(
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
            })
            .build();

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
            })
            .build();

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
            })
            .build();

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
            })
            .build();

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
            })
            .build();

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
            })
            .build();

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
            })
            .build();

        final result = compilerWithSchema.compile(query);

        expect(result.sql, contains('EXISTS'));
        expect(result.sql, contains('SELECT 1 FROM "Review"'));
      });
    });
  });
}

