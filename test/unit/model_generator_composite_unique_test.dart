import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Collapse whitespace so assertions ignore dart_style line-wrapping.
String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('CbModelGenerator composite unique keys (#C6)', () {
    test('@@id([a,b]) generates a compound-unique input + flatten toJson', () {
      const schema = '''
model OrgInvoiceCounter {
  organizationId String
  fiscalYear     String
  lastNumber     Int    @default(0)

  @@id([organizationId, fiscalYear])
}
''';
      final parsed = PrismaParser().parse(schema);
      final code = CbModelGenerator(parsed).generateModel(parsed.models.first);
      final flat = _flat(code);

      // Compound input class with both typed fields
      expect(
          flat,
          contains(
              'class OrgInvoiceCounterOrganizationIdFiscalYearCompoundUnique'));
      expect(flat, contains('required String organizationId'));
      expect(flat, contains('required String fiscalYear'));

      // WhereUniqueInput carries the compound field named a_b
      expect(flat, contains('OrgInvoiceCounterWhereUniqueInput'));
      expect(
          flat,
          contains(
              'OrgInvoiceCounterOrganizationIdFiscalYearCompoundUnique? organizationId_fiscalYear'));

      // WhereUniqueInput.toJson FLATTENS the compound via spread
      expect(flat, contains('...organizationId_fiscalYear!.toJson()'));
      // The compound toJson emits the individual field keys
      expect(flat, contains("'organizationId': organizationId"));
      expect(flat, contains("'fiscalYear': fiscalYear"));
    });

    test('@@unique([a,b]) on a model with an @id also gets a compound input',
        () {
      const schema = '''
model Membership {
  id     String @id @default(cuid())
  userId String
  orgId  String

  @@unique([userId, orgId])
}
''';
      final parsed = PrismaParser().parse(schema);
      final code = CbModelGenerator(parsed).generateModel(parsed.models.first);
      final flat = _flat(code);

      // Both the id field and the compound are addressable
      expect(flat, contains('String? id'));
      expect(
          flat, contains('MembershipUserIdOrgIdCompoundUnique? userId_orgId'));
      expect(flat, contains('...userId_orgId!.toJson()'));
    });

    test('single-field @@unique([x]) does NOT create a compound input', () {
      const schema = '''
model Slug {
  id   String @id
  name String

  @@unique([name])
}
''';
      final parsed = PrismaParser().parse(schema);
      // parser only records composites with >1 field
      expect(parsed.models.first.compositeUniques, isEmpty);
    });
  });
}
