import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';
import 'package:prisma_flutter_connector/src/exceptions/network_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/not_found_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/validation_exception.dart';
import 'package:prisma_flutter_connector/src/models/order.dart';

/// API interface for Order operations
class OrderAPI {
  final GraphQLClient _client;
  final PrismaConfig _config;

  OrderAPI(this._client, this._config);

  /// Get a single order by ID with items
  Future<Order?> findUnique({required String id}) async {
    const query = r'''
      query GetOrder($id: String!) {
        order(id: $id) {
          id
          userId
          status
          total
          createdAt
          updatedAt
          user {
            id
            email
            name
          }
          items {
            id
            productId
            quantity
            price
            product {
              id
              name
              description
              price
            }
          }
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

    final data = result.data?['order'];
    if (data == null) return null;

    return Order.fromJson(data as Map<String, dynamic>);
  }

  /// List orders with optional filters
  Future<List<Order>> list({
    OrderFilter? filter,
    OrderOrderBy? orderBy,
  }) async {
    const query = r'''
      query ListOrders(
        $userId: String
        $status: OrderStatus
      ) {
        orders(
          userId: $userId
          status: $status
        ) {
          id
          userId
          status
          total
          createdAt
          updatedAt
        }
      }
    ''';

    final variables = <String, dynamic>{};
    if (filter != null) {
      if (filter.userId != null) {
        variables['userId'] = filter.userId;
      }
      if (filter.status != null) {
        variables['status'] = filter.status!.name.toUpperCase();
      }
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: variables,
      ),
    );

    _handleErrors(result);

    final data = result.data?['orders'] as List?;
    if (data == null) return [];

    return data.map((json) => Order.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new order
  Future<Order> create({required CreateOrderInput input}) async {
    const mutation = r'''
      mutation CreateOrder($input: CreateOrderInput!) {
        createOrder(input: $input) {
          id
          userId
          status
          total
          createdAt
          updatedAt
          items {
            id
            productId
            quantity
            price
            product {
              id
              name
              price
            }
          }
        }
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'input': _prepareOrderInput(input)},
      ),
    );

    _handleErrors(result);

    final data = result.data?['createOrder'];
    return Order.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing order (typically status)
  Future<Order> update({
    required String id,
    required UpdateOrderInput input,
  }) async {
    const mutation = r'''
      mutation UpdateOrder($id: String!, $input: UpdateOrderInput!) {
        updateOrder(id: $id, input: $input) {
          id
          userId
          status
          total
          createdAt
          updatedAt
        }
      }
    ''';

    final variables = {
      'id': id,
      'input': <String, dynamic>{},
    };

    if (input.status != null) {
      (variables['input'] as Map<String, dynamic>)['status'] =
          input.status!.name.toUpperCase();
    }

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables,
      ),
    );

    _handleErrors(result);

    final data = result.data?['updateOrder'];
    return Order.fromJson(data as Map<String, dynamic>);
  }

  /// Subscribe to order creation events
  Stream<Order> subscribeToOrderCreated({String? userId}) {
    const subscription = r'''
      subscription OrderCreated($userId: String) {
        orderCreated(userId: $userId) {
          id
          userId
          status
          total
          createdAt
          updatedAt
        }
      }
    ''';

    return _client
        .subscribe(
          SubscriptionOptions(
            document: gql(subscription),
            variables: userId != null ? {'userId': userId} : {},
          ),
        )
        .map((result) {
          if (result.hasException) {
            throw NetworkException(
              message: result.exception.toString(),
              originalError: result.exception,
            );
          }

          final data = result.data?['orderCreated'];
          return Order.fromJson(data as Map<String, dynamic>);
        });
  }

  /// Subscribe to order status changes
  Stream<Order> subscribeToOrderStatusChanged({required String orderId}) {
    const subscription = r'''
      subscription OrderStatusChanged($orderId: String!) {
        orderStatusChanged(orderId: $orderId) {
          id
          userId
          status
          total
          createdAt
          updatedAt
        }
      }
    ''';

    return _client
        .subscribe(
          SubscriptionOptions(
            document: gql(subscription),
            variables: {'orderId': orderId},
          ),
        )
        .map((result) {
          if (result.hasException) {
            throw NetworkException(
              message: result.exception.toString(),
              originalError: result.exception,
            );
          }

          final data = result.data?['orderStatusChanged'];
          return Order.fromJson(data as Map<String, dynamic>);
        });
  }

  Map<String, dynamic> _prepareOrderInput(CreateOrderInput input) {
    return {
      'userId': input.userId,
      'items': input.items
          .map((item) => {
                'productId': item.productId,
                'quantity': item.quantity,
              })
          .toList(),
      if (input.status != OrderStatus.pending)
        'status': input.status.name.toUpperCase(),
    };
  }

  void _handleErrors(QueryResult result) {
    if (result.hasException) {
      if (_config.debugMode) {
        print('GraphQL Error: ${result.exception}');
      }

      final exception = result.exception!;

      if (exception.linkException != null) {
        throw NetworkException(
          message: exception.linkException.toString(),
          originalError: exception.linkException,
        );
      }

      if (exception.graphqlErrors.isNotEmpty) {
        final error = exception.graphqlErrors.first;
        final message = error.message;

        if (message.contains('not found') || message.contains('Not found')) {
          throw NotFoundException(message: message);
        }

        if (message.contains('validation') || message.contains('invalid')) {
          throw ValidationException(message: message);
        }

        throw NetworkException(
          message: message,
          code: error.extensions?['code'] as String?,
        );
      }
    }
  }
}
