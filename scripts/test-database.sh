#!/bin/bash

# Test a specific database integration
# Usage: ./scripts/test-database.sh <database>
# Example: ./scripts/test-database.sh postgres

set -e  # Exit on error

DATABASE=$1

if [ -z "$DATABASE" ]; then
  echo "Usage: $0 <database>"
  echo "Available databases: postgres, mysql, mongodb, sqlite, supabase"
  exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Testing $DATABASE integration...${NC}"

# Function to cleanup on exit
cleanup() {
  if [ "$DATABASE" != "sqlite" ] && [ "$DATABASE" != "supabase" ]; then
    echo -e "${YELLOW}Cleaning up $DATABASE container...${NC}"
    cd "test/integration/$DATABASE" && docker-compose down -v
  fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Move to database directory
cd "test/integration/$DATABASE"

# Step 1: Setup environment
echo -e "${GREEN}[1/5] Setting up environment...${NC}"
cp .env.example .env

# Step 2: Start database (if needed)
if [ "$DATABASE" = "postgres" ] || [ "$DATABASE" = "mysql" ] || [ "$DATABASE" = "mongodb" ]; then
  echo -e "${GREEN}[2/5] Starting $DATABASE container...${NC}"
  docker-compose up -d

  # Wait for database to be ready
  if [ "$DATABASE" = "mysql" ]; then
    sleep 15  # MySQL takes longer
  else
    sleep 5
  fi
else
  echo -e "${GREEN}[2/5] Skipping container start (not needed for $DATABASE)${NC}"
fi

# Step 3: Run migrations or schema push
echo -e "${GREEN}[3/5] Running migrations...${NC}"
if [ "$DATABASE" = "mongodb" ]; then
  npx prisma db push --accept-data-loss
elif [ "$DATABASE" = "supabase" ]; then
  if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found for Supabase${NC}"
    echo "Copy .env.example and fill in your Supabase credentials"
    exit 1
  fi
  npx prisma migrate deploy
else
  npx prisma migrate deploy
fi

# Step 4: Generate Prisma Client
echo -e "${GREEN}[4/5] Generating Prisma Client...${NC}"
npx prisma generate

# Return to root directory
cd ../../..

# Step 5: Generate Dart code
echo -e "${GREEN}[5/5] Generating Dart code...${NC}"
dart run prisma_flutter_connector:generate \
  --schema "test/integration/$DATABASE/schema.prisma" \
  --output "test/integration/$DATABASE/generated/"

# Run tests
echo -e "${GREEN}Running tests for $DATABASE...${NC}"
flutter test "test/integration/$DATABASE/${DATABASE}_test.dart"

echo -e "${GREEN}✓ $DATABASE tests completed successfully!${NC}"
