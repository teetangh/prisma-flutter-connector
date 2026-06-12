import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/runtime/adapters/postgres_adapter.dart';

/// Custom enum[] columns arrive from the postgres driver as UndecodedBytes —
/// either the binary ARRAY wire format or a text array literal. These tests
/// cover the two parsers the adapter uses to turn them into List<String?>.
void main() {
  group('parsePgBinaryArray', () {
    /// Build the 1-D PostgreSQL binary array wire format.
    List<int> binaryArray(List<String?> elements, {int elemOid = 12345}) {
      final builder = BytesBuilder();
      void writeInt32(int v) {
        final b = ByteData(4)..setInt32(0, v);
        builder.add(b.buffer.asUint8List());
      }

      writeInt32(1); // ndim
      writeInt32(elements.contains(null) ? 1 : 0); // hasNull
      writeInt32(elemOid);
      writeInt32(elements.length); // dim size
      writeInt32(1); // lower bound
      for (final e in elements) {
        if (e == null) {
          writeInt32(-1);
        } else {
          final bytes = utf8.encode(e);
          writeInt32(bytes.length);
          builder.add(bytes);
        }
      }
      return builder.toBytes();
    }

    test('decodes a single-element enum array', () {
      final bytes = binaryArray(['ONE_ON_ONE']);
      expect(PostgresAdapter.parsePgBinaryArray(bytes), ['ONE_ON_ONE']);
    });

    test('decodes a multi-element enum array', () {
      final bytes = binaryArray(['ONE_ON_ONE', 'GROUP', 'ASYNC_REVIEW']);
      expect(
        PostgresAdapter.parsePgBinaryArray(bytes),
        ['ONE_ON_ONE', 'GROUP', 'ASYNC_REVIEW'],
      );
    });

    test('decodes empty arrays (ndim 0)', () {
      final builder = BytesBuilder();
      for (final v in [0, 0, 12345]) {
        final b = ByteData(4)..setInt32(0, v);
        builder.add(b.buffer.asUint8List());
      }
      expect(PostgresAdapter.parsePgBinaryArray(builder.toBytes()), isEmpty);
    });

    test('decodes NULL elements', () {
      final bytes = binaryArray(['A', null, 'B']);
      expect(PostgresAdapter.parsePgBinaryArray(bytes), ['A', null, 'B']);
    });

    test('returns null for non-array payloads (plain enum label bytes)', () {
      expect(PostgresAdapter.parsePgBinaryArray(utf8.encode('ONE_ON_ONE')),
          isNull);
      expect(PostgresAdapter.parsePgBinaryArray(<int>[]), isNull);
    });
  });

  group('parsePgTextArray', () {
    test('parses simple literals', () {
      expect(
        PostgresAdapter.parsePgTextArray('{ONE_ON_ONE,GROUP}'),
        ['ONE_ON_ONE', 'GROUP'],
      );
    });

    test('parses quoted elements with commas and escapes', () {
      expect(
        PostgresAdapter.parsePgTextArray(r'{"a, b","c \"d\""}'),
        ['a, b', 'c "d"'],
      );
    });

    test('parses NULL and empty arrays', () {
      expect(PostgresAdapter.parsePgTextArray('{A,NULL}'), ['A', null]);
      expect(PostgresAdapter.parsePgTextArray('{}'), isEmpty);
      // Quoted "NULL" is the literal string, not SQL NULL
      expect(PostgresAdapter.parsePgTextArray('{"NULL"}'), ['NULL']);
    });
  });
}
