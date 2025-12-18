/// Typed exceptions for Prisma operations.
///
/// These exceptions provide semantic error handling, allowing applications
/// to catch and handle specific database error conditions.
///
/// Error codes are based on Prisma's error code system:
/// - P1xxx: Connection errors
/// - P2xxx: Query errors (constraints, not found, etc.)
/// - P3xxx: Migration errors
/// - P4xxx: Introspection errors
library;

/// Base class for all Prisma exceptions.
sealed class PrismaException implements Exception {
  /// Human-readable error message
  final String message;

  /// Prisma error code (e.g., P2002 for unique constraint violation)
  final String? code;

  /// Original error from the database driver (if available)
  final Object? originalError;

  /// Additional context about the error
  final Map<String, dynamic>? context;

  const PrismaException(
    this.message, {
    this.code,
    this.originalError,
    this.context,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PrismaException');
    if (code != null) buffer.write(' [$code]');
    buffer.write(': $message');
    return buffer.toString();
  }
}

// =============================================================================
// Connection Errors (P1xxx)
// =============================================================================

/// Database connection failed.
///
/// Thrown when the connector cannot establish a connection to the database.
class ConnectionException extends PrismaException {
  /// Database host that was attempted
  final String? host;

  /// Database port that was attempted
  final int? port;

  const ConnectionException(
    super.message, {
    super.code = 'P1000',
    super.originalError,
    super.context,
    this.host,
    this.port,
  });

  @override
  String toString() => 'ConnectionException [$code]: $message';
}

/// Authentication failed.
///
/// Thrown when database credentials are invalid.
class AuthenticationException extends PrismaException {
  /// Username that was attempted
  final String? username;

  const AuthenticationException(
    super.message, {
    super.code = 'P1001',
    super.originalError,
    super.context,
    this.username,
  });

  @override
  String toString() => 'AuthenticationException [$code]: $message';
}

/// Connection timed out.
///
/// Thrown when the database does not respond within the timeout period.
class ConnectionTimeoutException extends PrismaException {
  /// Timeout duration that was exceeded
  final Duration? timeout;

  const ConnectionTimeoutException(
    super.message, {
    super.code = 'P1002',
    super.originalError,
    super.context,
    this.timeout,
  });

  @override
  String toString() => 'ConnectionTimeoutException [$code]: $message';
}

// =============================================================================
// Query Errors (P2xxx)
// =============================================================================

/// Record not found.
///
/// Thrown when a findUnique/findFirst query returns no results,
/// or when trying to update/delete a non-existent record.
class RecordNotFoundException extends PrismaException {
  /// Model name that was queried
  final String? model;

  /// Filter criteria used
  final Map<String, dynamic>? where;

  const RecordNotFoundException(
    super.message, {
    super.code = 'P2001',
    super.originalError,
    super.context,
    this.model,
    this.where,
  });

  @override
  String toString() {
    if (model != null) {
      return 'RecordNotFoundException [$code]: No $model found with criteria: $where';
    }
    return 'RecordNotFoundException [$code]: $message';
  }
}

/// Unique constraint violation.
///
/// Thrown when trying to create/update a record that would violate
/// a unique constraint.
///
/// PostgreSQL error code: 23505
class UniqueConstraintException extends PrismaException {
  /// Field(s) that caused the violation
  final List<String>? fields;

  /// Value that caused the violation
  final dynamic value;

  /// Name of the constraint that was violated
  final String? constraintName;

  const UniqueConstraintException(
    super.message, {
    super.code = 'P2002',
    super.originalError,
    super.context,
    this.fields,
    this.value,
    this.constraintName,
  });

  @override
  String toString() {
    if (fields != null && fields!.isNotEmpty) {
      return 'UniqueConstraintException [$code]: Duplicate value for ${fields!.join(', ')}';
    }
    return 'UniqueConstraintException [$code]: $message';
  }
}

/// Foreign key constraint violation.
///
/// Thrown when trying to create/update a record with a foreign key
/// that references a non-existent record.
///
/// PostgreSQL error code: 23503
class ForeignKeyException extends PrismaException {
  /// Name of the foreign key constraint
  final String? constraintName;

  /// Field that caused the violation
  final String? field;

  /// Referenced table
  final String? referencedTable;

  const ForeignKeyException(
    super.message, {
    super.code = 'P2003',
    super.originalError,
    super.context,
    this.constraintName,
    this.field,
    this.referencedTable,
  });

