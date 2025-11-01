# Architecture Document: Prisma Flutter Connector

## Overview

The Prisma Flutter Connector provides a type-safe, GraphQL-based bridge between Flutter applications and Prisma backends. This document outlines the architectural decisions, component design, and data flow.

## System Architecture

```
┌─────────────────────┐
│   Flutter App       │
│   (Mobile/Web/     │
│    Desktop)         │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Prisma Flutter Connector SDK       │
│  ┌─────────────────────────────┐  │
│  │  PrismaClient               │  │
│  │  - products                  │  │
│  │  - users                     │  │
│  │  - orders                    │  │
│  └──────────┬──────────────────┘  │
│             │                       │
│  ┌──────────▼──────────────────┐  │
│  │  API Interfaces              │  │
│  │  - ProductAPI                │  │
│  │  - UserAPI                   │  │
│  │  - OrderAPI                  │  │
│  └──────────┬──────────────────┘  │
│             │                       │
│  ┌──────────▼──────────────────┐  │
│  │  GraphQL Client              │  │
│  │  (graphql_flutter)           │  │
│  │  - HTTP Link                 │  │
│  │  - WebSocket Link            │  │
│  └──────────┬──────────────────┘  │
│             │                       │
│  ┌──────────▼──────────────────┐  │
│  │  Freezed Models              │  │
│  │  - Product                   │  │
│  │  - User, Order, OrderItem    │  │
│  └─────────────────────────────┘  │
└─────────────────────────────────────┘
           │
           │ HTTP / WebSocket
           │ (GraphQL Queries/Mutations/Subscriptions)
           ▼
┌─────────────────────────────────────┐
│  Backend API (Node.js/TypeScript)   │
│  ┌─────────────────────────────┐  │
│  │  Apollo Server               │  │
│  └──────────┬──────────────────┘  │
│             │                       │
│  ┌──────────▼──────────────────┐  │
│  │  Pothos GraphQL Schema       │  │
│  │  (Generated from Prisma)     │  │
│  └──────────┬──────────────────┘  │
│             │                       │
│  ┌──────────▼──────────────────┐  │
│  │  Prisma ORM                  │  │
│  │  - Query Engine              │  │
│  │  - Type-safe DB access       │  │
│  └──────────┬──────────────────┘  │
└─────────────┼─────────────────────┘
              │
              ▼
      ┌───────────────┐
      │   Database    │
      │  (PostgreSQL/ │
      │   MySQL/      │
      │   SQLite)     │
      └───────────────┘
```

## Component Design

### 1. Flutter SDK Layer

#### PrismaClient
**Purpose:** Main entry point for SDK usage

**Responsibilities:**
- Initialize GraphQL client with configuration
- Provide access to API interfaces (products, users, orders)
- Manage connection lifecycle
- Handle authentication tokens

**Key Files:**
- `lib/src/client/prisma_client.dart`
- `lib/src/client/prisma_config.dart`

#### API Interfaces
**Purpose:** Type-safe, domain-specific APIs for each Prisma model

**Responsibilities:**
- Convert Dart objects to GraphQL variables
- Execute GraphQL operations
- Parse responses into Freezed models
- Handle errors and throw typed exceptions

**Key Files:**
- `lib/src/api/product_api.dart`
- `lib/src/api/user_api.dart`
- `lib/src/api/order_api.dart`

#### Models Layer
**Purpose:** Immutable, type-safe data classes

**Technology:** Freezed + json_serializable

**Responsibilities:**
- Represent domain entities (Product, User, Order, OrderItem)
- Provide JSON serialization/deserialization
- Support value equality and copyWith
- Define input types for mutations
- Define filter types for queries

**Key Files:**
- `lib/src/models/product.dart`
- `lib/src/models/user.dart`
- `lib/src/models/order.dart`
- `lib/src/models/order_item.dart`

#### Exception Handling
**Purpose:** Type-safe error handling

**Exception Hierarchy:**
```
PrismaException (base)
├─ NetworkException
│  ├─ timeout()
│  ├─ noConnection()
│  └─ serverError(statusCode)
├─ NotFoundException
│  └─ resource(type, id)
└─ ValidationException
   ├─ field(field, error)
   └─ multiple(errors)
```

