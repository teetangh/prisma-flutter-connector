import 'package:prisma_flutter_connector/src/exceptions/prisma_exception.dart';

/// Exception thrown when a network error occurs
class NetworkException extends PrismaException {
  const NetworkException({
    required super.message,
    super.code = 'NETWORK_ERROR',
    super.originalError,
    super.stackTrace,
  });

  factory NetworkException.timeout() {
    return const NetworkException(
      message: 'Request timed out. Please check your internet connection.',
      code: 'TIMEOUT',
    );
  }

  factory NetworkException.noConnection() {
    return const NetworkException(
      message: 'No internet connection available.',
      code: 'NO_CONNECTION',
    );
  }

  factory NetworkException.serverError(int statusCode) {
    return NetworkException(
      message: 'Server error occurred (HTTP $statusCode)',
      code: 'SERVER_ERROR_$statusCode',
    );
  }
}
