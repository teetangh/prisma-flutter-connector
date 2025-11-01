# API Protocol Decision: GraphQL over REST

## Executive Summary

After comprehensive research and analysis, we chose **GraphQL** as the primary API protocol for the Prisma Flutter Connector. This document explains the rationale, trade-offs, and implementation details.

## Decision

**Primary Protocol:** GraphQL with Pothos + Apollo Server
**Implementation:** Prisma → Pothos GraphQL Schema → Apollo Server → Flutter GraphQL Client
**Status:** ✅ Approved and Implemented
**Date:** 2025-11-01

## Background

The Prisma Flutter Connector needs an API protocol to bridge Flutter applications with Prisma backends. The primary candidates were:

1. **GraphQL** - Query language for APIs
2. **REST** - Traditional HTTP-based architecture
3. **tRPC** - TypeScript RPC framework

## Research Findings

### GraphQL Adoption (2024-2025)

- **61%+** of organizations now use GraphQL
- Major production users: GitHub, Shopify, Facebook, Airbnb
- Growing adoption in mobile development
- Strong tooling ecosystem for both backend and Flutter

### Prisma Integration

GraphQL has significantly better Prisma integration:

| Aspect | GraphQL | REST |
|--------|---------|------|
| Schema Generation | **Automatic** (Pothos plugin) | Manual controllers |
| Type Safety | End-to-end | OpenAPI + Retrofit |
| Relations | Native (nested queries) | Multiple endpoints |
| N+1 Problem | Auto-solved (Pothos dataloader) | Manual optimization |
| Maintenance | Low (schema-driven) | High (boilerplate) |

### Flutter Ecosystem

| Feature | GraphQL | REST |
|---------|---------|------|
| Client Library | graphql_flutter | Dio + Retrofit |
| Code Generation | Ferry, Artemis | retrofit_generator |
| Subscriptions | Native WebSocket | Custom implementation |
| Caching | Built-in normalized cache | HTTP caching |
| Bundle Size | Larger | Smaller |

## Decision Criteria & Evaluation

### 1. Prisma Integration (Weight: 30%)

**Winner: GraphQL**

- **Pothos** provides first-class Prisma support via `@pothos/plugin-prisma`
- Auto-generates GraphQL schema from Prisma schema
- Automatic N+1 query optimization
- Type-safe resolvers with full TypeScript inference

**REST Alternative:**
- Requires manual controller creation for each model
- Manual filter/sort/pagination logic
- No automatic schema generation from Prisma
- More boilerplate code

### 2. Mobile Performance (Weight: 25%)

**Winner: GraphQL**

- **Single endpoint:** Reduces DNS lookups, connection overhead
- **Precise data fetching:** ~30% reduction in data transfer (no over-fetching)
- **Batching:** Multiple resources in one request
- **Battery efficiency:** Fewer network requests = less radio usage

**Example:**
```
REST: 3 requests for order with items and products
- GET /orders/123
- GET /orders/123/items
- GET /products?ids=1,2,3

GraphQL: 1 request
- order(id: "123") { items { product { name } } }
```

### 3. Real-time Support (Weight: 20%)

**Winner: GraphQL**

- **Native subscriptions:** GraphQL spec includes subscription support
- **WebSocket integration:** Standardized via graphql-ws
- **Prisma Pulse ready:** Future integration with Prisma's CDC service

**REST Alternative:**
- Requires separate WebSocket/SSE layer
- No standard pattern
- More complex client implementation

### 4. Developer Experience (Weight: 15%)

**Winner: GraphQL (for this use case)**

- **Self-documenting:** GraphQL introspection provides schema docs
- **Playground:** Built-in testing tool (GraphQL Playground)
- **Type-safe:** End-to-end types from DB → API → Flutter
- **Flexible:** Clients query exactly what they need

**REST Advantage:**
- Simpler mental model for beginners
- Well-understood HTTP semantics
- Easier debugging with standard HTTP tools

### 5. Tooling & Ecosystem (Weight: 10%)

**Tie**

**GraphQL:**
- Pothos, Apollo Server (backend)
- graphql_flutter, Ferry (Flutter)
- GraphQL Playground, GraphiQL

**REST:**
- Express, Fastify (backend)
- Dio, Retrofit (Flutter)
- Swagger/OpenAPI tooling

## Trade-offs Analysis

### GraphQL Advantages

✅ **Eliminates over-fetching:** Clients specify exact data requirements
✅ **Single endpoint:** Simplifies mobile networking
✅ **Strong typing:** GraphQL schema provides contract
✅ **Introspection:** Self-documenting API
✅ **Subscriptions:** Native real-time support
✅ **Batching:** Multiple operations in one request
✅ **Versioning:** Additive changes, field deprecation

### GraphQL Disadvantages

❌ **Learning curve:** Steeper than REST
❌ **Caching complexity:** HTTP caching doesn't work as well
❌ **Larger bundle:** GraphQL client libraries are bigger
❌ **Query complexity:** Can enable expensive queries
❌ **File uploads:** Requires multipart spec (not standardized)

### REST Advantages

