import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

void main() {
  group('CbDelegateGenerator composite @@id models', () {
    late PrismaParser parser;

    setUp(() {
      parser = PrismaParser();
    });

    test('composite @@id models get unique-keyed methods via the compound key',
        () {
      const schema = '''
model OrgInvoiceCounter {
  organizationId String
  fiscalYear     String
  lastNumber     Int    @default(0)

  @@id([organizationId, fiscalYear])
  @@map("org_invoice_counters")
}
''';

      final parsed = parser.parse(schema);
      final generator = CbDelegateGenerator(parsed, serverMode: true);

      // Must not throw, and now DOES get unique-keyed methods keyed by the
      // compound @@id (C6). WhereUniqueInput exists and carries the compound.
      final code = generator.generateDelegate(parsed.models.first);

      expect(code, contains('findUnique'));
      expect(code, contains('OrgInvoiceCounterWhereUniqueInput'));
      expect(code, contains('findMany'));
      expect(code, contains('updateMany'));
      expect(code, contains('deleteMany'));
      // @@map flows into the generated table name
      expect(code, contains('org_invoice_counters'));
    });

    test('model with no field-level or composite unique omits unique methods',
        () {
      const schema = '''
model AuditLine {
  message String
  at      DateTime @default(now())
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);
      expect(code, isNot(contains('findUnique')));
      expect(code, isNot(contains('WhereUniqueInput')));
      expect(code, contains('findMany'));
    });

    test('keeps unique-keyed methods for models with @id field', () {
      const schema = '''
model User {
  id    String @id @default(cuid())
  email String @unique
}
''';

      final parsed = parser.parse(schema);
      final generator = CbDelegateGenerator(parsed, serverMode: true);

      final code = generator.generateDelegate(parsed.models.first);

      expect(code, contains('findUnique'));
      expect(code, contains('UserWhereUniqueInput'));
    });

    test('upsert is generated for models with a unique field', () {
      const schema = '''
model User {
  id    String @id @default(cuid())
  email String @unique
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);

      expect(code, contains('Future<User> upsert('));
      expect(code, contains('CreateUserInput create'));
      expect(code, contains('UpdateUserInput update'));
      expect(code, contains('QueryAction.upsert'));
    });

    test('findMany/findFirst take a typed XInclude param', () {
      const schema = '''
model Post {
  id       String @id
  author   User   @relation(fields: [authorId], references: [id])
  authorId String
}
model User { id String @id }
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);
      expect(code, contains('PostInclude? include'));
      expect(code, isNot(contains("include: refer('Map<String, dynamic>?')")));
      expect(code, contains('include.toJson()'));
    });

    test('findMany takes a typed cursor param wired to the query builder', () {
      const schema = '''
model Post {
  id       String @id
  authorId String
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);
      expect(code, contains('PostWhereUniqueInput? cursor'));
      expect(code, contains('queryBuilder.cursor(_whereUniqueToJson(cursor))'));
    });

    test('unique-less model omits the cursor param', () {
      const schema = '''
model AuditLine {
  message String
  at      DateTime @default(now())
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);
      expect(code, isNot(contains('cursor')));
    });

    test('aggregate + findFirstOrThrow are generated', () {
      const schema = '''
model User {
  id     String @id @default(cuid())
  rating Int
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);

      expect(code, contains('Future<Map<String, dynamic>> aggregate('));
      expect(code, contains('QueryAction.aggregate'));
      expect(code, contains('Future<User> findFirstOrThrow('));
    });

    test('upsert IS generated for composite-@@id models', () {
      const schema = '''
model OrgInvoiceCounter {
  organizationId String
  fiscalYear     String
  lastNumber     Int    @default(0)

  @@id([organizationId, fiscalYear])
}
''';
      final parsed = parser.parse(schema);
      final code = CbDelegateGenerator(parsed, serverMode: true)
          .generateDelegate(parsed.models.first);

      expect(code, contains('upsert('));
    });
  });
}
