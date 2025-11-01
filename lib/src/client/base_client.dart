import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';

/// Base client for Prisma Flutter Connector
///
/// This is a generic client that works with any Prisma schema.
/// Model-specific clients are generated from your Prisma schema.
///
/// Do not use this directly - use the generated `PrismaClient` from your schema.
class BasePrismaClient {
  final PrismaConfig config;
  late final GraphQLClient graphQLClient;

  BasePrismaClient({
    required this.config,
  }) {
    _initializeGraphQLClient();
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

    graphQLClient = GraphQLClient(
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

  /// Execute a raw GraphQL query
  Future<QueryResult> query(String query, {Map<String, dynamic>? variables}) {
    return graphQLClient.query(
      QueryOptions(
        document: gql(query),
        variables: variables ?? {},
      ),
    );
  }

  /// Execute a raw GraphQL mutation
  Future<QueryResult> mutate(String mutation,
      {Map<String, dynamic>? variables}) {
    return graphQLClient.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables ?? {},
      ),
    );
  }

  /// Subscribe to a GraphQL subscription
  Stream<QueryResult> subscribe(String subscription,
      {Map<String, dynamic>? variables}) {
    return graphQLClient.subscribe(
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
