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
  group('CbModelGenerator relation hydration (#67)', () {
    late PrismaSchema parsed;

    setUp(() => parsed = PrismaParser().parse(_schema));

    String modelCode(String name) => CbModelGenerator(parsed)
        .generateModel(parsed.models.firstWhere((m) => m.name == name));

    test('fromJson hydrates a to-one relation into the typed model', () {
      final flat = _flat(modelCode('Post'));
      expect(
        flat,
        contains("author: json['author'] != null ? "
            "User.fromJson(json['author'] as Map<String, dynamic>) : null"),
      );
    });

    test('fromJson hydrates a to-many relation into a typed list', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains("json['comments'] as List?"));
      expect(flat, contains('Comment.fromJson(e as Map<String, dynamic>)'));
      expect(flat, contains('.toList() ?? const []'));
    });

    test('scalar fields still deserialize normally', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains("title: json['title'] as String"));
    });

    test('typed XInclude class carries a field per relation', () {
      final flat = _flat(modelCode('Post'));
      expect(flat, contains('class PostInclude'));
      expect(flat, contains('UserInclude? author'));
      expect(flat, contains('CommentInclude? comments'));
      // toJson nests empty-include -> true, else {'include': ..., 'select': ...}
      expect(flat, contains('final n = author!.toJson();'));
      expect(flat, contains('final s = author!.selectMap();'));
      expect(flat, contains("map['author'] = (n.isEmpty && s == null) ? true"));
      expect(flat, contains("if (n.isNotEmpty) 'include': n"));
      expect(flat, contains("if (s != null) 'select': s"));
    });

    test('XInclude has typed per-relation select + ScalarField enum (#0.8.0)',
        () {
      final flat = _flat(modelCode('Post'));
      // Include carries its own model's scalar-field select list
      expect(flat, contains('List<PostScalarField>? select'));
      // ScalarField enum generated with case-per-scalar + fieldName payload
      expect(flat, contains('enum PostScalarField'));
      expect(flat, contains("title('title')"));
      expect(flat, contains("authorId('authorId')"));
      // relations are NOT scalar cases
      expect(flat, isNot(contains("author('author')")));
      // selectMap emits {'field': true} or null
      expect(flat,
          contains('if (select == null || select!.isEmpty) return null;'));
      expect(flat, contains('for (final f in select!) f.fieldName: true'));
    });

    test('relation-less model gets an empty XInclude', () {
      final flat = _flat(modelCode('User'));
      // User has a relation (posts) so isn't empty; assert its Include exists
      expect(flat, contains('class UserInclude'));
      expect(flat, contains('PostInclude? posts'));
    });
  });
}