**Key Files:**
- `lib/src/exceptions/prisma_exception.dart`
- `lib/src/exceptions/network_exception.dart`
- `lib/src/exceptions/not_found_exception.dart`
- `lib/src/exceptions/validation_exception.dart`

### 2. GraphQL Communication Layer

#### HTTP Link
- Standard HTTP requests for queries and mutations
- Includes auth headers from configuration
- Handles timeouts and retries

#### WebSocket Link
- Real-time subscriptions
- Auto-reconnect on connection loss
- Heartbeat/keep-alive mechanism

#### Cache Strategy (v0.1.0)
- **Policy:** Network-only (no caching)
- **Rationale:** Simplicity for initial release
- **Future:** v0.2.0 will add Drift-based offline caching

### 3. Backend Layer (Example Implementation)

#### Apollo Server
- GraphQL server implementation
- Handles HTTP and WebSocket protocols
- Integrates with Pothos schema

#### Pothos GraphQL Schema Builder
- Type-safe schema building
- Auto-generates GraphQL types from Prisma schema
- Solves N+1 query problem automatically
- Plugin-based architecture

**Key Plugin:**
- `@pothos/plugin-prisma` - Prisma integration

#### Prisma ORM
- Type-safe database access
- Migration management
- Query optimization
- Connection pooling

**Schema Features:**
- Models: User, Product, Order, OrderItem
- Relations: User → Orders, Order → OrderItems, OrderItem → Product
- Enums: OrderStatus
- Timestamps: createdAt, updatedAt

## Data Flow

### Query Flow (Fetching Products)

```
1. Flutter App
   ↓
   client.products.list(filter: ProductFilter(priceUnder: 100))
   ↓
2. ProductAPI
   ↓
   Builds GraphQL query with variables
   ↓
3. GraphQL Client (HTTP Link)
   ↓
   POST /graphql { query: "...", variables: {...} }
   ↓
4. Apollo Server
   ↓
   Validates query against schema
   ↓
5. Pothos Resolver
   ↓
   ctx.prisma.product.findMany({ where: { price: { lte: 100 } } })
   ↓
6. Prisma ORM
   ↓
   SELECT * FROM products WHERE price <= 100
   ↓
7. Database
   ↓
   Returns rows
   ↓
8. Response Flow (reverse)
   ↓
   Database → Prisma → Pothos → Apollo → GraphQL Client → ProductAPI
   ↓
9. ProductAPI
   ↓
   Parses JSON → List<Product> (Freezed models)
   ↓
10. Flutter App
   ↓
   Displays products in UI
```

### Mutation Flow (Creating Order)

```
1. Flutter App
   ↓
   client.orders.create(input: CreateOrderInput(...))
   ↓
2. OrderAPI
   ↓
   Builds GraphQL mutation with input
   ↓
3. GraphQL Client (HTTP Link)
   ↓
   POST /graphql { mutation: "...", variables: {...} }
   ↓
4. Apollo Server
   ↓
   Validates mutation
   ↓
5. Pothos Resolver
   ↓
   - Fetches product prices
   - Calculates total
   - Creates order with items in transaction
   - Publishes subscription event
   ↓
6. Prisma ORM
   ↓
   BEGIN;
   INSERT INTO orders...
   INSERT INTO order_items...
   COMMIT;
   ↓
7. Database
   ↓
   Returns created order
   ↓
8. PubSub
   ↓
   Publishes "ORDER_CREATED" event
   ↓
9. Response Flow
   ↓
   Database → Prisma → Pothos → Apollo → GraphQL Client → OrderAPI
   ↓
10. OrderAPI
   ↓
   Parses JSON → Order (Freezed model)
   ↓
11. Flutter App
   ↓
   Displays order confirmation
```

### Subscription Flow (Real-time Updates)

