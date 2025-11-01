# E-commerce Example

This example demonstrates using the Prisma Flutter Connector with an e-commerce schema.

## Schema

The example uses a Prisma schema with:
- **User** - Customer accounts
- **Product** - Items for sale
- **Order** - Customer orders
- **OrderItem** - Line items in orders

## Running the Example

### 1. Start the Backend

```bash
cd ../../backend_example
npm install
npm run prisma:generate
npm run prisma:migrate
npm run prisma:seed
npm run dev
```

### 2. Generate Dart Code

```bash
cd ../examples/ecommerce
flutter pub get

# Generate code from Prisma schema
flutter pub run prisma_flutter_connector:generate \
  --schema prisma/schema.prisma \
  --output lib/generated/
```

### 3. Run the App

```bash
flutter run
```

## Generated Files

After running the generator, you'll see:
- `lib/generated/models/` - Freezed models for each Prisma model
- `lib/generated/api/` - API interfaces for queries and mutations
- `lib/generated/prisma_client.dart` - Configured client

## Usage

```dart
import 'package:ecommerce_example/generated/prisma_client.dart';

final client = PrismaClient(
  config: PrismaConfig(
    graphqlEndpoint: 'http://localhost:4000/graphql',
  ),
);

// Query products
final products = await client.products.list(
  filter: ProductFilter(priceUnder: 100),
);

// Create order
final order = await client.orders.create(
  input: CreateOrderInput(
    userId: 'user-id',
    items: [
      OrderItemInput(productId: 'prod-1', quantity: 2),
    ],
  ),
);
```
