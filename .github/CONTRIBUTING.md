# Contributing to Prisma Flutter Connector

Thank you for your interest in contributing to the Prisma Flutter Connector!

## Development Setup

### Prerequisites

1. **Flutter SDK** (3.24.0 or higher)
2. **Dart SDK** (included with Flutter)
3. **Node.js** (20.x or higher)
4. **Prisma CLI**: `npm install -g prisma`
5. **Docker** (for integration tests)
6. **Git**

### Getting Started

1. **Fork and clone the repository**

```bash
git clone https://github.com/YOUR_USERNAME/prisma-flutter-connector.git
cd prisma-flutter-connector
```

2. **Initialize submodules**

```bash
git submodule update --init --recursive
```

3. **Install dependencies**

```bash
flutter pub get
```

4. **Run analyzer**

```bash
flutter analyze
```

## Running Tests

### Quick Start

The easiest way to run tests is using the **Makefile**:

```bash
# Run all tests (recommended before submitting PR)
make test-all

# Run unit tests only
make test-unit

# Run all integration tests
make test-integration

# Run specific database test
make test-postgres
make test-mysql
make test-mongodb
make test-sqlite
```

### Using Test Scripts

Alternatively, use the test runner scripts:

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

### Manual Testing

See the [test README](../test/README.md) for detailed instructions on manual testing setup.

## GitHub Actions CI/CD

### Workflow Overview

The project uses **modular GitHub Actions workflows** for better maintainability and easier debugging. Each workflow can be triggered independently or as part of the complete CI pipeline.

#### Workflow Files

- **`.github/workflows/ci.yml`** - Master workflow that orchestrates all tests
- **`.github/workflows/unit-tests.yml`** - Unit tests
- **`.github/workflows/lint.yml`** - Code quality (formatting + analyzer)
- **`.github/workflows/postgres-integration.yml`** - PostgreSQL integration tests
- **`.github/workflows/mysql-integration.yml`** - MySQL integration tests
- **`.github/workflows/mongodb-integration.yml`** - MongoDB integration tests
- **`.github/workflows/sqlite-integration.yml`** - SQLite integration tests
- **`.github/workflows/supabase-integration.yml`** - Supabase integration tests

#### Execution Flow

1. **Lint** - Code formatting and analyzer checks
2. **Unit Tests** - Fast tests without external dependencies
3. **Integration Tests** (run in parallel after unit tests pass):
   - PostgreSQL (GitHub Actions service container)
   - MySQL (GitHub Actions service container)
   - MongoDB (Docker Compose)
   - SQLite (file-based, no service needed)
   - Supabase (requires GitHub secrets, conditional)

### Setting Up GitHub Secrets for Supabase Tests

Supabase integration tests require credentials stored as GitHub repository secrets.

#### Creating a Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Create a new project
3. Wait for the project to finish provisioning

#### Getting Supabase Credentials

1. **Project URL**:
   - Navigate to Project Settings → API
   - Copy the "Project URL" (e.g., `https://xxxxx.supabase.co`)

2. **Anon Key**:
   - Navigate to Project Settings → API
   - Copy the "anon" key under "Project API keys"

3. **Database URL**:
   - Navigate to Project Settings → Database
   - Scroll to "Connection string" section
   - Select "URI" mode
   - Copy the connection string
   - Replace `[YOUR-PASSWORD]` with your database password

#### Adding Secrets to GitHub

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Add the following secrets:

   - **Name**: `SUPABASE_URL`
     - **Value**: Your Supabase project URL

   - **Name**: `SUPABASE_ANON_KEY`
     - **Value**: Your Supabase anon key

   - **Name**: `SUPABASE_DATABASE_URL`
     - **Value**: Your Supabase database connection string

5. Once all three secrets are added, the Supabase integration tests will run automatically

### Manual Workflow Triggers

You can manually trigger workflows from the GitHub Actions tab:

1. Go to the "Actions" tab in your GitHub repository
2. Select the workflow you want to run:
   - **CI - All Tests** - Run the complete test suite
   - **Unit Tests** - Run only unit tests
   - **PostgreSQL Integration Tests** - Run only PostgreSQL tests
   - **MySQL Integration Tests** - Run only MySQL tests
   - **MongoDB Integration Tests** - Run only MongoDB tests
   - **SQLite Integration Tests** - Run only SQLite tests
   - **Supabase Integration Tests** - Run only Supabase tests
   - **Code Quality** - Run linting and analysis
3. Click "Run workflow"
4. Select the branch and click "Run workflow"

**Tip**: Run specific database workflows to debug integration test failures faster!

## Code Style

### Formatting

Use Dart's standard formatting:

```bash
dart format .
```

### Linting

Follow the rules defined in `analysis_options.yaml`:

```bash
flutter analyze
```

### Generated Files

Exclude generated files from version control:
- `**/*.g.dart` (json_serializable)
- `**/*.freezed.dart` (Freezed)
- `**/generated/**` (Prisma-generated code)

## Project Structure

```
prisma-flutter-connector/
├── lib/
│   ├── src/
│   │   ├── client/          # Generic Prisma client
│   │   ├── generator/       # Code generation
│   │   ├── config/          # Configuration
│   │   ├── exceptions/      # Custom exceptions
│   │   └── utils/           # Utilities
│   └── prisma_flutter_connector.dart
├── test/
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── e2e/                # End-to-end tests
├── examples/
│   └── ecommerce/          # Example application
├── bin/
│   └── generate.dart       # CLI code generator
├── prisma-submodule/       # Prisma as Git submodule
└── .github/
    └── workflows/          # CI/CD workflows
```

## Making Changes

### Adding a New Feature

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Add tests for new functionality
4. Run tests and analyzer: `flutter test && flutter analyze`
5. Format code: `dart format .`
6. Commit with descriptive message
7. Push and create a pull request

### Fixing a Bug

1. Create a bugfix branch: `git checkout -b fix/issue-123`
2. Write a failing test that reproduces the bug
3. Fix the bug
4. Ensure all tests pass
5. Commit and create a pull request

### Adding Support for a New Database

1. Create directory: `test/integration/newdb/`
2. Add `schema.prisma` with test models
3. Add `docker-compose.yml` (if applicable)
4. Add `.env.example` with connection string format
5. Create `newdb_test.dart` with integration tests
6. Update `.github/workflows/test.yml` to include new database
7. Update documentation

## Commit Message Guidelines

Follow conventional commits:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Adding or updating tests
- `refactor:` Code refactoring
- `chore:` Maintenance tasks

Example:
```
feat: add support for PostgreSQL array types

- Parse array types in Prisma schema
- Generate List<T> types in Dart models
- Add integration tests for array operations
```

## Pull Request Process

1. **Update documentation** if needed
2. **Add tests** for new features
3. **Ensure all CI checks pass**
4. **Request review** from maintainers
5. **Address feedback** promptly
6. **Squash commits** if requested

## Code Review Guidelines

Reviewers will check:

- Code quality and style
- Test coverage
- Documentation updates
- Breaking changes (require major version bump)
- Performance implications

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/anthropics/prisma-flutter-connector/issues)
- **Discussions**: [GitHub Discussions](https://github.com/anthropics/prisma-flutter-connector/discussions)
- **Discord**: (link to community Discord if available)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
