/// Prisma Flutter Connector
///
/// A type-safe Flutter connector for Prisma backends using GraphQL.
/// Provides seamless integration between Flutter apps and Prisma ORM
/// with automatic code generation.
library prisma_flutter_connector;

// Core SDK exports
export 'src/client/prisma_client.dart';
export 'src/client/prisma_config.dart';

// Models
export 'src/models/product.dart';
export 'src/models/user.dart';
export 'src/models/order.dart';
export 'src/models/order_item.dart';

// Exceptions
export 'src/exceptions/prisma_exception.dart';
export 'src/exceptions/network_exception.dart';
export 'src/exceptions/not_found_exception.dart';
export 'src/exceptions/validation_exception.dart';

// API interfaces
export 'src/api/product_api.dart';
export 'src/api/user_api.dart';
export 'src/api/order_api.dart';
