import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:prisma_flutter_connector/src/client/prisma_config.dart';
import 'package:prisma_flutter_connector/src/exceptions/network_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/not_found_exception.dart';
import 'package:prisma_flutter_connector/src/exceptions/validation_exception.dart';
import 'package:prisma_flutter_connector/src/models/user.dart';

/// API interface for User operations
class UserAPI {
  final GraphQLClient _client;
  final PrismaConfig _config;

  UserAPI(this._client, this._config);

  /// Get a single user by ID
  Future<User?> findUnique({required String id}) async {
    const query = r'''
      query GetUser($id: String!) {
        user(id: $id) {
          id
          email
          name
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

    final data = result.data?['user'];
    if (data == null) return null;

    return User.fromJson(data as Map<String, dynamic>);
  }

  /// List users with optional filters
  Future<List<User>> list({
    UserFilter? filter,
    UserOrderBy? orderBy,
  }) async {
    const query = r'''
      query ListUsers(
        $emailContains: String
        $nameContains: String
      ) {
        users(
          emailContains: $emailContains
          nameContains: $nameContains
        ) {
          id
          email
          name
          createdAt
          updatedAt
        }
      }
    ''';

    final variables = <String, dynamic>{};
    if (filter != null) {
      if (filter.emailContains != null) {
        variables['emailContains'] = filter.emailContains;
      }
      if (filter.nameContains != null) {
        variables['nameContains'] = filter.nameContains;
      }
    }

    final result = await _client.query(
      QueryOptions(
        document: gql(query),
        variables: variables,
      ),
    );

    _handleErrors(result);

    final data = result.data?['users'] as List?;
    if (data == null) return [];

    return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new user
  Future<User> create({required CreateUserInput input}) async {
    const mutation = r'''
      mutation CreateUser($input: CreateUserInput!) {
        createUser(input: $input) {
          id
          email
          name
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

    final data = result.data?['createUser'];
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Update an existing user
  Future<User> update({
    required String id,
    required UpdateUserInput input,
  }) async {
    const mutation = r'''
      mutation UpdateUser($id: String!, $input: UpdateUserInput!) {
        updateUser(id: $id, input: $input) {
          id
          email
          name
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

    final data = result.data?['updateUser'];
    return User.fromJson(data as Map<String, dynamic>);
  }

  /// Delete a user
  Future<bool> delete({required String id}) async {
    const mutation = r'''
      mutation DeleteUser($id: String!) {
        deleteUser(id: $id)
      }
    ''';

    final result = await _client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'id': id},
      ),
    );

    _handleErrors(result);

    return result.data?['deleteUser'] == true;
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