  @override
  String toString() {
    if (field != null && referencedTable != null) {
      return 'ForeignKeyException [$code]: Invalid reference from $field to $referencedTable';
    }
    return 'ForeignKeyException [$code]: $message';
  }
}

/// Constraint violation (general).
///
/// Thrown when a database constraint is violated (not unique or FK).
/// Examples: CHECK constraints, NOT NULL constraints.
///
/// PostgreSQL error code: 23514 (check), 23502 (not null)
class ConstraintException extends PrismaException {
  /// Name of the constraint that was violated
  final String? constraintName;

  /// Type of constraint (check, not_null, etc.)
  final String? constraintType;

  const ConstraintException(
    super.message, {
    super.code = 'P2004',
    super.originalError,
    super.context,
    this.constraintName,
    this.constraintType,
  });

  @override
  String toString() => 'ConstraintException [$code]: $message';
}

/// Invalid field value.
///
/// Thrown when a field value is invalid for the field type.
class InvalidFieldValueException extends PrismaException {
  /// Field that received the invalid value
  final String? field;

  /// Value that was rejected
  final dynamic value;

  /// Expected type
  final String? expectedType;

  const InvalidFieldValueException(
    super.message, {
    super.code = 'P2006',
    super.originalError,
    super.context,
    this.field,
    this.value,
    this.expectedType,
  });

  @override
  String toString() {
    if (field != null) {
      return 'InvalidFieldValueException [$code]: Invalid value for field $field';
    }
    return 'InvalidFieldValueException [$code]: $message';
  }
}

/// Query timeout.
///
/// Thrown when a query exceeds the configured timeout.
class QueryTimeoutException extends PrismaException {
  /// Timeout duration that was exceeded
  final Duration? timeout;

  /// The query that timed out (truncated for safety)
  final String? query;

  const QueryTimeoutException(
    super.message, {
    super.code = 'P2024',
    super.originalError,
    super.context,
    this.timeout,
    this.query,
  });

  @override
  String toString() => 'QueryTimeoutException [$code]: $message';
}

/// Required value missing.
///
/// Thrown when a required field is missing from a create/update operation.
class RequiredFieldException extends PrismaException {
  /// Field that is required but missing
  final String? field;

  /// Model that the field belongs to
  final String? model;

  const RequiredFieldException(
    super.message, {
    super.code = 'P2012',
    super.originalError,
    super.context,
    this.field,
    this.model,
  });

  @override
  String toString() {
    if (field != null && model != null) {
      return 'RequiredFieldException [$code]: Missing required field $field in $model';
    }
    return 'RequiredFieldException [$code]: $message';
  }
}

/// Related record not found.
///
/// Thrown when trying to connect/disconnect a relation to a non-existent record.
class RelatedRecordNotFoundException extends PrismaException {
  /// Model of the related record
  final String? relatedModel;

  /// Relation name
  final String? relation;

  const RelatedRecordNotFoundException(
    super.message, {
    super.code = 'P2025',
    super.originalError,
    super.context,
    this.relatedModel,
    this.relation,
  });

  @override
  String toString() => 'RelatedRecordNotFoundException [$code]: $message';
}

// =============================================================================
// Transaction Errors
// =============================================================================

/// Transaction failed.
///
/// Thrown when a transaction cannot be completed.
class TransactionException extends PrismaException {
  /// Whether the transaction was rolled back
  final bool rolledBack;

  const TransactionException(
    super.message, {
    super.code = 'P2034',
    super.originalError,
    super.context,
    this.rolledBack = true,
  });

  @override
  String toString() {
    final status = rolledBack ? 'rolled back' : 'unknown state';
    return 'TransactionException [$code]: $message ($status)';
  }
}

// =============================================================================
// Internal Errors
// =============================================================================

/// Internal query engine error.
///
/// Thrown when something unexpected happens in the query engine.
class InternalException extends PrismaException {
  const InternalException(
    super.message, {
    super.code = 'P5000',
    super.originalError,
    super.context,
  });

  @override
  String toString() => 'InternalException [$code]: $message';
}

/// Unsupported operation.
///
/// Thrown when trying to use a feature that is not supported
/// by the current database adapter or Prisma version.
class UnsupportedOperationException extends PrismaException {
  /// The operation that is not supported
  final String? operation;

  /// Database provider that doesn't support it
  final String? provider;

  const UnsupportedOperationException(
    super.message, {
    super.code = 'P5001',
    super.originalError,
    super.context,
    this.operation,
    this.provider,
  });

