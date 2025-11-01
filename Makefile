.PHONY: help test-all test-unit test-integration test-postgres test-mysql test-mongodb test-sqlite test-supabase \
		setup-postgres setup-mysql setup-mongodb cleanup-all lint format analyze

# Default target
.DEFAULT_GOAL := help

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Testing

test-all: lint test-unit test-integration ## Run all tests (lint, unit, and integration)

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	@flutter test test/unit/ --coverage
	@echo "✓ Unit tests completed"

test-integration: test-postgres test-mysql test-mongodb test-sqlite ## Run all integration tests
	@echo "✓ All integration tests completed"

test-postgres: setup-postgres ## Run PostgreSQL integration tests
	@echo "Running PostgreSQL integration tests..."
	@cd test/integration/postgres && \
		prisma migrate deploy && \
		prisma generate
	@dart run prisma_flutter_connector:generate \
		--schema test/integration/postgres/schema.prisma \
		--output test/integration/postgres/generated/
	@flutter test test/integration/postgres/postgres_test.dart
	@echo "✓ PostgreSQL tests completed"

test-mysql: setup-mysql ## Run MySQL integration tests
	@echo "Running MySQL integration tests..."
	@cd test/integration/mysql && \
		prisma migrate deploy && \
		prisma generate
	@dart run prisma_flutter_connector:generate \
		--schema test/integration/mysql/schema.prisma \
		--output test/integration/mysql/generated/
	@flutter test test/integration/mysql/mysql_test.dart
	@echo "✓ MySQL tests completed"

test-mongodb: setup-mongodb ## Run MongoDB integration tests
	@echo "Running MongoDB integration tests..."
	@cd test/integration/mongodb && \
		prisma db push --accept-data-loss && \
		prisma generate
	@dart run prisma_flutter_connector:generate \
		--schema test/integration/mongodb/schema.prisma \
		--output test/integration/mongodb/generated/
	@flutter test test/integration/mongodb/mongodb_test.dart
	@echo "✓ MongoDB tests completed"

test-sqlite: ## Run SQLite integration tests (no setup needed)
	@echo "Running SQLite integration tests..."
	@cd test/integration/sqlite && \
		cp .env.example .env && \
		prisma migrate deploy && \
		prisma generate
	@dart run prisma_flutter_connector:generate \
		--schema test/integration/sqlite/schema.prisma \
		--output test/integration/sqlite/generated/
	@flutter test test/integration/sqlite/sqlite_test.dart
	@echo "✓ SQLite tests completed"

test-supabase: ## Run Supabase integration tests (requires .env with credentials)
	@if [ ! -f test/integration/supabase/.env ]; then \
		echo "Error: test/integration/supabase/.env not found"; \
		echo "Copy .env.example and fill in your Supabase credentials"; \
		exit 1; \
	fi
	@echo "Running Supabase integration tests..."
	@cd test/integration/supabase && \
		prisma migrate deploy && \
		prisma generate
	@dart run prisma_flutter_connector:generate \
		--schema test/integration/supabase/schema.prisma \
		--output test/integration/supabase/generated/
	@flutter test test/integration/supabase/supabase_test.dart
	@echo "✓ Supabase tests completed"

##@ Database Setup

setup-postgres: ## Start PostgreSQL container
	@echo "Starting PostgreSQL container..."
	@cd test/integration/postgres && \
		cp .env.example .env && \
		docker-compose up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@echo "✓ PostgreSQL is ready"

setup-mysql: ## Start MySQL container
	@echo "Starting MySQL container..."
	@cd test/integration/mysql && \
		cp .env.example .env && \
		docker-compose up -d
	@echo "Waiting for MySQL to be ready..."
	@sleep 10
	@echo "✓ MySQL is ready"

setup-mongodb: ## Start MongoDB container
	@echo "Starting MongoDB container..."
	@cd test/integration/mongodb && \
		cp .env.example .env && \
		docker-compose up -d
	@echo "Waiting for MongoDB to be ready..."
	@sleep 10
	@echo "✓ MongoDB is ready"

##@ Cleanup

cleanup-all: cleanup-postgres cleanup-mysql cleanup-mongodb cleanup-sqlite ## Stop all containers and clean up
	@echo "✓ All databases cleaned up"

cleanup-postgres: ## Stop PostgreSQL container
	@echo "Stopping PostgreSQL container..."
	@cd test/integration/postgres && docker-compose down -v || true

cleanup-mysql: ## Stop MySQL container
	@echo "Stopping MySQL container..."
	@cd test/integration/mysql && docker-compose down -v || true

cleanup-mongodb: ## Stop MongoDB container
	@echo "Stopping MongoDB container..."
	@cd test/integration/mongodb && docker-compose down -v || true

cleanup-sqlite: ## Clean up SQLite database
	@echo "Cleaning up SQLite database..."
	@rm -f test/integration/sqlite/test.db || true

##@ Code Quality

lint: format analyze ## Run formatter and analyzer

format: ## Format Dart code
	@echo "Formatting Dart code..."
	@dart format .
	@echo "✓ Code formatted"

analyze: ## Run Dart analyzer
	@echo "Running Dart analyzer..."
	@flutter analyze
	@echo "✓ Analysis complete"

##@ Development

deps: ## Get Flutter dependencies
	@echo "Getting Flutter dependencies..."
	@flutter pub get
	@echo "✓ Dependencies installed"

generate: deps ## Run code generation (build_runner)
	@echo "Running build_runner..."
	@flutter pub run build_runner build --delete-conflicting-outputs
	@echo "✓ Code generation complete"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@flutter clean
	@rm -rf test/integration/*/generated/
	@echo "✓ Clean complete"

##@ CI/CD

ci-local: lint test-unit test-integration ## Run full CI pipeline locally
	@echo "✓ CI pipeline completed successfully"
