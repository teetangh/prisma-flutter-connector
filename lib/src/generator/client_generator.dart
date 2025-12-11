/// Client generator for adapter-based Prisma client
///
/// Generates the main PrismaClient class that uses database adapters
/// for direct database access.
library;

import 'package:prisma_flutter_connector/src/generator/prisma_parser.dart';

/// Generates the main PrismaClient class
class ClientGenerator {
  final PrismaSchema schema;

  const ClientGenerator(this.schema);

  /// Generate the PrismaClient class
  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('/// Generated Prisma Client for Dart/Flutter');
    buffer.writeln('///');
    buffer.writeln(
        '/// This client provides type-safe database access using adapters.');
    buffer.writeln(
        '/// No GraphQL backend required - connects directly to your database!');
    buffer.writeln('///');
    buffer.writeln('/// Usage:');
    buffer.writeln('/// ```dart');
    buffer.writeln('/// final adapter = PostgresAdapter(connection);');
    buffer.writeln('/// final prisma = PrismaClient(adapter: adapter);');
    buffer.writeln('///');
    buffer.writeln('/// final users = await prisma.user.findMany();');
    buffer.writeln('/// ```');
    buffer.writeln('library;');
    buffer.writeln();

    // Imports
    buffer.writeln("import 'package:prisma_flutter_connector/runtime.dart';");
    buffer.writeln();

    // Import delegates
    for (final model in schema.models) {
      final snakeName = _toSnakeCase(model.name);
      buffer.writeln("import 'delegates/${snakeName}_delegate.dart';");
    }
    buffer.writeln();

    // Import models
    for (final model in schema.models) {
      final snakeName = _toSnakeCase(model.name);
      buffer.writeln("import 'models/$snakeName.dart';");
    }
    buffer.writeln();

    // PrismaClient class
    buffer.writeln('/// Main Prisma client for database operations');
    buffer.writeln('///');
    buffer
        .writeln('/// This client provides access to all your models through');
    buffer.writeln('/// type-safe delegate classes.');
    buffer.writeln('class PrismaClient {');
    buffer.writeln(
        '  /// The database adapter (PostgreSQL, Supabase, SQLite, etc.)');
    buffer.writeln('  final SqlDriverAdapter adapter;');
    buffer.writeln();
    buffer.writeln('  /// The query executor');
    buffer.writeln('  final QueryExecutor _executor;');
    buffer.writeln();

    // Declare delegate properties
    for (final model in schema.models) {
      final camelName = _toLowerCamelCase(model.name);
      buffer.writeln('  /// Delegate for ${model.name} operations');
      buffer.writeln('  late final ${model.name}Delegate $camelName;');
    }
    buffer.writeln();

    // Constructor
    buffer.writeln('  /// Create a new PrismaClient with a database adapter');
    buffer.writeln('  ///');
    buffer.writeln('  /// Example:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// final connection = await pg.Connection.open(...);');
    buffer.writeln('  /// final adapter = PostgresAdapter(connection);');
    buffer.writeln('  /// final prisma = PrismaClient(adapter: adapter);');
    buffer.writeln('  /// ```');
    buffer.writeln('  PrismaClient({required this.adapter})');
    buffer.writeln('      : _executor = QueryExecutor(adapter: adapter) {');

    // Initialize delegates
    for (final model in schema.models) {
      final camelName = _toLowerCamelCase(model.name);
      buffer.writeln('    $camelName = ${model.name}Delegate(_executor);');
    }

    buffer.writeln('  }');
    buffer.writeln();

    // Transaction method
    buffer.writeln('  /// Execute multiple operations in a transaction');
    buffer.writeln('  ///');
    buffer.writeln('  /// All operations succeed or all rollback on error.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Example:');
    buffer.writeln('  /// ```dart');
    buffer.writeln('  /// await prisma.\$transaction((tx) async {');
    buffer.writeln('  ///   await tx.user.create(data: {...});');
    buffer.writeln('  ///   await tx.profile.create(data: {...});');
    buffer.writeln('  ///   // Both succeed or both rollback');
    buffer.writeln('  /// });');
    buffer.writeln('  /// ```');
    buffer.writeln('  Future<T> \$transaction<T>(');
    buffer.writeln('    Future<T> Function(PrismaClient) callback, {');
    buffer.writeln('    IsolationLevel? isolationLevel,');
    buffer.writeln('  }) async {');
    buffer.writeln(
        '    return await _executor.executeInTransaction((txExecutor) async {');
    buffer.writeln(
        '      final txClient = PrismaClient._transaction(txExecutor);');
    buffer.writeln('      return await callback(txClient);');
    buffer.writeln('    }, isolationLevel: isolationLevel);');
    buffer.writeln('  }');
    buffer.writeln();

