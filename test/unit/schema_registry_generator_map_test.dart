import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_schema_registry_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Collapse all whitespace runs to single spaces so assertions are not
/// sensitive to dart_style line-wrapping decisions.
String flatten(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('CbSchemaRegistryGenerator @map/@@map support', () {
    late PrismaParser parser;

    setUp(() {
      parser = PrismaParser();
    });

    test(
        '@@map flows into ModelSchema.tableName and @map into '
        'FieldInfo.columnName', () {
      const schema = '''
model User {
  id     String @id
  status String @map("requestStatus")

  @@map("users")
}
''';

      final parsed = parser.parse(schema);
      final generator = CbSchemaRegistryGenerator(parsed);
      final code = generator.generate();
      final flat = flatten(code);

      // Model registered under its Dart name but mapped table name
      expect(flat, contains("name: 'User'"));
      expect(flat, contains("tableName: 'users'"));

      // Field keeps its Dart name; columnName carries the @map value
      // (the formatter may add trailing commas, so match the argument run)
      expect(flat, contains("'status': FieldInfo("));
      expect(
          flat,
          contains(
              "name: 'status', columnName: 'requestStatus', type: 'String'"));

      // Unmapped field defaults columnName to the field name
      expect(
          flat,
          contains("name: 'id', columnName: 'id', type: 'String', "
              "isId: true"));
    });

    test('model without @@map uses model name as table name', () {
      const schema = '''
model Post {
  id String @id
}
''';

      final parsed = parser.parse(schema);
      final code = CbSchemaRegistryGenerator(parsed).generate();
      final flat = flatten(code);

      expect(flat, contains("tableName: 'Post'"));
    });
  });

  group('CbSchemaRegistryGenerator one-to-one FK resolution', () {
    test('FK on the target model emits non-owner relation with real FK', () {
      // Program.licensedSeatConfig has no @relation attrs; the FK lives on
      // LicensedSeatConfig.programId. The generator must NOT fabricate a
      // 'licensedSeatConfigId' column on Program.
      const schema = '''
model Program {
  id                 String              @id @default(uuid())
  name               String
  licensedSeatConfig LicensedSeatConfig?
}

model LicensedSeatConfig {
  programId String  @id
  program   Program @relation(fields: [programId], references: [id])
  seats     Int
}
''';

      final parsed = PrismaParser().parse(schema);
      final code = CbSchemaRegistryGenerator(parsed).generate();
      final flat = flatten(code);

      expect(
        flat,
        contains("'licensedSeatConfig': RelationInfo.oneToOne( "
                "name: 'licensedSeatConfig', "
                "targetModel: 'LicensedSeatConfig', "
                "foreignKey: 'programId', "
                "isOwner: false"
            .replaceAll(RegExp(r'\s+'), ' ')),
      );
      expect(flat, isNot(contains('licensedSeatConfigId')));

      // The owning side keeps its own FK and owner flag
      expect(
        flat,
        contains("'program': RelationInfo.oneToOne( "
                "name: 'program', "
                "targetModel: 'Program', "
                "foreignKey: 'programId', "
                "isOwner: true"
            .replaceAll(RegExp(r'\s+'), ' ')),
      );
    });
  });
}
