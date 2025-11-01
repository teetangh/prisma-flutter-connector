import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';
import 'package:prisma_flutter_connector/src/exceptions/network_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/not_found_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/validation_exception.dart';
import 'package:prisma_flutter_connector/src/models/product.dart';

/// API interface for Product operations
class ProductAPI {
  final GraphQLClient _client;
  final PrismaConfig _config;

  ProductAPI(this._client, this._config);

  /// Get a single product by ID
  Future<Product?> findUnique({required String id}) async {
    const query = r'''
      query GetProduct($id: String!) {
        product(id: $id) {
          id
          name
          description
          price
          stock
          createdAt
          updatedAt
        }
      }
    ''';

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: {'id': id},
      ),
    );

    _handleErrors(result);

    final data = result.data?['product'];
    if (data == null) return null;

    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// List products with optional filters
  Future<List<Product>> list({
    ProductFilter? filter,
    ProductOrderBy? orderBy,
  }) async {
    const query = r'''
      query ListProducts(
        $nameContains: String
        $priceUnder: Float
        $priceOver: Float
        $inStock: Boolean
      ) {
        products(
          nameContains: $nameContains
          priceUnder: $priceUnder
          priceOver: $priceOver
          inStock: $inStock
        ) {
          id
          name
          description
          price
          stock
          createdAt
          updatedAt
        }
      }
    ''';

    final variables = <String, dynamic>{};
    if (filter != null) {
      if (filter.nameContains != null) {
        variables['nameContains'] = filter.nameContains;
      }
      if (filter.priceUnder != null) {
        variables['priceUnder'] = filter.priceUnder;
      }
      if (filter.priceOver != null) {
        variables['priceOver'] = filter.priceOver;
      }
      if (filter.inStock != null) {
        variables['inStock'] = filter.inStock;
      }
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: variables,
      ),
    );

    _handleErrors(result);

    final data = result.data?['products'] as List?;
    if (data == null) return [];

    return data.map((json) => Product.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new product
  Future<Product> create({required CreateProductInput input}) async {
    const mutation = r'''
      mutation CreateProduct($input: CreateProductInput!) {
        createProduct(input: $input) {
          id
          name
          description
          price
          stock
          createdAt
          updatedAt
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'input': input.toJson()},
      ),
    );

    _handleErrors(result);

    final data = result.data?['createProduct'];
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing product
  Future<Product> update({
    required String id,
    required UpdateProductInput input,
  }) async {
    const mutation = r'''
      mutation UpdateProduct($id: String!, $input: UpdateProductInput!) {
        updateProduct(id: $id, input: $input) {
          id
          name
          description
          price
          stock
          createdAt
          updatedAt
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          'id': id,
          'input': input.toJson(),
        },
      ),
    );

    _handleErrors(result);

    final data = result.data?['updateProduct'];
    return Product.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a product
  Future<bool> delete({required String id}) async {
    const mutation = r'''
      mutation DeleteProduct($id: String!) {
        deleteProduct(id: $id)
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'id': id},
      ),
    );

    _handleErrors(result);

    return result.data?['deleteProduct'] == true;
  }

  void _handleErrors(QueryResult result) {
    if (result.hasException) {
      if (_config.debugMode) {
        print('GraphQL Error: ${result.exception}');
      }

      final exception = result.exception!;

      // Network errors
      if (exception.linkException != null) {
        throw NetworkException(
          message: exception.linkException.toString(),
          originalError: exception.linkException,
        );
      }

      // GraphQL errors
      if (exception.graphqlErrors.isNotEmpty) {
        final error = exception.graphqlErrors.first;
        final message = error.message;

        // Check for specific error types
        if (message.contains('not found') || message.contains('Not found')) {
          throw NotFoundException(message: message);
        }

        if (message.contains('validation') || message.contains('invalid')) {
          throw ValidationException(message: message);
        }

        // Generic GraphQL error
        throw NetworkException(
          message: message,
          code: error.extensions?['code'] as String?,
        );
      }
    }
  }
}
