import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_filter_types_generator.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('JsonFilter generation (#69)', () {
    final parsed = PrismaParser().parse('model Ping { id String @id }');

    test('filter types include a JsonFilter with path + operators', () {
      final flat = _flat(CbFilterTypesGenerator(parsed).generate());
      expect(flat, contains('class JsonFilter'));
      expect(flat, contains("JsonKey(name: 'string_contains')"));
      expect(flat, contains("JsonKey(name: 'array_contains')"));
      expect(flat, contains('List<String>? path'));
    });

    test('Json columns map to JsonFilter in WhereInput', () {
      const schema = '''
model Event {
  id   String @id
  meta Json
}
''';
      final p = PrismaParser().parse(schema);
      final flat = _flat(CbModelGenerator(p)
          .generateModel(p.models.firstWhere((m) => m.name == 'Event')));
      expect(flat, contains('JsonFilter? meta'));
    });

    test('filter types include BigIntFilter + BytesFilter', () {
      final flat = _flat(CbFilterTypesGenerator(parsed).generate());
      expect(flat, contains('class BigIntFilter'));
      expect(flat, contains('class BytesFilter'));
      // BigInt values serialize via toString() in toJson
      expect(flat, contains('equals!.toString()'));
    });

    test('BigInt/Bytes columns map to their filters in WhereInput', () {
      const schema = '''
model Blob {
  id    String @id
  size  BigInt
  data  Bytes
}
''';
      final p = PrismaParser().parse(schema);
      final flat = _flat(CbModelGenerator(p)
          .generateModel(p.models.firstWhere((m) => m.name == 'Blob')));
      expect(flat, contains('BigIntFilter? size'));
      expect(flat, contains('BytesFilter? data'));
    });
  });
}