```
1. Flutter App
   ↓
   client.orders.subscribeToOrderCreated(userId: "123")
   ↓
2. OrderAPI
   ↓
   Builds GraphQL subscription
   ↓
3. GraphQL Client (WebSocket Link)
   ↓
   WS CONNECT → /graphql
   WS SUBSCRIBE { subscription: "...", variables: {...} }
   ↓
4. Apollo Server (WebSocket)
   ↓
   Registers subscription
   ↓
5. PubSub
   ↓
   Awaits "ORDER_CREATED" events
   ↓
[Later, when order is created...]
   ↓
6. PubSub.publish("ORDER_CREATED", data)
   ↓
7. Apollo Server
   ↓
   Sends WS message to subscribed clients
   ↓
8. GraphQL Client
   ↓
   Receives message over WebSocket
   ↓
9. OrderAPI
   ↓
   Parses JSON → Order → Stream event
   ↓
10. Flutter App
   ↓
   StreamBuilder rebuilds UI with new order
```

## Technology Choices

### Why GraphQL?
1. **Single Endpoint:** Reduces mobile network overhead
2. **Flexible Queries:** Clients request exactly what they need
3. **Type Safety:** Schema-first development with codegen
4. **Subscriptions:** Native real-time support
5. **Prisma Integration:** Pothos plugin auto-generates schema

### Why Pothos?
1. **Active Maintenance:** Nexus is deprecated
2. **Prisma Plugin:** First-class Prisma support
3. **N+1 Solution:** Automatic dataloader integration
4. **Type Safety:** Full TypeScript inference
5. **Modern:** Supports latest GraphQL features

### Why Freezed?
1. **Immutability:** Data integrity for state management
2. **Value Equality:** Reliable comparison in collections
3. **CopyWith:** Easy updates without mutation
4. **Union Types:** Useful for loading/success/error states
5. **JSON Support:** Built-in serialization

### Why graphql_flutter?
1. **Mature:** Well-established in Flutter ecosystem
2. **Full-Featured:** Queries, mutations, subscriptions
3. **Caching:** Built-in (though not used in v0.1.0)
4. **Active:** Maintained by community

## Security Considerations

### Authentication
- Bearer token in Authorization header
- Tokens managed in `PrismaConfig`
- Backend validates tokens on every request

### Data Validation
- Input validation on backend (Prisma schema constraints)
- GraphQL schema validation
- Typed exceptions bubble to Flutter

### Network Security
- HTTPS enforced for production
- WSS (secure WebSocket) for subscriptions
- CORS configuration on backend

## Performance Optimizations

### Backend
- Prisma query optimization
- Connection pooling
- Pothos dataloader (N+1 prevention)
- GraphQL persisted queries (future)

### Flutter
- No caching in v0.1.0 (network-only)
- Freezed models are immutable (memory-efficient)
- Lazy loading for relations (future)

## Future Enhancements (Roadmap)

### v0.2.0: Offline Support
- Drift database integration
- Cache-first queries
- Offline mutations queue
- Sync on reconnect

### v0.3.0: Advanced Features
- Pagination (cursor-based)
- Optimistic UI updates
- Batch operations
- File uploads

### v1.0.0: Production Ready
- Comprehensive error handling
- Retry strategies
- Circuit breaker patterns
- Performance monitoring
- Full test coverage

## Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Exception handling
- Input validation

### Integration Tests
- API interface methods
- GraphQL client communication
- End-to-end data flow

### E2E Tests
- Example app user flows
- Real backend integration

## Monitoring & Observability

### Logging
- Debug mode in `PrismaConfig`
- GraphQL request/response logging
- Backend query logging (Prisma)

### Metrics (Future)
- Request latency
- Error rates
- Cache hit rates

### Tracing (Future)
- OpenTelemetry integration
- Request correlation IDs

## Deployment

### Flutter Package
- Publish to pub.dev
- Semantic versioning
- Changelog maintenance

### Backend Example
- Docker container
- Environment-based configuration
- CI/CD pipeline

## Conclusion

The Prisma Flutter Connector architecture prioritizes:
1. **Type Safety:** End-to-end from database to UI
2. **Developer Experience:** Intuitive API, good documentation
3. **Maintainability:** Clear separation of concerns, modern tooling
4. **Scalability:** Foundation for offline, caching, and advanced features
5. **Production Ready:** Security, error handling, performance

This architecture provides a solid foundation for building Flutter apps with Prisma backends while maintaining flexibility for future enhancements.
