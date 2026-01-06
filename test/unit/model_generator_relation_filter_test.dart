import 'package:prisma_flutter_connector/src/generator/model_generator.dart';
import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';
import 'package:test/test.dart';

void main() {
  group('ModelGenerator Relation Filters', () {
    late ModelGenerator generator;
    late PrismaModel userModel;
    late PrismaModel orderModel;
    late PrismaModel productModel;
    // Cache generated code to avoid repeated generation in tests
    late String userCode;
    late String orderCode;
    late String productCode;

    setUp(() {
      // Create a schema with various relation types for testing
      const schema = PrismaSchema(
        models: [
          // User model with one-to-many relation to Order
          PrismaModel(
            name: 'User',
            fields: [
              PrismaField(
                name: 'id',
                type: 'String',
                isId: true,
                isRequired: true,
              ),
              PrismaField(
                name: 'email',
                type: 'String',
                isRequired: true,
                isUnique: true,
              ),
              PrismaField(
                name: 'name',
                type: 'String',
                isRequired: false,
              ),
              // One-to-many: User has many Orders
              PrismaField(
                name: 'orders',
                type: 'Order',
                isList: true,
                isRelation: true,
                relationName: 'UserOrders',
              ),
              // Many-to-many: User has many Products (favorites)
              PrismaField(
                name: 'favoriteProducts',
                type: 'Product',
                isList: true,
                isRelation: true,
                relationName: 'UserFavoriteProducts',
              ),
            ],
            relations: [],
          ),
          // Order model with many-to-one relation to User
          PrismaModel(
            name: 'Order',
            fields: [
              PrismaField(
                name: 'id',
                type: 'String',
                isId: true,
                isRequired: true,
              ),
              PrismaField(
                name: 'total',
                type: 'Float',
                isRequired: true,
              ),
              PrismaField(
                name: 'userId',
                type: 'String',
                isRequired: true,
              ),
              // Many-to-one: Order belongs to User
              PrismaField(
                name: 'user',
                type: 'User',
                isList: false,
                isRelation: true,
                relationName: 'UserOrders',
                relationFromFields: ['userId'],
                relationToFields: ['id'],
              ),
            ],
            relations: [],
          ),
          // Product model for M2M relation testing
          PrismaModel(
            name: 'Product',
            fields: [
              PrismaField(
                name: 'id',
                type: 'String',
                isId: true,
                isRequired: true,
              ),
              PrismaField(
                name: 'name',
                type: 'String',
                isRequired: true,
              ),
              // Many-to-many: Product is favorited by many Users
              PrismaField(
                name: 'favoritedBy',
                type: 'User',
                isList: true,
                isRelation: true,
                relationName: 'UserFavoriteProducts',
              ),
            ],
            relations: [],
          ),
        ],
        enums: [],
        datasourceProvider: 'postgresql',
      );

      generator = const ModelGenerator(schema);
      userModel = schema.models.firstWhere((m) => m.name == 'User');
      orderModel = schema.models.firstWhere((m) => m.name == 'Order');
      productModel = schema.models.firstWhere((m) => m.name == 'Product');

      // Generate code once for all tests
      userCode = generator.generateModel(userModel);
      orderCode = generator.generateModel(orderModel);
      productCode = generator.generateModel(productModel);
    });

    group('ListRelationFilter generation', () {
      test('generates ListRelationFilter for one-to-many relations', () {
        // Should generate OrderListRelationFilter for the orders relation
        expect(userCode, contains('OrderListRelationFilter? orders,'));

        // Should generate the ListRelationFilter class
        expect(userCode, contains('class UserListRelationFilter'));
        expect(userCode, contains('UserWhereInput? some,'));
        expect(userCode, contains('UserWhereInput? every,'));
        expect(userCode, contains('UserWhereInput? none,'));
      });

      test('generates ListRelationFilter for many-to-many relations', () {
        // Should generate ProductListRelationFilter for the favoriteProducts relation
        expect(
            userCode, contains('ProductListRelationFilter? favoriteProducts,'));
      });

      test('ListRelationFilter includes some, every, and none operators', () {
        // Order model should have its own ListRelationFilter
        expect(orderCode, contains('class OrderListRelationFilter'));
        expect(orderCode, contains('OrderWhereInput? some,'));
        expect(orderCode, contains('OrderWhereInput? every,'));
        expect(orderCode, contains('OrderWhereInput? none,'));
      });
    });

    group('RelationFilter generation', () {
      test('generates RelationFilter for many-to-one relations', () {
        // Should generate UserRelationFilter for the user relation
        expect(orderCode, contains('UserRelationFilter? user,'));
      });

      test('RelationFilter includes is and isNot operators', () {
        // User model should have its own RelationFilter
        expect(userCode, contains('class UserRelationFilter'));
        expect(userCode, contains("@JsonKey(name: 'is') UserWhereInput? is_,"));
        expect(userCode, contains('UserWhereInput? isNot,'));
      });
    });

    group('WhereInput with relations', () {
      test('WhereInput includes relation filter fields', () {
        // WhereInput should include the relation filter fields
        expect(userCode, contains('class UserWhereInput'));
        expect(userCode, contains('/// Filter by orders relation'));
        expect(userCode, contains('OrderListRelationFilter? orders,'));
        expect(userCode, contains('/// Filter by favoriteProducts relation'));
        expect(
            userCode, contains('ProductListRelationFilter? favoriteProducts,'));
      });

      test('WhereInput includes scalar filter fields alongside relations', () {
        // Should still have scalar filters
        expect(userCode, contains('StringFilter? id,'));
        expect(userCode, contains('StringFilter? email,'));
        expect(userCode, contains('StringFilter? name,'));
      });

      test('WhereInput includes logical operators', () {
        expect(userCode, contains('List<UserWhereInput>? AND,'));
        expect(userCode, contains('List<UserWhereInput>? OR,'));
        expect(userCode, contains('UserWhereInput? NOT,'));
      });
    });

    group('JSON serialization', () {
      test('ListRelationFilter has fromJson factory', () {
        expect(
            userCode,
            contains(
                'factory UserListRelationFilter.fromJson(Map<String, dynamic> json)'));
      });

      test('RelationFilter has fromJson factory', () {
        expect(
            userCode,
            contains(
                'factory UserRelationFilter.fromJson(Map<String, dynamic> json)'));
      });

      test('RelationFilter uses @JsonKey for is_ field', () {
        // The 'is' keyword needs to be escaped as 'is_' with a JsonKey mapping
        expect(userCode, contains("@JsonKey(name: 'is') UserWhereInput? is_,"));
      });
    });

    group('edge cases', () {
      test('model without relations still generates filter types', () {
        // Even models without relations should generate their own filter types
        // so other models can reference them
        expect(productCode, contains('class ProductListRelationFilter'));
        expect(productCode, contains('class ProductRelationFilter'));
      });

      test('self-referential relations work correctly', () {
        // Create a model with self-referential relation
        const selfRefSchema = PrismaSchema(
          models: [
            PrismaModel(
              name: 'Category',
              fields: [
                PrismaField(
                  name: 'id',
                  type: 'String',
                  isId: true,
                  isRequired: true,
                ),
                PrismaField(
                  name: 'name',
                  type: 'String',
                  isRequired: true,
                ),
                // Self-referential: parent category
                PrismaField(
                  name: 'parent',
                  type: 'Category',
                  isList: false,
                  isRelation: true,
                  relationName: 'CategoryParent',
                ),
                // Self-referential: child categories
                PrismaField(
                  name: 'children',
                  type: 'Category',
                  isList: true,
                  isRelation: true,
                  relationName: 'CategoryParent',
                ),
              ],
              relations: [],
            ),
          ],
          enums: [],
          datasourceProvider: 'postgresql',
        );

        const selfRefGenerator = ModelGenerator(selfRefSchema);
        final categoryModel = selfRefSchema.models.first;
        final categoryCode = selfRefGenerator.generateModel(categoryModel);

        // Should handle self-referential relations
        expect(categoryCode, contains('CategoryRelationFilter? parent,'));
        expect(categoryCode, contains('CategoryListRelationFilter? children,'));
      });
    });
  });
}
