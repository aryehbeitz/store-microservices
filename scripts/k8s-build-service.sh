#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  echo "Loading configuration from .env.local..."
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

if [ -z "$1" ]; then
  echo "Usage: $0 <service>"
  echo "Services: backend, frontend, payment-service"
  exit 1
fi

SERVICE="$1"

# Get GCP project ID
PROJECT_ID="${GCP_PROJECT_ID:-}"
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP_PROJECT_ID not set and unable to get from gcloud config"
    exit 1
  fi
fi

case "$SERVICE" in
  backend)
    DOCKERFILE="apps/backend/Dockerfile"
    IMAGE_NAME="backend"
    ;;
  frontend)
    DOCKERFILE="apps/frontend/Dockerfile"
    IMAGE_NAME="frontend"
    ;;
  payment-service)
    DOCKERFILE="apps/payment-service/Dockerfile"
    IMAGE_NAME="payment-service"
    ;;
  *)
    echo "Unknown service: $SERVICE"
    echo "Available services: backend, frontend, payment-service"
    exit 1
    ;;
esac

# Use Artifact Registry
REGISTRY_LOCATION="${ARTIFACT_REGISTRY_LOCATION:-us-east1}"
REGISTRY_REPO="${ARTIFACT_REGISTRY_REPO:-docker-repo}"
REGISTRY="us-east1-docker.pkg.dev/$PROJECT_ID/$REGISTRY_REPO"

echo "Building and pushing $IMAGE_NAME to Artifact Registry..."
# Use --no-cache to ensure fresh build (can be disabled by setting DOCKER_NO_CACHE=false)
NO_CACHE_FLAG=""
if [ "${DOCKER_NO_CACHE:-true}" != "false" ]; then
  NO_CACHE_FLAG="--no-cache"
  echo "Building without cache to ensure latest code is included..."
fi
docker buildx build $NO_CACHE_FLAG --platform linux/amd64 -f "$DOCKERFILE" -t "$REGISTRY/$IMAGE_NAME:latest" --push .

echo "✅ $IMAGE_NAME built and pushed successfully!"

