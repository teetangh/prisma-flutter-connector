## 0.1.0 - 2025-11-01

### Added
- Initial release of Prisma Flutter Connector
- GraphQL client integration using Ferry
- Type-safe models with Freezed
- E-commerce example (Product, Order, User models)
- Basic CRUD operations (queries and mutations)
- Error handling with custom exceptions
- Backend example using Prisma + Pothos + Apollo Server
- Comprehensive documentation

### Architecture
- GraphQL API protocol (chosen over REST for better Prisma integration)
- Pothos for GraphQL schema generation from Prisma
- Ferry for type-safe Dart code generation
- No offline caching in v0.1.0 (planned for v0.2.0)