    // Private transaction constructor
    buffer.writeln('  /// Private constructor for transaction client');
    buffer.writeln('  PrismaClient._transaction(QueryExecutor executor)');
    buffer.writeln('      : adapter = executor.adapter,');
    buffer.writeln('        _executor = executor {');

    for (final model in schema.models) {
      final camelName = _toLowerCamelCase(model.name);
      buffer.writeln('    $camelName = ${model.name}Delegate(_executor);');
    }

    buffer.writeln('  }');
    buffer.writeln();

    // Disconnect method
    buffer.writeln('  /// Close the database connection');
    buffer.writeln('  ///');
    buffer.writeln(
        '  /// Call this when you\'re done using the client to clean up resources.');
    buffer.writeln('  Future<void> \$disconnect() async {');
    buffer.writeln('    await _executor.dispose();');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();

    // Helper functions for building queries
    buffer.writeln('/// Helper class for filter operators');
    buffer.writeln('///');
    buffer.writeln('/// Use these when building WHERE clauses.');
    buffer.writeln('class Where {');
    buffer.writeln('  /// Equals');
    buffer.writeln(
        '  static Map<String, dynamic> equals(dynamic value) => FilterOperators.equals(value);');
    buffer.writeln();
    buffer.writeln('  /// Not equals');
    buffer.writeln(
        '  static Map<String, dynamic> not(dynamic value) => FilterOperators.not(value);');
    buffer.writeln();
    buffer.writeln('  /// In list');
    buffer.writeln(
        '  static Map<String, dynamic> in_(List<dynamic> values) => FilterOperators.in_(values);');
    buffer.writeln();
    buffer.writeln('  /// Not in list');
    buffer.writeln(
        '  static Map<String, dynamic> notIn(List<dynamic> values) => FilterOperators.notIn(values);');
    buffer.writeln();
    buffer.writeln('  /// Less than');
    buffer.writeln(
        '  static Map<String, dynamic> lt(dynamic value) => FilterOperators.lt(value);');
    buffer.writeln();
    buffer.writeln('  /// Less than or equal');
    buffer.writeln(
        '  static Map<String, dynamic> lte(dynamic value) => FilterOperators.lte(value);');
    buffer.writeln();
    buffer.writeln('  /// Greater than');
    buffer.writeln(
        '  static Map<String, dynamic> gt(dynamic value) => FilterOperators.gt(value);');
    buffer.writeln();
    buffer.writeln('  /// Greater than or equal');
    buffer.writeln(
        '  static Map<String, dynamic> gte(dynamic value) => FilterOperators.gte(value);');
    buffer.writeln();
    buffer.writeln('  /// Contains (string)');
    buffer.writeln(
        '  static Map<String, dynamic> contains(String value) => FilterOperators.contains(value);');
    buffer.writeln();
    buffer.writeln('  /// Starts with (string)');
    buffer.writeln(
        '  static Map<String, dynamic> startsWith(String value) => FilterOperators.startsWith(value);');
    buffer.writeln();
    buffer.writeln('  /// Ends with (string)');
    buffer.writeln(
        '  static Map<String, dynamic> endsWith(String value) => FilterOperators.endsWith(value);');
    buffer.writeln();
    buffer.writeln('  /// AND conditions');
    buffer.writeln(
        '  static Map<String, dynamic> and(List<Map<String, dynamic>> conditions) => FilterOperators.and(conditions);');
    buffer.writeln();
    buffer.writeln('  /// OR conditions');
    buffer.writeln(
        '  static Map<String, dynamic> or(List<Map<String, dynamic>> conditions) => FilterOperators.or(conditions);');
    buffer.writeln();
    buffer.writeln('  /// NOT condition');
    buffer.writeln(
        '  static Map<String, dynamic> none(Map<String, dynamic> condition) => FilterOperators.none(condition);');
    buffer.writeln('}');

    return buffer.toString();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  String _toLowerCamelCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }
}
