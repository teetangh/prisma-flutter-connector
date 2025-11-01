#!/bin/bash

# Run all tests (unit + all integration tests)
# Usage: ./scripts/test-runner.sh [--skip-cleanup] [--only-unit] [--only-integration]

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Parse arguments
SKIP_CLEANUP=false
ONLY_UNIT=false
ONLY_INTEGRATION=false

for arg in "$@"; do
  case $arg in
    --skip-cleanup)
      SKIP_CLEANUP=true
      shift
      ;;
    --only-unit)
      ONLY_UNIT=true
      shift
      ;;
    --only-integration)
      ONLY_INTEGRATION=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --skip-cleanup       Don't stop Docker containers after tests"
      echo "  --only-unit          Run only unit tests"
      echo "  --only-integration   Run only integration tests"
      echo "  --help               Show this help message"
      exit 0
      ;;
  esac
done

# Track failures
FAILED_TESTS=()

# Function to cleanup on exit
cleanup() {
  if [ "$SKIP_CLEANUP" = false ]; then
    echo -e "${YELLOW}Cleaning up Docker containers...${NC}"
    cd test/integration/postgres && docker-compose down -v 2>/dev/null || true
    cd ../mysql && docker-compose down -v 2>/dev/null || true
    cd ../mongodb && docker-compose down -v 2>/dev/null || true
    cd ../../..
  fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Prisma Flutter Connector - Test Suite    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Get dependencies
echo -e "${GREEN}Installing dependencies...${NC}"
flutter pub get

# Run code quality checks
if [ "$ONLY_INTEGRATION" = false ]; then
  echo -e "\n${BLUE}═══ Code Quality ═══${NC}"

  echo -e "${GREEN}Checking code format...${NC}"
  if dart format --set-exit-if-changed . > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Code formatting check passed${NC}"
  else
    echo -e "${RED}✗ Code formatting check failed${NC}"
    FAILED_TESTS+=("formatting")
  fi

  echo -e "${GREEN}Running analyzer...${NC}"
  if flutter analyze > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Analyzer passed${NC}"
  else
    echo -e "${RED}✗ Analyzer failed${NC}"
    FAILED_TESTS+=("analyzer")
  fi
fi

# Run unit tests
if [ "$ONLY_INTEGRATION" = false ]; then
  echo -e "\n${BLUE}═══ Unit Tests ═══${NC}"
  if flutter test test/unit/ --coverage; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
  else
    echo -e "${RED}✗ Unit tests failed${NC}"
    FAILED_TESTS+=("unit")
  fi
fi

# Run integration tests
if [ "$ONLY_UNIT" = false ]; then
  echo -e "\n${BLUE}═══ Integration Tests ═══${NC}"

  # PostgreSQL
  echo -e "\n${YELLOW}Testing PostgreSQL...${NC}"
  if ./scripts/test-database.sh postgres; then
    echo -e "${GREEN}✓ PostgreSQL tests passed${NC}"
  else
    echo -e "${RED}✗ PostgreSQL tests failed${NC}"
    FAILED_TESTS+=("postgres")
  fi

  # MySQL
  echo -e "\n${YELLOW}Testing MySQL...${NC}"
  if ./scripts/test-database.sh mysql; then
    echo -e "${GREEN}✓ MySQL tests passed${NC}"
  else
    echo -e "${RED}✗ MySQL tests failed${NC}"
    FAILED_TESTS+=("mysql")
  fi

  # MongoDB
  echo -e "\n${YELLOW}Testing MongoDB...${NC}"
  if ./scripts/test-database.sh mongodb; then
    echo -e "${GREEN}✓ MongoDB tests passed${NC}"
  else
    echo -e "${RED}✗ MongoDB tests failed${NC}"
    FAILED_TESTS+=("mongodb")
  fi

  # SQLite
  echo -e "\n${YELLOW}Testing SQLite...${NC}"
  if ./scripts/test-database.sh sqlite; then
    echo -e "${GREEN}✓ SQLite tests passed${NC}"
  else
    echo -e "${RED}✗ SQLite tests failed${NC}"
    FAILED_TESTS+=("sqlite")
  fi

  # Supabase (optional - skip if no .env)
  if [ -f test/integration/supabase/.env ]; then
    echo -e "\n${YELLOW}Testing Supabase...${NC}"
    if ./scripts/test-database.sh supabase; then
      echo -e "${GREEN}✓ Supabase tests passed${NC}"
    else
      echo -e "${RED}✗ Supabase tests failed${NC}"
      FAILED_TESTS+=("supabase")
    fi
  else
    echo -e "\n${YELLOW}Skipping Supabase tests (no .env file)${NC}"
  fi
fi

# Print summary
echo -e "\n${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Summary                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ ${#FAILED_TESTS[@]} test(s) failed:${NC}"
  for test in "${FAILED_TESTS[@]}"; do
    echo -e "${RED}  - $test${NC}"
  done
  exit 1
fi
