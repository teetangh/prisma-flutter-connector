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

### Unit Tests

```bash
flutter test test/unit/
```

### Integration Tests

See the [test README](../test/README.md) for detailed instructions on running integration tests.

Quick start:

```bash
# PostgreSQL
cd test/integration/postgres
docker-compose up -d
prisma migrate dev
flutter test test/integration/postgres/postgres_test.dart

# MySQL
cd test/integration/mysql
docker-compose up -d
prisma migrate dev
flutter test test/integration/mysql/mysql_test.dart

# MongoDB
cd test/integration/mongodb
docker-compose up -d
prisma db push
flutter test test/integration/mongodb/mongodb_test.dart

# SQLite (no Docker needed)
cd test/integration/sqlite
prisma migrate dev
flutter test test/integration/sqlite/sqlite_test.dart
```

## GitHub Actions CI/CD

### Workflow Overview

The project uses GitHub Actions for continuous integration. The workflow runs:

1. **Unit Tests** - Fast tests without external dependencies
2. **Integration Tests** - Tests against real databases:
   - PostgreSQL (GitHub Actions service container)
   - MySQL (GitHub Actions service container)
   - MongoDB (Docker Compose)
   - SQLite (file-based, no service needed)
   - Supabase (requires GitHub secrets)
3. **Code Quality Checks** - Linting, formatting, analysis

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

### Workflow Files

- `.github/workflows/test.yml` - Main test workflow

### Manual Workflow Trigger

You can manually trigger the test workflow:

1. Go to the "Actions" tab in your GitHub repository
2. Select "Tests" from the workflows list
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
