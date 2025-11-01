# Prisma Flutter Connector

[![pub package](https://img.shields.io/pub/v/prisma_flutter_connector.svg)](https://pub.dev/packages/prisma_flutter_connector)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/yourusername/prisma-flutter-connector/workflows/Tests/badge.svg)](https://github.com/yourusername/prisma-flutter-connector/actions)

A type-safe, database-agnostic Flutter connector that generates type-safe Dart clients from your Prisma schema. Build Flutter apps with seamless Prisma ORM integration, automatic code generation, and support for multiple databases.

## Features

- **Database Agnostic** - PostgreSQL, MySQL, MongoDB, SQLite, Supabase
- **Type-Safe** - End-to-end type safety from database to UI
- **Code Generation** - Auto-generate Dart models and APIs from Prisma schema
- **GraphQL-Based** - Efficient queries with Pothos + Apollo Server
- **Freezed Models** - Immutable models with JSON serialization
- **Real-time** - WebSocket subscriptions for live updates
- **Error Handling** - Typed exceptions for better debugging
- **Developer-Friendly** - Intuitive API inspired by Prisma Client
- **CI/CD Ready** - GitHub Actions workflows included

## Supported Databases

- **PostgreSQL** - Full support with UUID, JSON, arrays
- **MySQL** - Full support with auto-increment, decimals
- **MongoDB** - Full support with ObjectId, embedded documents
- **SQLite** - Full support with file-based storage
- **Supabase** - Full support with PostgreSQL + Auth integration

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Code Generation](#code-generation)
- [Usage](#usage)
- [Backend Setup](#backend-setup)
- [Database Setup](#database-setup)
- [Architecture](#architecture)
- [Testing](#testing)
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

### 1. Create Your Prisma Schema

```prisma
// schema.prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

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

### 2. Generate Dart Code

```bash
# Generate type-safe Dart models and API clients
dart run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated/
```

This creates:
- `lib/generated/models/` - Freezed models (Product, CreateProductInput, etc.)
- `lib/generated/api/` - Type-safe API clients (ProductsAPI)
- `lib/generated/client.dart` - PrismaClient with all APIs

### 3. Initialize the Client

```dart
import 'package:prisma_flutter_connector/prisma_flutter_connector.dart';
import 'generated/client.dart';

final client = PrismaClient(
  config: PrismaConfig(
    graphqlEndpoint: 'http://localhost:4000/graphql',
    debugMode: true,
  ),
);
```

### 4. Use Type-Safe APIs

```dart
// List all products
final products = await client.products.list();

// Filter products
final cheapProducts = await client.products.list(
  filter: ProductFilter(priceUnder: 100),
);

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
  id: newProduct.id,
  input: UpdateProductInput(stock: 5),
);
```

## Code Generation

The connector works by generating type-safe Dart code from your Prisma schema. This ensures complete type safety from your database to your Flutter UI.

### Generator CLI

```bash
dart run prisma_flutter_connector:generate [options]
```

**Options:**
- `--schema` - Path to your Prisma schema file (required)
- `--output` - Output directory for generated code (required)

**Example:**
```bash
dart run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated/
```

### What Gets Generated

For each model in your Prisma schema, the generator creates:

1. **Freezed Model** (`models/product.dart`)
   ```dart
   @freezed
   class Product with _$Product {
     const factory Product({
       required String id,
       required String name,
       required String description,
       required double price,
       required int stock,
       required DateTime createdAt,
       required DateTime updatedAt,
     }) = _Product;

     factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
   }
   ```

2. **Input Types** (`models/product_input.dart`)
   ```dart
   @freezed
   class CreateProductInput with _$CreateProductInput {
     const factory CreateProductInput({
       required String name,
       required String description,
       required double price,
       int? stock,
     }) = _CreateProductInput;
   }

   @freezed
   class UpdateProductInput with _$UpdateProductInput {
     const factory UpdateProductInput({
       String? name,
       String? description,
       double? price,
       int? stock,
     }) = _UpdateProductInput;
   }
   ```

3. **Filter Types** (`models/product_filter.dart`)
   ```dart
   @freezed
   class ProductFilter with _$ProductFilter {
     const factory ProductFilter({
       String? nameContains,
       double? priceUnder,
       double? priceOver,
       bool? inStock,
     }) = _ProductFilter;
   }
   ```

4. **API Client** (`api/products_api.dart`)
   ```dart
   class ProductsAPI extends BaseAPI<Product> {
     Future<Product?> findUnique({required String id});
     Future<List<Product>> list({ProductFilter? filter, ProductOrderBy? orderBy});
     Future<Product> create({required CreateProductInput input});
     Future<Product> update({required String id, required UpdateProductInput input});
     Future<Product> delete({required String id});
   }
   ```

5. **PrismaClient** (`client.dart`)
   ```dart
   class PrismaClient extends BasePrismaClient {
     late final ProductsAPI products;
     // ... other model APIs
   }
   ```

### Running Build Runner

After code generation, run build_runner to generate Freezed and JSON serialization code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Workflow

```bash
# 1. Define your Prisma schema
vim prisma/schema.prisma

# 2. Generate Prisma Client (Node.js)
npx prisma generate

# 3. Generate Dart code
dart run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated/

# 4. Generate Freezed code
flutter pub run build_runner build --delete-conflicting-outputs

# 5. Use in your app
# Import generated client and start querying!
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

## Database Setup

The connector supports multiple databases. Choose the one that fits your needs:

### PostgreSQL

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(uuid())
  email     String   @unique
  name      String
  posts     Post[]
  createdAt DateTime @default(now())
}
```

**Connection String:**
```env
DATABASE_URL="postgresql://user:password@localhost:5432/mydb"
```

**Docker:**
```bash
docker run -d \
  -e POSTGRES_PASSWORD=password \
  -p 5432:5432 \
  postgres:16-alpine
```

### MySQL

```prisma
datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

model Product {
  id       Int      @id @default(autoincrement())
  name     String
  price    Decimal  @db.Decimal(10, 2)
  category Category @relation(fields: [categoryId], references: [id])
}
```

**Connection String:**
```env
DATABASE_URL="mysql://user:password@localhost:3306/mydb"
```

**Docker:**
```bash
docker run -d \
  -e MYSQL_ROOT_PASSWORD=password \
  -e MYSQL_DATABASE=mydb \
  -p 3306:3306 \
  mysql:8.0
```

### MongoDB

```prisma
datasource db {
  provider = "mongodb"
  url      = env("DATABASE_URL")
}

model Blog {
  id       String   @id @default(auto()) @map("_id") @db.ObjectId
  title    String
  content  String
  tags     String[]
  metadata Json?
}
```

**Connection String:**
```env
DATABASE_URL="mongodb://localhost:27017/mydb"
```

**Docker:**
```bash
docker run -d \
  -p 27017:27017 \
  mongo:7.0
```

### SQLite

```prisma
datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

model Task {
  id          String   @id @default(cuid())
  title       String
  completed   Boolean  @default(false)
  priority    Int      @default(0)
}
```

**No installation needed** - SQLite is file-based!

### Supabase

```prisma
datasource db {
  provider = "postgresql"
  url      = env("SUPABASE_DATABASE_URL")
}

model Profile {
  id        String   @id @default(uuid())
  userId    String   @unique  // Supabase Auth user ID
  username  String   @unique
  avatarUrl String?
}
```

**Connection String:**
```env
SUPABASE_DATABASE_URL="postgresql://postgres:[YOUR-PASSWORD]@db.yourproject.supabase.co:5432/postgres"
```

Get your connection string from Supabase project settings.

### Running Migrations

```bash
# Create a migration
npx prisma migrate dev --name init

# Apply migrations (production)
npx prisma migrate deploy

# MongoDB: use db push instead
npx prisma db push
```

## Architecture

### High-Level Overview

```
Prisma Schema (.prisma)
    ↓
Code Generator (bin/generate.dart)
    ↓
├── Dart Models (Freezed)
├── API Clients (type-safe)
└── PrismaClient
    ↓
GraphQL Client (graphql_flutter)
    ↓
Backend (Apollo Server + Pothos)
    ↓
Prisma ORM
    ↓
Database (PostgreSQL/MySQL/MongoDB/SQLite/Supabase)
```

### Components

#### 1. Code Generator (`lib/src/generator/`)
- **PrismaParser**: Parses `.prisma` schema files
- **ModelGenerator**: Generates Freezed models and input types
- **APIGenerator**: Generates type-safe API clients
- **CLI Tool**: `bin/generate.dart` - Command-line interface

#### 2. Runtime (`lib/src/`)
- **BasePrismaClient**: Generic client that works with any schema
- **BaseAPI**: Base class for generated API clients
- **PrismaConfig**: Configuration (endpoints, auth, caching)
- **Exceptions**: Typed error handling

#### 3. Generated Code
- **Models**: Freezed classes with JSON serialization
- **Input Types**: CreateInput, UpdateInput for mutations
- **Filter Types**: Type-safe query filters
- **API Clients**: One per model (ProductsAPI, UsersAPI, etc.)
- **PrismaClient**: Main entry point with all APIs

#### 4. Backend Stack
- **GraphQL** - Chosen over REST for mobile efficiency
- **Pothos GraphQL** - Auto-generates schema from Prisma
- **Apollo Server** - GraphQL server with subscriptions
- **Prisma ORM** - Database ORM with migrations

### Why Code Generation?

1. **Database Agnostic**: Works with any Prisma-supported database
2. **Zero Hardcoding**: No model-specific code in the library
3. **Type Safety**: Full type safety from database to UI
4. **Developer Experience**: One command to generate entire client
5. **Maintainability**: Schema changes automatically propagate

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture.

## Testing

The connector includes comprehensive tests across multiple databases with easy-to-use Makefile commands and test scripts.

### Quick Start

```bash
# Run all tests (recommended)
make test-all

# Run unit tests only
make test-unit

# Run specific database tests
make test-postgres
make test-mysql
make test-mongodb
make test-sqlite
```

### Test Structure

```
test/
├── unit/               # Unit tests for components
├── integration/        # Integration tests with real databases
│   ├── postgres/      # PostgreSQL tests
│   ├── mysql/         # MySQL tests
│   ├── mongodb/       # MongoDB tests
│   ├── sqlite/        # SQLite tests
│   └── supabase/      # Supabase tests
└── e2e/               # End-to-end tests
```

### Using Makefile (Recommended)

```bash
# Testing
make test-all          # Run all tests (lint + unit + integration)
make test-unit         # Run unit tests
make test-integration  # Run all integration tests
make test-postgres     # PostgreSQL integration tests
make test-mysql        # MySQL integration tests
make test-mongodb      # MongoDB integration tests
make test-sqlite       # SQLite integration tests
make test-supabase     # Supabase integration tests (requires .env)

# Database Setup
make setup-postgres    # Start PostgreSQL container
make setup-mysql       # Start MySQL container
make setup-mongodb     # Start MongoDB container

# Cleanup
make cleanup-all       # Stop all containers

# Code Quality
make lint              # Format and analyze code
make format            # Format Dart code
make analyze           # Run Dart analyzer
```

### Using Test Scripts

```bash
# Run entire test suite
./scripts/test-runner.sh

# Run only unit tests
./scripts/test-runner.sh --only-unit

# Run only integration tests
./scripts/test-runner.sh --only-integration

# Test specific database
./scripts/test-database.sh postgres
./scripts/test-database.sh mysql
./scripts/test-database.sh mongodb
./scripts/test-database.sh sqlite
```

See [test/README.md](test/README.md) for detailed testing instructions and manual setup.

### GitHub Actions CI/CD

The project uses **modular workflows** for better maintainability:

**Workflows:**
- `.github/workflows/ci.yml` - Master workflow (runs all tests)
- `.github/workflows/unit-tests.yml` - Unit tests
- `.github/workflows/lint.yml` - Code quality
- `.github/workflows/*-integration.yml` - Individual database tests

**Test Execution:**
1. Code quality checks (formatting, linting)
2. Unit tests
3. Integration tests (run in parallel):
   - PostgreSQL (GitHub Actions service)
   - MySQL (GitHub Actions service)
   - MongoDB (Docker Compose)
   - SQLite (file-based)
   - Supabase (requires secrets)

**Triggering Workflows:**
- Automatically on push/PR to `main` or `develop`
- Manually from GitHub Actions tab (any workflow)

View workflows in [.github/workflows/](.github/workflows/)

### Contributing Tests

When adding features:

1. Add unit tests for new components
2. Add integration tests for database-specific features
3. Run `make test-all` before submitting PR
4. Ensure all CI checks pass
5. Update test documentation if needed

See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md) for contribution guidelines.

## Documentation

### Core Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design and components
- [API Decision](docs/API_DECISION.md) - Why GraphQL over REST
- [Design Blueprint](docs/DESIGN_BLUEPRINT.md) - Original design document

### Testing & Contributing

- [Test README](test/README.md) - Testing guide for all databases
- [Contributing Guide](.github/CONTRIBUTING.md) - How to contribute
- [GitHub Actions](.github/workflows/test.yml) - CI/CD configuration

### Examples

- [E-commerce Example](examples/ecommerce/) - Full-featured example app
- [Backend Example](backend_example/) - GraphQL backend setup

### Additional Resources

- [Changelog](CHANGELOG.md) - Version history
- [License](LICENSE) - MIT License

## Roadmap

### v0.1.0 (Current)

- Code generation from Prisma schema
- Multi-database support (PostgreSQL, MySQL, MongoDB, SQLite, Supabase)
- Type-safe Freezed models
- GraphQL-based API clients
- Basic CRUD operations
- Real-time subscriptions
- Error handling
- Comprehensive test suite
- CI/CD with GitHub Actions

### v0.2.0 (Planned)

- Offline support with Drift
- Cache-first queries
- Optimistic UI updates
- Pagination (cursor-based)
- Aggregations (count, sum, avg)
- Relations loading (include/select)

### v0.3.0 (Future)

- Batch operations
- File uploads
- Advanced filters (full-text search)
- Transaction support
- Query builder API
- Middleware support

### v1.0.0 (Future)

- Production stability
- Performance optimizations
- Comprehensive documentation
- Migration guides
- VS Code extension
- CLI improvements

## Contributing

Contributions are welcome! Please read our [Contributing Guide](.github/CONTRIBUTING.md) for details on:

- Development setup
- Running tests
- Code style guidelines
- Pull request process
- Setting up GitHub secrets for CI/CD

Quick start:

1. Fork the repository
2. Clone and initialize submodules: `git clone --recurse-submodules`
3. Install dependencies: `flutter pub get`
4. Create a feature branch: `git checkout -b feature/my-feature`
5. Make your changes and add tests
6. Run tests: `flutter test`
7. Run analyzer: `flutter analyze`
8. Commit and push
9. Open a Pull Request

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
