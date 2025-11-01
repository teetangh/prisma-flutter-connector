import 'package:prisma_flutter_connector/src/exceptions/prisma_exception.dart';

/// Exception thrown when validation fails
class ValidationException extends PrismaException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
    super.originalError,
    super.stackTrace,
  });

  factory ValidationException.field(String field, String error) {
    return ValidationException(
      message: 'Validation failed for field "$field": $error',
      fieldErrors: {
        field: [error]
      },
    );
  }

  factory ValidationException.multiple(Map<String, List<String>> errors) {
    final errorCount = errors.values.fold<int>(
      0,
      (count, errors) => count + errors.length,
    );
    return ValidationException(
      message: 'Validation failed with $errorCount error(s)',
      fieldErrors: errors,
    );
  }

  @override
  String toString() {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final formattedErrors = fieldErrors!.entries
          .map((e) => '  ${e.key}: ${e.value.join(", ")}')
          .join('\n');
      return 'ValidationException: $message\n$formattedErrors';
    }
    return super.toString();
  }
}
