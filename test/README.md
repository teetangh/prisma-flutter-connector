# Prisma Flutter Connector - Test Suite

This directory contains the complete test suite for the Prisma Flutter Connector, organized into unit tests, integration tests, and end-to-end tests.

## Directory Structure

```
test/
├── unit/                    # Unit tests for individual components
├── integration/             # Integration tests with real databases
│   ├── postgres/           # PostgreSQL integration tests
│   ├── mysql/              # MySQL integration tests
│   ├── mongodb/            # MongoDB integration tests
│   ├── sqlite/             # SQLite integration tests
│   └── supabase/           # Supabase (PostgreSQL) integration tests
└── e2e/                    # End-to-end tests
```

## Integration Tests

Integration tests verify that the connector works correctly with actual database backends. Each database has its own test suite with a dedicated Prisma schema.

### Prerequisites

1. **Docker** (for PostgreSQL, MySQL, MongoDB)
2. **Node.js** (for Prisma CLI)
3. **Prisma CLI**: `npm install -g prisma`
4. **Backend GraphQL server** for each database

### Running Integration Tests

#### PostgreSQL

```bash
# 1. Start PostgreSQL
cd test/integration/postgres
docker-compose up -d

# 2. Run migrations
prisma migrate dev

# 3. Start backend server (with schema.prisma)
# See backend setup instructions

# 4. Run tests
flutter test test/integration/postgres/postgres_test.dart
```

#### MySQL

```bash
# 1. Start MySQL
cd test/integration/mysql
docker-compose up -d

# 2. Run migrations
prisma migrate dev

# 3. Start backend server
# See backend setup instructions

# 4. Run tests
flutter test test/integration/mysql/mysql_test.dart
```

#### MongoDB

```bash
# 1. Start MongoDB
cd test/integration/mongodb
docker-compose up -d

# 2. Push schema (MongoDB doesn't use migrations)
prisma db push

# 3. Start backend server
# See backend setup instructions

# 4. Run tests
flutter test test/integration/mongodb/mongodb_test.dart
```

#### SQLite

```bash
# 1. Run migrations (no Docker needed - file-based)
cd test/integration/sqlite
prisma migrate dev

# 2. Start backend server
# See backend setup instructions

# 3. Run tests
flutter test test/integration/sqlite/sqlite_test.dart
```

#### Supabase

```bash
# 1. Create a Supabase project at https://supabase.com

# 2. Copy .env.example to .env and fill in credentials
cd test/integration/supabase
cp .env.example .env
# Edit .env with your Supabase credentials

# 3. Run migrations
prisma migrate dev

# 4. Start backend server
# See backend setup instructions

# 5. Run tests
flutter test test/integration/supabase/supabase_test.dart
```

### Environment Variables

Each integration test requires environment variables defined in `.env` files:

- **PostgreSQL**: `POSTGRES_DATABASE_URL`, `GRAPHQL_ENDPOINT`
- **MySQL**: `MYSQL_DATABASE_URL`, `GRAPHQL_ENDPOINT`
- **MongoDB**: `MONGODB_DATABASE_URL`, `GRAPHQL_ENDPOINT`
- **SQLite**: `SQLITE_DATABASE_URL`, `GRAPHQL_ENDPOINT`
- **Supabase**: `SUPABASE_DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GRAPHQL_ENDPOINT`

Use `.env.example` files as templates.

## Backend Server Setup

Each integration test requires a running GraphQL backend server. Here's how to set one up:

### Option 1: Using Pothos GraphQL (Recommended)

```bash
# In each test directory
cd test/integration/postgres  # or mysql, mongodb, etc.

# Initialize Node.js project
npm init -y

# Install dependencies
npm install @pothos/core @pothos/plugin-prisma graphql graphql-yoga @prisma/client

# Generate Prisma client
prisma generate

# Create server.ts with Pothos setup
# See examples in test/integration/postgres/backend/

# Start server
npm run dev
```

### Option 2: Using Prisma Examples

Check the [Prisma Examples Repository](https://github.com/prisma/prisma-examples) for ready-to-use GraphQL server setups.

## Code Generation

Before running tests, generate the Dart models and API clients from the Prisma schema:

```bash
cd test/integration/postgres  # or any test directory

# Generate code
dart run prisma_flutter_connector:generate \
  --schema schema.prisma \
  --output generated/
```

This creates:
- Freezed models
- Type-safe API clients
- Filter and input types
- PrismaClient instance

## GitHub Actions

Integration tests run automatically on GitHub Actions using a matrix strategy:

- **PostgreSQL** tests run on every push
- **MySQL** tests run on every push
- **MongoDB** tests run on every push
- **SQLite** tests run on every push
- **Supabase** tests run only when secrets are configured

See `.github/workflows/test.yml` for the complete CI/CD configuration.

## Test Features by Database

### PostgreSQL (`postgres_test.dart`)
- UUID ID handling
- User/Post relationships
- Standard SQL operations
- Connection pooling

### MySQL (`mysql_test.dart`)
- Auto-increment IDs
- Decimal type handling
- Category/Product relationships
- Price range queries

### MongoDB (`mongodb_test.dart`)
- ObjectId handling
- Array fields (tags)
- JSON metadata storage
- Embedded documents
- Blog/Author relationships

### SQLite (`sqlite_test.dart`)
- File-based database
- Many-to-many relationships (Task-Tag)
- Boolean fields
- Priority sorting
- Lightweight operations

### Supabase (`supabase_test.dart`)
- Supabase Auth integration
- Real-time subscriptions
- Row-level security (RLS)
- Profile/Post relationships
- Cloud PostgreSQL features

## Troubleshooting

### Docker containers won't start
```bash
# Check if ports are already in use
lsof -i :5432  # PostgreSQL
lsof -i :3306  # MySQL
lsof -i :27017 # MongoDB

# Stop existing containers
docker-compose down
```

### Migrations fail
```bash
# Reset database
prisma migrate reset

# Or push schema directly (for development)
prisma db push
```

### Backend server errors
```bash
# Regenerate Prisma client
prisma generate

# Check database connection
prisma studio
```

### Test failures
```bash
# Run with verbose output
flutter test --verbose test/integration/postgres/postgres_test.dart

# Run specific test
flutter test test/integration/postgres/postgres_test.dart --name "should create a user"
```

## Contributing

When adding new integration tests:

1. Create a new directory under `test/integration/`
2. Add `schema.prisma` with test models
3. Add `docker-compose.yml` (if applicable)
4. Add `.env.example` with required variables
5. Create `*_test.dart` with test cases
6. Update this README
7. Update GitHub Actions workflow

## Resources

- [Prisma Documentation](https://www.prisma.io/docs)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [GraphQL with Prisma](https://www.prisma.io/docs/concepts/overview/prisma-in-your-stack/graphql)
- [Supabase Documentation](https://supabase.com/docs)
