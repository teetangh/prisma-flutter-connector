import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

void main() {
  group('CbDelegateGenerator composite @@id models', () {
    late PrismaParser parser;

    setUp(() {
      parser = PrismaParser();
    });

    test('omits unique-keyed methods when model has no unique scalar field',
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

      // Must not throw (previously emitted invalid Dart for these models)
      final code = generator.generateDelegate(parsed.models.first);

      expect(code, isNot(contains('findUnique')));
      expect(code, isNot(contains('WhereUniqueInput')));
      expect(code, contains('findMany'));
      expect(code, contains('findFirst'));
      expect(code, contains('updateMany'));
      expect(code, contains('deleteMany'));
      // @@map flows into the generated table name
      expect(code, contains('org_invoice_counters'));
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

    test('upsert is omitted for composite-@@id-only models', () {
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

      expect(code, isNot(contains('upsert(')));
    });
  });
}
