/// Base exception for all Prisma-related errors
class PrismaException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const PrismaException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    if (code != null) {
      return 'PrismaException [$code]: $message';
    }
    return 'PrismaException: $message';
  }
}
