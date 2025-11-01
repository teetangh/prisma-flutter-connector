import 'package:prisma_flutter_connector/src/exceptions/prisma_exception.dart';

/// Exception thrown when a requested resource is not found
class NotFoundException extends PrismaException {
  final String? resourceType;
  final String? resourceId;

  const NotFoundException({
    required super.message,
    super.code = 'NOT_FOUND',
    this.resourceType,
    this.resourceId,
    super.originalError,
    super.stackTrace,
  });

  factory NotFoundException.resource(String type, String id) {
    return NotFoundException(
      message: '$type with ID "$id" not found',
      resourceType: type,
      resourceId: id,
    );
  }

  @override
  String toString() {
    if (resourceType != null && resourceId != null) {
      return 'NotFoundException: $resourceType with ID "$resourceId" not found';
    }
    return super.toString();
  }
}
