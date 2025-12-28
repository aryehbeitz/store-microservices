#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  echo "Loading configuration from .env.local..."
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

# Check if Docker is running
echo "Checking Docker..."
if ! docker info &> /dev/null; then
  echo "❌ Error: Docker is not running"
  echo ""
  echo "Please start Docker Desktop and try again."
  echo ""
  echo "Solutions:"
  echo "  • macOS: Open Docker Desktop from Applications"
  echo "  • Linux: Run 'sudo systemctl start docker'"
  echo "  • Windows: Start Docker Desktop"
  echo ""
  echo "Verify Docker is running with: docker info"
  echo ""
  exit 1
fi
echo "✓ Docker is running"
echo ""

# Check if GCR registry should be used (default: true for GKE)
USE_GCR="${USE_GCR:-true}"
PROJECT_ID="${GCP_PROJECT_ID:-}"

if [ "$USE_GCR" = "true" ]; then
  if [ -z "$PROJECT_ID" ]; then
    # Try to get project from gcloud config
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$PROJECT_ID" ]; then
      echo "Error: GCP_PROJECT_ID not set and unable to get from gcloud config"
      echo "Usage: GCP_PROJECT_ID=your-project-id USE_GCR=true $0"
      echo "Or set USE_GCR=false for local/minikube/kind"
      exit 1
    fi
  fi

  # Use Artifact Registry (modern) instead of GCR (deprecated)
  REGISTRY_LOCATION="${ARTIFACT_REGISTRY_LOCATION:-us-east1}"
  REGISTRY_REPO="${ARTIFACT_REGISTRY_REPO:-docker-repo}"
  REGISTRY="us-east1-docker.pkg.dev/$PROJECT_ID/$REGISTRY_REPO"
  echo "Building Docker images for GKE (Artifact Registry: $REGISTRY)..."

  # Build and push images directly to Artifact Registry (explicitly for linux/amd64)
  echo "Building and pushing backend..."
  docker buildx build --platform linux/amd64 -f apps/backend/Dockerfile -t $REGISTRY/backend:latest --push .

  echo "Building and pushing frontend..."
  docker buildx build --platform linux/amd64 -f apps/frontend/Dockerfile -t $REGISTRY/frontend:latest --push .

  echo ""
  echo "✅ Docker images built and pushed to Artifact Registry with linux/amd64 platform!"
else
  echo "Building Docker images for local/minikube/kind..."

  # Detect Kubernetes cluster
  if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo "Using Minikube"
    eval $(minikube docker-env)
  elif command -v k3d &> /dev/null && k3d cluster list | grep -q "honey-store"; then
    echo "Using K3d"
    eval $(k3d kubeconfig get honey-store)
  fi

  # Build images
  echo "Building backend..."
  docker build -t honey-store/backend:latest -f apps/backend/Dockerfile .

  echo "Building frontend..."
  docker build -t honey-store/frontend:latest -f apps/frontend/Dockerfile .

  echo ""
  echo "✅ Docker images built successfully!"
  echo ""
  echo "If using kind, run: kind load docker-image honey-store/backend:latest honey-store/frontend:latest"
fi