  @override
  String toString() {
    if (operation != null && provider != null) {
      return 'UnsupportedOperationException [$code]: $operation is not supported by $provider';
    }
    return 'UnsupportedOperationException [$code]: $message';
  }
}

// =============================================================================
// Error Mapping Utilities
// =============================================================================

/// Maps database-specific error codes to PrismaException types.
///
/// Each database has its own error code system:
/// - PostgreSQL: 5-character SQLSTATE codes (e.g., '23505' for unique violation)
/// - MySQL: numeric error codes (e.g., 1062 for duplicate key)
/// - SQLite: numeric error codes (e.g., 19 for constraint)
class PrismaErrorMapper {
  /// Map a PostgreSQL error to a PrismaException.
  static PrismaException fromPostgresError(
    String message, {
    String? sqlState,
    String? constraintName,
    Object? originalError,
  }) {
    switch (sqlState) {
      // Connection errors
      case '08000': // connection_exception
      case '08003': // connection_does_not_exist
      case '08006': // connection_failure
        return ConnectionException(
          message,
          originalError: originalError,
        );

      case '28000': // invalid_authorization_specification
      case '28P01': // invalid_password
        return AuthenticationException(
          message,
          originalError: originalError,
        );

      // Constraint violations
      case '23505': // unique_violation
        return UniqueConstraintException(
          message,
          constraintName: constraintName,
          originalError: originalError,
        );

      case '23503': // foreign_key_violation
        return ForeignKeyException(
          message,
          constraintName: constraintName,
          originalError: originalError,
        );

      case '23502': // not_null_violation
        return ConstraintException(
          message,
          constraintName: constraintName,
          constraintType: 'not_null',
          originalError: originalError,
        );

      case '23514': // check_violation
        return ConstraintException(
          message,
          constraintName: constraintName,
          constraintType: 'check',
          originalError: originalError,
        );

      // Query errors
      case '42P01': // undefined_table
      case '42703': // undefined_column
        return InternalException(
          message,
          originalError: originalError,
        );

      // Timeout
      case '57014': // query_canceled (timeout)
        return QueryTimeoutException(
          message,
          originalError: originalError,
        );

      default:
        return InternalException(
          message,
          originalError: originalError,
          context: {'sqlState': sqlState},
        );
    }
  }

  /// Map a MySQL error to a PrismaException.
  static PrismaException fromMySqlError(
    String message, {
    int? errorCode,
    String? constraintName,
    Object? originalError,
  }) {
    switch (errorCode) {
      case 1044: // Access denied for user
      case 1045: // Access denied (using password)
        return AuthenticationException(
          message,
          originalError: originalError,
        );

      case 1049: // Unknown database
      case 2002: // Can't connect to MySQL server
      case 2003: // Can't connect to MySQL server on host
        return ConnectionException(
          message,
          originalError: originalError,
        );

      case 1062: // Duplicate entry
        return UniqueConstraintException(
          message,
          constraintName: constraintName,
          originalError: originalError,
        );

      case 1451: // Cannot delete or update a parent row (FK)
      case 1452: // Cannot add or update a child row (FK)
        return ForeignKeyException(
          message,
          constraintName: constraintName,
          originalError: originalError,
        );

      case 1048: // Column cannot be null
        return ConstraintException(
          message,
          constraintType: 'not_null',
          originalError: originalError,
        );

      case 4031: // Query timeout
        return QueryTimeoutException(
          message,
          originalError: originalError,
        );

      default:
        return InternalException(
          message,
          originalError: originalError,
          context: {'errorCode': errorCode},
        );
    }
  }

  /// Map a SQLite error to a PrismaException.
  static PrismaException fromSqliteError(
    String message, {
    int? errorCode,
    Object? originalError,
  }) {
    switch (errorCode) {
      case 14: // SQLITE_CANTOPEN
        return ConnectionException(
          message,
          originalError: originalError,
        );

      case 19: // SQLITE_CONSTRAINT
        // SQLite doesn't distinguish constraint types as easily
        if (message.toLowerCase().contains('unique')) {
          return UniqueConstraintException(
            message,
            originalError: originalError,
          );
        }
        if (message.toLowerCase().contains('foreign key')) {
          return ForeignKeyException(
            message,
            originalError: originalError,
          );
        }
        return ConstraintException(
          message,
          originalError: originalError,
        );

      default:
        return InternalException(
          message,
          originalError: originalError,
          context: {'errorCode': errorCode},
        );
    }
  }
}
