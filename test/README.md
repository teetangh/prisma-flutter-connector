# Prisma Flutter Connector - Test Suite

This directory contains the complete test suite for the Prisma Flutter Connector, organized into unit tests, integration tests, and end-to-end tests.

## Quick Start

### Run All Tests (Recommended)

```bash
# Using Makefile (easiest)
make test-all

# Or using the test runner script
./scripts/test-runner.sh
```

### Run Specific Tests

```bash
# Unit tests only
make test-unit

# Specific database integration test
make test-postgres
make test-mysql
make test-mongodb
make test-sqlite

# All integration tests
make test-integration
```

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

## Prerequisites

1. **Docker** (for PostgreSQL, MySQL, MongoDB)
2. **Node.js** (20.x or higher)
3. **Prisma CLI**: `npm install -g prisma`
4. **Flutter SDK** (3.24.0 or higher)
5. **Make** (usually pre-installed on macOS/Linux)

## Makefile Commands

The project includes a comprehensive Makefile for easy test execution:

### Testing Commands

```bash
make test-all           # Run all tests (lint + unit + integration)
make test-unit          # Run unit tests only
make test-integration   # Run all integration tests

# Individual database tests
make test-postgres      # PostgreSQL integration tests
make test-mysql         # MySQL integration tests
make test-mongodb       # MongoDB integration tests
make test-sqlite        # SQLite integration tests
make test-supabase      # Supabase integration tests (requires .env)
```

### Database Setup Commands

```bash
make setup-postgres     # Start PostgreSQL container
make setup-mysql        # Start MySQL container
make setup-mongodb      # Start MongoDB container
```

### Cleanup Commands

```bash
make cleanup-all        # Stop all containers
make cleanup-postgres   # Stop PostgreSQL container
make cleanup-mysql      # Stop MySQL container
make cleanup-mongodb    # Stop MongoDB container
make cleanup-sqlite     # Remove SQLite database file
```

### Code Quality Commands

```bash
make lint              # Run formatter + analyzer
make format            # Format Dart code
make analyze           # Run Dart analyzer
```

### Development Commands

```bash
make deps              # Get Flutter dependencies
make generate          # Run build_runner code generation
make clean             # Clean build artifacts
make help              # Show all available commands
```

## Test Runner Scripts

### Full Test Suite

Run the complete test suite with the test runner script:

```bash
# Run all tests
./scripts/test-runner.sh

# Run only unit tests
./scripts/test-runner.sh --only-unit

# Run only integration tests
./scripts/test-runner.sh --only-integration

# Skip cleanup (keep containers running)
./scripts/test-runner.sh --skip-cleanup
```

### Individual Database Tests

Test a specific database using the database test script:

```bash
# PostgreSQL
./scripts/test-database.sh postgres

# MySQL
./scripts/test-database.sh mysql

# MongoDB
./scripts/test-database.sh mongodb

# SQLite
./scripts/test-database.sh sqlite

# Supabase (requires .env)
./scripts/test-database.sh supabase
```

## Manual Testing (Step-by-Step)

If you prefer to run tests manually, follow these instructions for each database:

### Prerequisites

1. **Docker** (for PostgreSQL, MySQL, MongoDB)
2. **Node.js** (for Prisma CLI)
3. **Prisma CLI**: `npm install -g prisma`

### Running Integration Tests Manually

#### PostgreSQL

```bash
# 1. Start PostgreSQL
cd test/integration/postgres
docker-compose up -d

# 2. Setup environment
cp .env.example .env

# 3. Run migrations
prisma migrate deploy

# 4. Generate Prisma Client
prisma generate

# 5. Generate Dart code
cd ../../..
dart run prisma_flutter_connector:generate \
  --schema test/integration/postgres/schema.prisma \
  --output test/integration/postgres/generated/

# 6. Run tests
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

## GitHub Actions CI/CD

The project uses modular GitHub Actions workflows for comprehensive testing. Each database has its own workflow file for better modularity and easier debugging.

### Workflow Files

- **`.github/workflows/ci.yml`** - Master workflow that runs all tests
- **`.github/workflows/unit-tests.yml`** - Unit tests
- **`.github/workflows/lint.yml`** - Code quality (formatting + analyzer)
- **`.github/workflows/postgres-integration.yml`** - PostgreSQL tests
- **`.github/workflows/mysql-integration.yml`** - MySQL tests
- **`.github/workflows/mongodb-integration.yml`** - MongoDB tests
- **`.github/workflows/sqlite-integration.yml`** - SQLite tests
- **`.github/workflows/supabase-integration.yml`** - Supabase tests (conditional)

### Triggers

All workflows are triggered on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch

You can also run individual workflows manually from the GitHub Actions tab.

### Test Execution Flow

1. **Lint** - Code quality checks (formatting, analyzer)
2. **Unit Tests** - Fast tests with no external dependencies
3. **Integration Tests** - Run in parallel after lint + unit tests pass:
   - PostgreSQL (GitHub Actions service)
   - MySQL (GitHub Actions service)
   - MongoDB (Docker Compose)
   - SQLite (file-based)
   - Supabase (requires secrets, optional)

### Setting Up Supabase Tests

Supabase integration tests require GitHub repository secrets:

1. Go to repository Settings → Secrets and variables → Actions
2. Add these secrets:
   - `SUPABASE_URL` - Your Supabase project URL
   - `SUPABASE_ANON_KEY` - Your Supabase anon key
   - `SUPABASE_DATABASE_URL` - Your pooled connection string (Transaction mode)
   - `SUPABASE_DIRECT_URL` - Your direct connection string (Session mode)

**Why two URLs?**
- **DATABASE_URL** (pooled): Used for queries with connection pooling
- **DIRECT_URL** (direct): Required for Prisma migrations

See [.github/CONTRIBUTING.md](../.github/CONTRIBUTING.md) for detailed setup instructions.

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
