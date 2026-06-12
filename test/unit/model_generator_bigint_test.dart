import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Collapse all whitespace runs to single spaces so assertions are not
/// sensitive to dart_style line-wrapping decisions.
String flatten(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  group('CbModelGenerator BigInt @default handling', () {
    late PrismaParser parser;

    const schema = '''
model Wallet {
  id           String @id @default(cuid())
  balancePaise BigInt @default(0)
  limitPaise   BigInt?
  totalPaise   BigInt
}
''';

    setUp(() {
      parser = PrismaParser();
    });

    String generateWallet() {
      final parsed = parser.parse(schema);
      final generator = CbModelGenerator(parsed);
      return generator.generateModel(parsed.models.first);
    }

    group('main model class', () {
      test(
          'BigInt field with literal default is a required param (no '
          '@Default — BigInt has no const constructor)', () {
        final flat = flatten(generateWallet());

        expect(flat, contains('required BigInt balancePaise'));
        // No @Default annotation may appear anywhere in the file: cuid() is
        // a runtime default and @Default(0) on a BigInt would not compile.
        expect(flat, isNot(contains('@Default(')));
      });

      test('required BigInt without default stays required', () {
        final flat = flatten(generateWallet());

        expect(flat, contains('required BigInt totalPaise'));
      });

      test('optional BigInt is nullable', () {
        final flat = flatten(generateWallet());

        expect(flat, contains('BigInt? limitPaise'));
      });
    });

    group('fromJson', () {
      test("BigInt with default falls back to BigInt.parse('<default>')", () {
        final flat = flatten(generateWallet());

        expect(
            flat,
            contains("balancePaise: json['balancePaise'] != null "
                "? BigInt.parse(json['balancePaise'].toString()) "
                ": BigInt.parse('0')"));
      });

      test('required BigInt without default uses plain BigInt.parse', () {
        final flat = flatten(generateWallet());

        expect(
            flat,
            contains(
                "totalPaise: BigInt.parse(json['totalPaise'].toString())"));
        // Not null-guarded and no fallback
        expect(flat, isNot(contains("json['totalPaise'] != null")));
      });

      test('optional BigInt uses null-guarded parse', () {
        final flat = flatten(generateWallet());

        expect(
            flat,
            contains("limitPaise: json['limitPaise'] != null "
                "? BigInt.parse(json['limitPaise'].toString()) "
                ": null"));
      });
    });

    group('toJson', () {
      test('serializes BigInt via .toString()', () {
        final flat = flatten(generateWallet());

        // balancePaise is non-nullable in the model (required param)
        expect(flat, contains("'balancePaise': balancePaise.toString()"));
        expect(flat, contains("'totalPaise': totalPaise.toString()"));
        // limitPaise is nullable → null-aware toString
        expect(flat, contains("'limitPaise': limitPaise?.toString()"));
      });
    });

    group('CreateWalletInput', () {
      test(
          'BigInt with default is nullable WITHOUT @Default — the database '
          'applies the schema default when omitted', () {
        final code = generateWallet();
        final flat = flatten(code);

        // Isolate the CreateWalletInput class body
        final start = flat.indexOf('class CreateWalletInput');
        expect(start, greaterThanOrEqualTo(0));
        final end = flat.indexOf('class ', start + 1);
        final createInput = flat.substring(start, end);

        expect(createInput, contains('BigInt? balancePaise'));
        expect(createInput, isNot(contains('@Default(')));
        // Required BigInt without schema default is still required
        expect(createInput, contains('required BigInt totalPaise'));
        // CreateInput toJson serializes BigInt via toString and skips nulls
        expect(
            createInput,
            contains("if (balancePaise != null) "
                "'balancePaise': balancePaise?.toString()"));
      });
    });
  });
}
