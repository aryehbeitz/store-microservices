#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <service>"
  echo "Services: frontend, backend, payment-service, all"
  exit 1
fi

SERVICE="$1"

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

bump_service_version() {
  local service=$1
  echo -e "${BLUE}Bumping version for $service...${NC}"

  # Bump the version
  node scripts/bump-version.js "$service"

  # Get the new version
  local packageJsonPath="apps/$service/package.json"
  local newVersion=$(node -p "require('./$packageJsonPath').version")

  # Stage the package.json change
  git add "$packageJsonPath"

  # Commit the version bump
  git commit -m "Bump $service version to $newVersion" || {
    echo -e "${YELLOW}No changes to commit for $service${NC}"
    return 0
  }

  echo -e "${GREEN}✓ $service version bumped to $newVersion and committed${NC}"
}

if [ "$SERVICE" = "all" ]; then
  echo -e "${BLUE}Bumping versions for all services...${NC}"
  bump_service_version "frontend"
  bump_service_version "backend"
  bump_service_version "payment-service"
else
  bump_service_version "$SERVICE"
fi

echo ""
echo -e "${GREEN}✅ Version bumping complete!${NC}"

