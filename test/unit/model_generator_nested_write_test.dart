import 'package:test/test.dart';
import 'package:prisma_flutter_connector/src/generator/cb_model_generator.dart';
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
  group('CbModelGenerator nested relation writes (#64)', () {
    late PrismaSchema parsed;

    setUp(() => parsed = PrismaParser().parse(_schema));

    String modelCode(String name) => CbModelGenerator(parsed)
        .generateModel(parsed.models.firstWhere((m) => m.name == name));

    test('per-relation write input classes are generated', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains('class PostAuthorWriteInput'));
      expect(flat, contains('class PostCommentsWriteInput'));
    });

    test('to-one write input has connect + create', () {
      final flat = _flat(modelCode('Post'));
      // author -> User (has @id) so connect is available
      expect(flat, contains('UserWhereUniqueInput? connect'));
      expect(flat, contains('CreateUserInput? create'));
    });

    test('to-many write input has list connect/disconnect + create', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains('List<CommentWhereUniqueInput>? connect'));
      expect(flat, contains('List<CommentWhereUniqueInput>? disconnect'));
      expect(flat, contains('List<CreateCommentInput>? create'));
    });

    test('CreateInput carries an optional param per relation', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains('PostAuthorWriteInput? author'));
      expect(flat, contains('PostCommentsWriteInput? comments'));
    });

    test('UpdateInput carries an optional param per relation', () {
      // User has a to-many relation (posts)
      final flat = _flat(modelCode('User'));
      expect(flat, contains('UserPostsWriteInput? posts'));
    });

    test('CreateInput.toJson emits relation writes when present', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains("if (author != null) 'author': author!.toJson()"));
      expect(flat,
          contains("if (comments != null) 'comments': comments!.toJson()"));
    });
  });
}
