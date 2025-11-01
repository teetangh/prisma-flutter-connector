# Prisma Flutter Backend Example

This is an example GraphQL backend using Prisma + Pothos + Apollo Server for the Prisma Flutter Connector.

## Features

- **Prisma ORM** for type-safe database access
- **Pothos GraphQL** for schema generation from Prisma
- **Apollo Server** for GraphQL API
- **SQLite** database (easy setup, no external dependencies)
- **WebSocket subscriptions** support
- **E-commerce schema** (User, Product, Order, OrderItem)

## Getting Started

### Prerequisites

- Node.js 18+ and npm
- (Optional) Prisma Studio for database visualization

### Installation

1. Install dependencies:
```bash
cd backend_example
npm install
```

2. Set up environment variables:
```bash
cp .env.example .env
```

3. Generate Prisma Client:
```bash
npm run prisma:generate
```

4. Run migrations:
```bash
npm run prisma:migrate
```

5. (Optional) Seed the database:
```bash
npm run prisma:seed
```

### Running the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production build:
```bash
npm run build
npm start
```

The GraphQL API will be available at `http://localhost:4000/graphql`

### Prisma Studio

To explore the database visually:
```bash
npm run prisma:studio
```

Open `http://localhost:5555` in your browser.

## GraphQL Schema

The server exposes the following operations:

### Queries

- `user(id: ID!)` - Get single user
- `users(filter: UserFilter, orderBy: UserOrderBy)` - List users
- `product(id: ID!)` - Get single product
- `products(filter: ProductFilter, orderBy: ProductOrderBy)` - List products
- `order(id: ID!)` - Get single order with items
- `orders(filter: OrderFilter, orderBy: OrderOrderBy)` - List orders

### Mutations

- `createUser(input: CreateUserInput!)` - Create new user
- `updateUser(id: ID!, input: UpdateUserInput!)` - Update user
- `deleteUser(id: ID!)` - Delete user
- `createProduct(input: CreateProductInput!)` - Create new product
- `updateProduct(id: ID!, input: UpdateProductInput!)` - Update product
- `deleteProduct(id: ID!)` - Delete product
- `createOrder(input: CreateOrderInput!)` - Create new order
- `updateOrder(id: ID!, input: UpdateOrderInput!)` - Update order status

### Subscriptions

- `orderCreated(userId: ID)` - Subscribe to new orders
- `orderStatusChanged(orderId: ID!)` - Subscribe to order status updates

## Testing with GraphQL Playground

Navigate to `http://localhost:4000/graphql` and try:

```graphql
# Create a product
mutation {
  createProduct(input: {
    name: "Laptop"
    description: "High-performance laptop"
    price: 999.99
    stock: 10
  }) {
    id
    name
    price
  }
}

# Query products
query {
  products(filter: { priceUnder: 1000 }) {
    id
    name
    price
    stock
  }
}

# Create an order
mutation {
  createOrder(input: {
    userId: "user-id-here"
    items: [
      { productId: "product-id-here", quantity: 2 }
    ]
  }) {
    id
    total
    status
    items {
      product {
        name
      }
      quantity
      price
    }
  }
}
```

## Project Structure

```
backend_example/
├── prisma/
│   ├── schema.prisma      # Database schema
│   └── dev.db             # SQLite database (generated)
├── src/
│   ├── server.ts          # Apollo Server setup
│   ├── schema.ts          # Pothos schema builder
│   ├── seed.ts            # Database seeding script
│   └── context.ts         # GraphQL context
├── .env                   # Environment variables
├── package.json
└── tsconfig.json
```

## Connecting from Flutter

Update your Flutter app to point to this GraphQL endpoint:

```dart
final sdk = PrismaFlutterSDK(
  graphqlEndpoint: 'http://localhost:4000/graphql',
);
```

For real devices/emulators, use your machine's IP address instead of `localhost`.