✅ **Simplicity:** Well-understood HTTP semantics
✅ **HTTP caching:** Standard browser/CDN caching
✅ **Smaller client:** Lightweight HTTP libraries
✅ **File uploads:** Standard multipart/form-data
✅ **Debugging:** Standard HTTP tools (curl, Postman)

### REST Disadvantages

❌ **Over-fetching:** Fixed response structures
❌ **Multiple endpoints:** More requests for related data
❌ **Versioning:** URL-based (/v1/, /v2/)
❌ **Documentation:** Requires separate OpenAPI/Swagger
❌ **No subscriptions:** Requires custom WebSocket layer

## Why Not tRPC?

tRPC was considered but rejected for Flutter:

**Pros:**
- End-to-end TypeScript type safety
- RPC-style API (easy to use)
- Growing adoption in TypeScript ecosystem

**Cons:**
- **Flutter incompatibility:** Designed for TypeScript → TypeScript
- **No native Dart support:** Would need custom client
- **Loses main benefit:** Type safety doesn't transfer to Dart
- **Immature tooling:** Limited Flutter ecosystem

**Verdict:** Great for React/React Native, poor fit for Flutter

## Implementation Details

### Chosen Stack

**Backend:**
```json
{
  "@prisma/client": "^5.8.0",
  "@pothos/core": "^3.41.0",
  "@pothos/plugin-prisma": "^3.64.0",
  "apollo-server-express": "^4.10.0",
  "graphql": "^16.8.1"
}
```

**Flutter:**
```yaml
dependencies:
  graphql_flutter: ^5.1.0
  ferry: ^0.15.0
  freezed_annotation: ^2.4.1
```

### Schema Generation Flow

```
Prisma Schema (schema.prisma)
    ↓
Pothos Schema Builder (@pothos/plugin-prisma)
    ↓
GraphQL Schema (SDL)
    ↓
Apollo Server (runtime)
    ↓
GraphQL Introspection
    ↓
Ferry Code Generation (Dart)
    ↓
Type-safe Flutter Client
```

### Query Example

**Prisma Schema:**
```prisma
model Product {
  id    String @id
  name  String
  price Float
}
```

**Pothos (auto-generates):**
```graphql
type Product {
  id: ID!
  name: String!
  price: Float!
}

type Query {
  product(id: ID!): Product
  products(priceUnder: Float): [Product!]!
}
```

**Flutter Usage:**
```dart
final products = await client.products.list(
  filter: ProductFilter(priceUnder: 100),
);
```

## Alternative Considered: Hybrid Approach

We considered offering both GraphQL and REST:

**Pros:**
- GraphQL for rich client apps (Flutter, React)
- REST for simple integrations, public APIs

**Cons:**
- Doubles maintenance burden
- Version drift risk
- Confusing for developers

**Decision:** Start with GraphQL only. Add REST in v2.0 if needed.

## Validation Metrics

To validate this decision, we'll track:

1. **Developer Satisfaction:** Survey users on API ergonomics
2. **Performance:** Network request count, data transfer size
3. **Adoption:** Usage stats from pub.dev
4. **Issues:** Bug reports related to GraphQL vs alternatives

## Risk Mitigation

### Risk: Steep Learning Curve

**Mitigation:**
- Comprehensive documentation
- Working examples
- Tutorial videos
- Active community support

### Risk: Query Complexity

**Mitigation:**
- Query depth limiting on backend
- Query complexity analysis
- Rate limiting per user

### Risk: Caching Complexity

**Mitigation:**
- v0.1.0: Network-only (no caching)
- v0.2.0: Drift-based offline cache
- v0.3.0: Normalized GraphQL cache

## Future Considerations

### GraphQL Enhancements

- **Persisted queries:** Reduce bandwidth, improve security
- **Federation:** Multiple GraphQL services
- **Relay compliance:** Cursor-based pagination
- **File uploads:** graphql-upload implementation

### REST Addition (v2.0+)

If user demand justifies it:
- Generate REST endpoints from Prisma schema
- Maintain GraphQL as primary
- Use same business logic layer

## Conclusion

GraphQL is the right choice for the Prisma Flutter Connector because:

1. ✅ **Best Prisma integration** (Pothos plugin)
2. ✅ **Mobile-optimized** (single endpoint, precise queries)
3. ✅ **Future-proof** (Prisma Pulse, real-time ready)
4. ✅ **Type-safe** (end-to-end)
5. ✅ **Industry momentum** (61%+ adoption, growing)

While REST is simpler and better-cached, GraphQL's advantages for a Prisma-backed mobile connector outweigh the trade-offs.

## References

- [Prisma Documentation](https://www.prisma.io/docs)
- [Pothos GraphQL](https://pothos-graphql.dev/)
- [GraphQL Flutter](https://pub.dev/packages/graphql_flutter)
- [Ferry](https://ferrygraphql.com/)
- [2024 State of GraphQL Survey](https://2024.stateofgraphql.com/)

---

**Last Updated:** 2025-11-01
**Decision Owner:** Prisma Flutter Connector Team
**Status:** Implemented in v0.1.0
