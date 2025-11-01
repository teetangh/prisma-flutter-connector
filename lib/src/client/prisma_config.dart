/// Configuration for Prisma Flutter Connector
class PrismaConfig {
  /// GraphQL endpoint URL
  final String graphqlEndpoint;

  /// Optional authentication token
  final String? authToken;

  /// Custom HTTP headers
  final Map<String, String>? headers;

  /// Request timeout in milliseconds
  final int timeoutMs;

  /// Enable debug logging
  final bool debugMode;

  const PrismaConfig({
    required this.graphqlEndpoint,
    this.authToken,
    this.headers,
    this.timeoutMs = 30000,
    this.debugMode = false,
  });

  /// Get all headers including auth token
  Map<String, String> get allHeaders {
    final Map<String, String> allHeaders = {};

    // Add custom headers
    if (headers != null) {
      allHeaders.addAll(headers!);
    }

    // Add auth token if provided
    if (authToken != null) {
      allHeaders['Authorization'] = 'Bearer $authToken';
    }

    return allHeaders;
  }

  /// Create a copy with updated values
  PrismaConfig copyWith({
    String? graphqlEndpoint,
    String? authToken,
    Map<String, String>? headers,
    int? timeoutMs,
    bool? debugMode,
  }) {
    return PrismaConfig(
      graphqlEndpoint: graphqlEndpoint ?? this.graphqlEndpoint,
      authToken: authToken ?? this.authToken,
      headers: headers ?? this.headers,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      debugMode: debugMode ?? this.debugMode,
    );
  }
}
