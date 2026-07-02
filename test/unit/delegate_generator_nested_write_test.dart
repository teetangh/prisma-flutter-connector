import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_delegate_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

String _flat(String code) => code.replaceAll(RegExp(r'\s+'), ' ');

const _schema = '''
model Post {
  id       String    @id @default(cuid())
  title    String
  author   User      @relation(fields: [authorId], references: [id])
  authorId String
  comments Comment[]
}

model User {
  id    String @id
  name  String
  posts Post[]
}

model Comment {
  id     String @id
  postId String
  post   Post   @relation(fields: [postId], references: [id])
}
''';

void main() {
  group('CbDelegateGenerator nested-write routing (#64)', () {
    late PrismaSchema parsed;

    setUp(() => parsed = PrismaParser().parse(_schema));

    String delegateCode(String name) =>
        CbDelegateGenerator(parsed, serverMode: true)
            .generateDelegate(parsed.models.firstWhere((m) => m.name == name));

    test('create routes to relations engine when relation ops present', () {
      final flat = _flat(delegateCode('Post'));
      expect(flat, contains("const relationFields = {'author', 'comments'}"));
      expect(flat, contains('data0.keys.any(relationFields.contains)'));
      expect(flat,
          contains('_executor.executeMutationWithRelationsReturning(query)'));
    });

    test('update routes to relations engine when relation ops present', () {
      final flat = _flat(delegateCode('Post'));
      // update falls back to plain executeMutation otherwise
      expect(flat, contains('_executor.executeMutation(query)'));
      expect(flat,
          contains('_executor.executeMutationWithRelationsReturning(query)'));
    });

    test('relation-less model uses an empty relation-field set', () {
      const schema = '''
model Tag { id String @id name String }
''';
      final p = PrismaParser().parse(schema);
      final flat = _flat(CbDelegateGenerator(p, serverMode: true)
          .generateDelegate(p.models.first));
      expect(flat, contains('const relationFields = const <String>{}'));
    });
  });
}
