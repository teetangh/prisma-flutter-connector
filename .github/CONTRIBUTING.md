# Contributing to Prisma Flutter Connector

Thank you for your interest in contributing to the Prisma Flutter Connector!

## Development Setup

### Prerequisites

1. **Dart SDK** (3.0.0 or higher)
2. **Flutter SDK** (optional, only for Flutter app examples)
3. **Node.js** (20.x or higher, for Prisma CLI migrations)
4. **Prisma CLI**: `npm install -g prisma`
5. **Docker** (for PostgreSQL integration tests)
6. **Git**

### Getting Started

1. **Fork and clone the repository**

```bash
git clone https://github.com/teetangh/prisma-flutter-connector.git
cd prisma-flutter-connector
```

2. **Install dependencies**

```bash
dart pub get
```

3. **Run analyzer**

```bash
dart analyze
```

## Running Tests

### Quick Start

Run the pure-Dart unit test suite directly:

```bash
# Run unit tests
dart test test/unit/

# Or via Makefile:
make test-unit
make test-postgres
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
./scripts/test-database.sh sqlite
```

### Manual Testing

See the [test README](../test/README.md) for detailed instructions on manual testing setup.

## GitHub Actions CI/CD

### Workflow Overview

The project uses **modular GitHub Actions workflows** for maintainability and clear diagnostics:

#### Workflow Files

- **`.github/workflows/unit-tests.yml`** - Pure-Dart unit tests
- **`.github/workflows/lint.yml`** - Code quality (formatting + analyzer)
- **`.github/workflows/postgres-integration.yml`** - PostgreSQL integration tests
- **`.github/workflows/sqlite-integration.yml`** - SQLite integration tests
- **`.github/workflows/supabase-integration.yml`** - Supabase integration tests
- **`.github/workflows/publish.yml`** - Release workflow to pub.dev

#### Execution Flow

1. **Lint** - Code formatting and analyzer checks
2. **Unit Tests** - Fast pure-Dart tests without external dependencies
3. **Integration Tests**:
   - PostgreSQL (GitHub Actions service container)
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

3. **Database URL** (Session pooler):
   - Navigate to Project Settings → Database
   - Scroll to "Connection string" section
   - Select "Transaction" mode
   - Copy the connection string (starts with `postgresql://postgres.your-project:...pooler.supabase.com:6543`)
   - Replace `[YOUR-PASSWORD]` with your database password

4. **Direct URL** (Direct connection):
   - Navigate to Project Settings → Database
   - Scroll to "Connection string" section
   - Select "Session" mode or "Direct connection"
   - Copy the connection string (starts with `postgresql://postgres:...@db.your-project.supabase.co:5432`)
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
     - **Value**: Your Supabase pooled connection string (Transaction mode)

   - **Name**: `SUPABASE_DIRECT_URL`
     - **Value**: Your Supabase direct connection string (Session mode)

5. Once all four secrets are added, the Supabase integration tests will run automatically

### Manual Workflow Triggers

You can manually trigger workflows from the GitHub Actions tab:

1. Go to the "Actions" tab in your GitHub repository
2. Select the workflow you want to run:
   - **Unit Tests** - Run only unit tests
   - **PostgreSQL Integration Tests** - Run only PostgreSQL tests
   - **SQLite Integration Tests** - Run only SQLite tests
   - **Supabase Integration Tests** - Run only Supabase tests
   - **Code Quality** - Run linting and analysis
3. Click "Run workflow"
4. Select the branch and click "Run workflow"

## Code Style

### Formatting

Use Dart's standard formatting:

```bash
dart format .
```

### Linting

Follow the rules defined in `analysis_options.yaml`:

```bash
dart analyze
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
│   │   ├── generator/       # AST-based code_builder generators (Cb*) & PrismaParser
│   │   └── runtime/         # Pure-Dart SQL compiler, QueryExecutor, adapters, errors
│   ├── prisma_flutter_connector.dart
│   ├── runtime.dart
│   └── runtime_server.dart
├── test/
│   ├── unit/               # Pure-Dart unit tests
│   └── integration/        # Integration tests (PostgreSQL, SQLite, Supabase)
├── example/                # Example applications
├── bin/
│   └── generate.dart       # CLI code generator
└── .github/
    └── workflows/          # CI/CD workflows
```

## Making Changes

### Adding a New Feature

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes
3. Add tests for new functionality
4. Run tests and analyzer: `dart test test/unit/ && dart analyze`
5. Format code: `dart format .`
6. Commit with descriptive message
7. Push and create a pull request

### Fixing a Bug

1. Create a bugfix branch: `git checkout -b fix/issue-123`
2. Write a failing test that reproduces the bug
3. Fix the bug
4. Ensure all tests pass (`dart test test/unit/`)
5. Commit and create a pull request

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
- Add unit tests for array operations
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

- **Issues**: [GitHub Issues](https://github.com/teetangh/prisma-flutter-connector/issues)
- **Discussions**: [GitHub Discussions](https://github.com/teetangh/prisma-flutter-connector/discussions)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.
