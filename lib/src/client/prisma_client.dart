import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:prisma_flutter_connector/src/api/order_api.dart';
import 'package:prisma_flutter_connector/src/api/product_api.dart';
import 'package:prisma_flutter_connector/src/api/user_api.dart';
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';

/// Main client for Prisma Flutter Connector
///
/// Usage:
/// ```dart
/// final client = PrismaClient(
///   config: PrismaConfig(
///     graphqlEndpoint: 'https://api.example.com/graphql',
///   ),
/// );
///
/// // Query products
/// final products = await client.products.list();
///
/// // Create order
/// final order = await client.orders.create(
///   input: CreateOrderInput(...),
/// );
/// ```
class PrismaClient {
  final PrismaConfig config;
  late final GraphQLClient _graphQLClient;

  // API interfaces
  late final ProductAPI products;
  late final UserAPI users;
  late final OrderAPI orders;

  PrismaClient({
    required this.config,
  }) {
    _initializeGraphQLClient();
    _initializeAPIs();
  }

  void _initializeGraphQLClient() {
    final HttpLink httpLink = HttpLink(
      config.graphqlEndpoint,
      defaultHeaders: config.allHeaders,
    );

    final WebSocketLink? wsLink = config.graphqlEndpoint.contains('http')
        ? WebSocketLink(
            config.graphqlEndpoint.replaceFirst('http', 'ws'),
            config: SocketClientConfig(
              autoReconnect: true,
              inactivityTimeout: const Duration(seconds: 30),
              initialPayload: () async => config.allHeaders,
            ),
          )
        : null;

    final Link link = wsLink != null
        ? Link.split(
            (request) => request.isSubscription,
            wsLink,
            httpLink,
          )
        : httpLink;

    _graphQLClient = GraphQLClient(
      link: link,
      cache: GraphQLCache(),
      defaultPolicies: DefaultPolicies(
        query: Policies(
          fetch: FetchPolicy.networkOnly,
          error: ErrorPolicy.all,
          cacheReread: CacheRereadPolicy.ignoreAll,
        ),
        mutate: Policies(
          fetch: FetchPolicy.networkOnly,
          error: ErrorPolicy.all,
        ),
      ),
    );
  }

  void _initializeAPIs() {
    products = ProductAPI(_graphQLClient, config);
    users = UserAPI(_graphQLClient, config);
    orders = OrderAPI(_graphQLClient, config);
  }

  /// Execute a raw GraphQL query
  Future<QueryResult> query(String query, {Map<String, dynamic>? variables}) {
    return _graphQLClient.query(
      QueryOptions(
        document: gql(query),
        variables: variables ?? {},
      ),
    );
  }

  /// Execute a raw GraphQL mutation
  Future<QueryResult> mutate(String mutation,
      {Map<String, dynamic>? variables}) {
    return _graphQLClient.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables ?? {},
      ),
    );
  }

  /// Subscribe to a GraphQL subscription
  Stream<QueryResult> subscribe(String subscription,
      {Map<String, dynamic>? variables}) {
    return _graphQLClient.subscribe(
      SubscriptionOptions(
        document: gql(subscription),
        variables: variables ?? {},
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    // GraphQL client cleanup if needed
  }
}
