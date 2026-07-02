import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Collapse all whitespace runs to single spaces so assertions are not
/// sensitive to dart_style line-wrapping decisions.
String flatten(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('CbModelGenerator field-level @map support', () {
    late PrismaParser parser;

    const schema = '''
model User {
  id     String @id
  status String @map("requestStatus")

  @@map("users")
}
''';

    setUp(() {
      parser = PrismaParser();
    });

    String generateUser() {
      final parsed = parser.parse(schema);
      return CbModelGenerator(parsed).generateModel(parsed.models.first);
    }

    test('mapped field carries @JsonKey(name: ...) on the model param', () {
      final flat = flatten(generateUser());

      expect(flat,
          contains("@JsonKey(name: 'requestStatus') required String status"));
      // Unmapped field gets no JsonKey
      expect(flat, isNot(contains("@JsonKey(name: 'id')")));
    });

    test('fromJson reads from the mapped key', () {
      final flat = flatten(generateUser());

      expect(flat, contains("status: json['requestStatus'] as String"));
      expect(flat, isNot(contains("json['status']")));
    });

    test('toJson writes to the mapped key', () {
      final flat = flatten(generateUser());

      expect(flat, contains("'requestStatus': status"));
      // The Dart field name is never used as a JSON key in the model class
      final mainClass = flat.substring(
          flat.indexOf('class User'), flat.indexOf('class CreateUserInput'));
      expect(mainClass, isNot(contains("'status':")));
    });
  });
}
