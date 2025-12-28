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

# Check if a service has changes since last commit with version bump
has_service_changes() {
  local service=$1
  local service_path="apps/$service"

  # Get the last commit that bumped this service's version
  local last_version_commit=$(git log --all --grep="Bump.*$service version" --format="%H" -n 1 2>/dev/null || echo "")

  if [ -z "$last_version_commit" ]; then
    # No previous version bump found, check if there are any commits for this service
    if git log --all -- "$service_path" &> /dev/null; then
      return 0  # Has changes
    else
      return 1  # No changes
    fi
  fi

  # Check if there are changes in the service directory since the last version bump
  local changes=$(git diff --name-only "$last_version_commit" HEAD -- "$service_path" 2>/dev/null | grep -v "package.json" || echo "")

  if [ -n "$changes" ]; then
    return 0  # Has changes
  else
    return 1  # No changes
  fi
}

bump_service_version() {
  local service=$1

  # Check if service has actual code changes
  if ! has_service_changes "$service"; then
    echo -e "${YELLOW}⊘ Skipping $service (no code changes since last version bump)${NC}"
    return 1
  fi

  echo -e "${BLUE}Bumping version for $service...${NC}"

  # Bump the version
  node scripts/bump-version.js "$service"

  # Get the new version
  local packageJsonPath="apps/$service/package.json"
  local newVersion=$(node -p "require('./$packageJsonPath').version")

  # Stage the package.json change
  git add "$packageJsonPath"

  echo -e "${GREEN}✓ $service version bumped to $newVersion${NC}"
  echo "$service:$newVersion"
  return 0
}

if [ "$SERVICE" = "all" ]; then
  echo -e "${BLUE}Checking for services with code changes...${NC}"

  bumped_services=()

  for svc in "frontend" "backend" "payment-service"; do
    if result=$(bump_service_version "$svc" 2>&1 | tail -1) && [[ "$result" == *":"* ]]; then
      bumped_services+=("$result")
    fi
  done

  # Create a single commit for all version bumps
  if [ ${#bumped_services[@]} -gt 0 ]; then
    commit_msg="Bump versions:"
    for item in "${bumped_services[@]}"; do
      commit_msg="$commit_msg
  - $item"
    done

    git commit -m "$commit_msg" || {
      echo -e "${YELLOW}No changes to commit${NC}"
      exit 0
    }

    echo ""
    echo -e "${GREEN}✅ Version bumping complete!${NC}"
    echo -e "${GREEN}Services updated: ${bumped_services[*]}${NC}"
  else
    echo ""
    echo -e "${YELLOW}No services needed version bumps (no code changes detected)${NC}"
  fi
else
  if bump_service_version "$SERVICE"; then
    # Get the new version for single service commit
    local packageJsonPath="apps/$SERVICE/package.json"
    local newVersion=$(node -p "require('./$packageJsonPath').version")

    git commit -m "Bump $SERVICE version to $newVersion" || {
      echo -e "${YELLOW}No changes to commit for $SERVICE${NC}"
      exit 0
    }

    echo ""
    echo -e "${GREEN}✅ Version bumping complete!${NC}"
  fi
fi

