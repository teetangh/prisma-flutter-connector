import 'dart:io';

import 'package:prisma_flutter_connector/src/generator/cb_client_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_filter_types_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_schema_registry_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:test/test.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('Web schema compatibility & atomic delegate codegen', () {
    test(
        'composite @@id marks both fields isId: true in SchemaRegistry and '
        'generates compound PK lookup in Delegate.update(include: ...)', () {
      const schema = '''
model OrgInvoiceCounter {
  organizationId String
  fiscalYear     String
  lastNumber     Int    @default(0)

  @@id([organizationId, fiscalYear])
  @@map("org_invoice_counters")
}
''';

      final parsed = PrismaParser().parse(schema);
      final registryCode =
          _flat(CbSchemaRegistryGenerator(parsed, serverMode: true).generate());
      expect(
        registryCode,
        contains(
          "name: 'organizationId', columnName: 'organizationId', "
          "type: 'String', isId: true",
        ),
      );
      expect(
        registryCode,
        contains(
          "name: 'fiscalYear', columnName: 'fiscalYear', "
          "type: 'String', isId: true",
        ),
      );

      final delegateCode = _flat(
        CbDelegateGenerator(parsed, serverMode: true)
            .generateDelegate(parsed.models.first),
      );
      expect(
        delegateCode,
        contains(
          'OrgInvoiceCounterOrganizationIdFiscalYearCompoundUnique(',
        ),
      );
      expect(
        delegateCode,
        contains("organizationId: updatedRow['organizationId'] as String"),
      );
      expect(
        delegateCode,
        contains("fiscalYear: updatedRow['fiscalYear'] as String"),
      );
    });

    test(
        'WhereUniqueInput maps Prisma Int to Dart int? and single-field '
        '@@unique([field]) is included on WhereUniqueInput', () {
      const schema = '''
model PlatformInvoiceCounter {
  id         Int @id @default(1)
  lastNumber Int @default(0)
}

model SsoProvider {
  id         String @id @default(cuid())
  providerId String

  @@unique([providerId])
}
''';

      final parsed = PrismaParser().parse(schema);
      final modelGen = CbModelGenerator(parsed);

      final counterCode = _flat(modelGen.generateModel(parsed.models[0]));
      expect(counterCode, contains('int? id'));
      expect(counterCode, isNot(contains('Int? id')));

      final ssoCode = _flat(modelGen.generateModel(parsed.models[1]));
      expect(ssoCode, contains('String? providerId'));
    });

    test(
        'OrderByInput includes BigInt and Decimal fields, Decimal fromJson '
        'handles num and String, and Json maps to dynamic', () {
      const schema = '''
model Payment {
  id                     String   @id @default(cuid())
  amountPaise            BigInt
  exchangeRateAtCheckout Decimal?
  requiredRate           Decimal
  payload                Json
  metadata               Json?
}
''';

      final parsed = PrismaParser().parse(schema);
      final code = _flat(
        CbModelGenerator(parsed).generateModel(parsed.models.first),
      );

      // OrderByInput includes BigInt and Decimal fields
      expect(code, contains('SortOrder? amountPaise'));
      expect(code, contains('SortOrder? exchangeRateAtCheckout'));
      expect(code, contains('SortOrder? requiredRate'));
      expect(
        code,
        contains("if (amountPaise != null) 'amountPaise': amountPaise!.name"),
      );
      expect(
        code,
        contains(
          "if (exchangeRateAtCheckout != null) "
          "'exchangeRateAtCheckout': exchangeRateAtCheckout!.name",
        ),
      );

      // Decimal fromJson handles both num and String
      expect(
        code,
        contains(
          "requiredRate: (json['requiredRate'] is num "
          "? (json['requiredRate'] as num).toDouble() "
          ": double.parse(json['requiredRate'].toString()))",
        ),
      );
      expect(
        code,
        contains(
          "exchangeRateAtCheckout: json['exchangeRateAtCheckout'] != null "
          "? (json['exchangeRateAtCheckout'] is num "
          "? (json['exchangeRateAtCheckout'] as num).toDouble() "
          ": double.parse(json['exchangeRateAtCheckout'].toString())) "
          ": null",
        ),
      );

      // Json fields use dynamic (never dynamic? or as Map<String, dynamic>)
      expect(code, contains('required dynamic payload'));
      expect(code, contains('dynamic metadata'));
      expect(code, isNot(contains('dynamic?')));
      expect(code, contains("payload: json['payload']"));
      expect(code, contains("metadata: json['metadata']"));
      expect(code, isNot(contains("json['payload'] as Map<String, dynamic>")));
      expect(code, isNot(contains("json['metadata'] as Map<String, dynamic>")));
    });

    test(
        'Delegate update() and delete() execute atomically in 1 round-trip via '
        'executeMutationAsMap and support include on update() and findUniqueOrThrow()',
        () {
      const schema = '''
model User {
  id    String @id @default(cuid())
  email String @unique
  name  String
}
''';

      final parsed = PrismaParser().parse(schema);
      final code = _flat(
        CbDelegateGenerator(parsed, serverMode: true)
            .generateDelegate(parsed.models.first),
      );

      // findUniqueOrThrow forwards include
      expect(
        code,
        contains(
          'Future<User> findUniqueOrThrow({ '
          'required UserWhereUniqueInput where, '
          'UserInclude? include, }) async { '
          'final result = await findUnique(where: where, include: include);',
        ),
      );

      // update uses executeMutationAsMap and supports include via updatedRow PK
      expect(code, contains('UserInclude? include'));
      expect(
        code,
        contains('updatedRow = await _executor.executeMutationAsMap(query);'),
      );
      expect(
        code,
        contains(
          'if (include != null) { '
          'return await findUniqueOrThrow( '
          "where: UserWhereUniqueInput(id: updatedRow['id'] as String?), "
          'include: include, ); } '
          'return User.fromJson(_normalizeForJson(updatedRow));',
        ),
      );

      // delete pre-fetches row via findUniqueOrThrow and executes mutation
      final deleteStart = code.indexOf('Future<User> delete(');
      final deleteEnd = code.indexOf('Future<int> deleteMany(');
      final deleteMethod = code.substring(deleteStart, deleteEnd);
      expect(
        deleteMethod,
        contains(
          'final existing = await findUniqueOrThrow(where: where);',
        ),
      );
      expect(
        deleteMethod,
        contains('final affected = await _executor.executeMutation(query);'),
      );
      expect(deleteMethod, contains('return existing;'));
    });

    test('generates non-RETURNING update fallback for SQLite provider', () {
      const sqliteSchemaStr = '''
datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

model User {
  id    String @id @default(uuid())
  email String @unique
}
''';
      final sqliteSchema = PrismaParser().parse(sqliteSchemaStr);
      final code = CbDelegateGenerator(sqliteSchema)
          .generateDelegate(sqliteSchema.models.first)
          .replaceAll(RegExp(r'\s+'), ' ');

      expect(
        code,
        contains('final existing = await findUniqueOrThrow(where: where);'),
      );
      expect(
        code,
        contains('final affected = await _executor.executeMutation(query);'),
      );
      expect(code, isNot(contains('executeMutationAsMap(query)')));
    });

    final integrationSchemaPath =
        Platform.environment['PRISMA_INTEGRATION_SCHEMA'];
    test(
      'parses and generates full familiarise_web schema if available',
      () {
        final schemaFile = File(integrationSchemaPath!);

        final parsed = PrismaParser().parse(schemaFile.readAsStringSync());
        expect(parsed.models.length, greaterThanOrEqualTo(135));
        expect(parsed.enums.length, greaterThanOrEqualTo(100));

        final models = CbModelGenerator(parsed).generateAll();
        final delegates =
            CbDelegateGenerator(parsed, serverMode: true).generateAll();
        final filters = CbFilterTypesGenerator(parsed).generate();
        final client = CbClientGenerator(parsed, serverMode: true).generate();
        final registry =
            CbSchemaRegistryGenerator(parsed, serverMode: true).generate();

        expect(
          models.length,
          equals(parsed.models.length + parsed.enums.length),
        );
        expect(delegates.length, equals(parsed.models.length));
        expect(filters, isNotEmpty);
        expect(client, isNotEmpty);
        expect(registry, isNotEmpty);
      },
      skip: integrationSchemaPath == null ||
              !File(integrationSchemaPath).existsSync()
          ? 'PRISMA_INTEGRATION_SCHEMA not set or file does not exist'
          : null,
    );
  });
}
