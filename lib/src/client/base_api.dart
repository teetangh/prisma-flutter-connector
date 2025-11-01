import 'package:graphql_flutter/graphql_flutter.dart'
    hide NetworkException; // Avoid conflict with our NetworkException
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';
import 'package:prisma_flutter_connector/src/exceptions/network_exception.dart'
    as prisma_exceptions;
import 'package:prisma_flutter_connector/src/exceptions/not_found_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/validation_exception.dart';

/// Base API interface that generated API classes extend
///
/// Provides common error handling and GraphQL utilities.
/// Model-specific API classes are generated from your Prisma schema.
abstract class BaseAPI {
  final GraphQLClient client;
  final PrismaConfig config;

  BaseAPI(this.client, this.config);

  /// Handle errors from GraphQL responses
  void handleErrors(QueryResult result) {
    if (result.hasException) {
      if (config.debugMode) {
        // ignore: avoid_print
        print('GraphQL Error: ${result.exception}');
      }

      final exception = result.exception!;

      // Network errors
      if (exception.linkException != null) {
        throw prisma_exceptions.NetworkException(
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
        throw prisma_exceptions.NetworkException(
          message: message,
          code: error.extensions?['code'] as String?,
        );
      }
    }
  }

  /// Execute a GraphQL query
  Future<QueryResult> executeQuery(String query,
      {Map<String, dynamic>? variables}) {
    return client.query(
      QueryOptions(
        document: gql(query),
        variables: variables ?? {},
      ),
    );
  }

  /// Execute a GraphQL mutation
  Future<QueryResult> executeMutation(String mutation,
      {Map<String, dynamic>? variables}) {
    return client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: variables ?? {},
      ),
    );
  }

  /// Subscribe to a GraphQL subscription
  Stream<QueryResult> executeSubscription(String subscription,
      {Map<String, dynamic>? variables}) {
    return client.subscribe(
      SubscriptionOptions(
        document: gql(subscription),
        variables: variables ?? {},
      ),
    );
  }
}
