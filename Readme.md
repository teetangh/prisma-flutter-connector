# Prisma Flutter Connector

[![pub package](https://img.shields.io/pub/v/prisma_flutter_connector.svg)](https://pub.dev/packages/prisma_flutter_connector)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A type-safe, GraphQL-based Flutter connector for Prisma backends. Build Flutter apps with seamless Prisma ORM integration, automatic code generation, and real-time subscriptions.

## Features

✅ **Type-Safe** - End-to-end type safety from database to UI
✅ **GraphQL API** - Efficient queries with Pothos + Apollo Server
✅ **Code Generation** - Freezed models with JSON serialization
✅ **Real-time** - WebSocket subscriptions for live updates
✅ **Error Handling** - Typed exceptions for better debugging
✅ **Developer-Friendly** - Intuitive API inspired by Prisma Client
✅ **Production Ready** - Used in real-world applications

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Backend Setup](#backend-setup)
- [Architecture](#architecture)
- [Documentation](#documentation)
- [Roadmap](#roadmap)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  prisma_flutter_connector: ^0.1.0
```

Run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize the Client

```dart
import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';

final client = PrismaClient(
  config: PrismaConfig(
    graphqlEndpoint: 'http://localhost:4000/graphql',
    debugMode: true,
  ),
);
```

### 2. Query Data

```dart
// List all products
final products = await client.products.list();

// Filter products
final cheapProducts = await client.products.list(
  filter: ProductFilter(priceUnder: 100),
);

// Get single product
final product = await client.products.findUnique(id: 'product-id');
```

### 3. Create & Update

```dart
// Create product
final newProduct = await client.products.create(
  input: CreateProductInput(
    name: 'Laptop',
    description: 'Gaming laptop',
    price: 1999.99,
    stock: 10,
  ),
);

// Update product
final updated = await client.products.update(
  id: product.id,
  input: UpdateProductInput(stock: 5),
);
```

### 4. Real-time Subscriptions

```dart
// Subscribe to new orders
final subscription = client.orders.subscribeToOrderCreated();

subscription.listen((order) {
  print('New order: ${order.id} - Total: \$${order.total}');
});
```

## Usage

### Queries

```dart
// List with filters
final products = await client.products.list(
  filter: ProductFilter(
    nameContains: 'laptop',
    priceUnder: 2000,
    inStock: true,
  ),
);

// Find unique
final product = await client.products.findUnique(id: 'prod-123');

// Get order with relations
final order = await client.orders.findUnique(id: 'order-123');
print('Order Total: \$${order?.total}');
print('Items: ${order?.items?.length}');
```

### Mutations

```dart
// Create user
final user = await client.users.create(
  input: CreateUserInput(
    email: 'alice@example.com',
    name: 'Alice Johnson',
  ),
);

// Create order
final order = await client.orders.create(
  input: CreateOrderInput(
    userId: user.id,
    items: [
      OrderItemInput(productId: 'prod-1', quantity: 2),
    ],
  ),
);

// Update order status
final updated = await client.orders.update(
  id: order.id,
  input: UpdateOrderInput(status: OrderStatus.shipped),
);

// Delete product
final deleted = await client.products.delete(id: 'product-id');
```

### Subscriptions

```dart
// Subscribe to order creation
final subscription = client.orders.subscribeToOrderCreated(
  userId: 'user-123',
);

subscription.listen(
  (order) => print('New order: ${order.id}'),
  onError: (error) => print('Error: $error'),
);

// Subscribe to order status changes
final statusSub = client.orders.subscribeToOrderStatusChanged(
  orderId: 'order-123',
);

statusSub.listen((order) {
  print('Status: ${order.status}');
});
```

### Error Handling

```dart
try {
  final product = await client.products.findUnique(id: 'invalid-id');
} on NotFoundException catch (e) {
  print('Not found: ${e.message}');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  e.fieldErrors?.forEach((field, errors) {
    print('  $field: ${errors.join(", ")}');
  });
} on NetworkException catch (e) {
  print('Network error: ${e.message}');
} on PrismaException catch (e) {
  print('Error: ${e.message}');
}
```

## Backend Setup

This package requires a GraphQL backend using Prisma + Pothos + Apollo Server. See the [backend example](backend_example/) for complete implementation.

### Quick Backend Setup

```bash
cd backend_example
npm install
cp .env.example .env
npm run prisma:generate
npm run prisma:migrate
npm run prisma:seed
npm run dev
```

The GraphQL API will be available at `http://localhost:4000/graphql`.

### Prisma Schema Example

```prisma
model Product {
  id          String   @id @default(cuid())
  name        String
  description String
  price       Float
  stock       Int      @default(0)
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

See [backend_example/prisma/schema.prisma](backend_example/prisma/schema.prisma) for the complete E-commerce schema.

## Architecture

```
Flutter App → PrismaClient → GraphQL → Apollo Server → Pothos Schema → Prisma ORM → Database
```

The connector uses:
- **GraphQL** - Chosen over REST for mobile efficiency (see [docs/API_DECISION.md](docs/API_DECISION.md))
- **Pothos** - Auto-generates GraphQL schema from Prisma
- **Freezed** - Type-safe immutable models
- **graphql_flutter** - GraphQL client with subscription support

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design and components
- [API Decision](docs/API_DECISION.md) - Why GraphQL over REST
- [Design Blueprint](docs/DESIGN_BLUEPRINT.md) - Original design document
- [Backend README](backend_example/README.md) - Backend setup guide
- [Changelog](CHANGELOG.md) - Version history

## Roadmap

### v0.1.0 (Current) ✅
- Basic CRUD operations
- Type-safe models with Freezed
- GraphQL queries and mutations
- Real-time subscriptions
- Error handling
- E-commerce example

### v0.2.0 (Planned)
- Offline support with Drift
- Cache-first queries
- Optimistic UI updates
- Pagination (cursor-based)

### v0.3.0 (Future)
- Batch operations
- File uploads
- Advanced filters
- Aggregations

### v1.0.0 (Future)
- Production stability
- Performance optimizations
- Comprehensive tests
- Migration guides

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push and open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Created with ❤️ for the Flutter and Prisma communities.

Special thanks to:
- [Prisma](https://www.prisma.io/) - Next-generation ORM
- [Pothos GraphQL](https://pothos-graphql.dev/) - Type-safe schema builder
- [Freezed](https://pub.dev/packages/freezed) - Immutable code generation

## Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://github.com/yourusername/prisma-flutter-connector/issues)
- 💬 [Discussions](https://github.com/yourusername/prisma-flutter-connector/discussions)

---

**Note:** This is v0.1.0 - the initial release. Offline caching and advanced features are planned for future versions.
