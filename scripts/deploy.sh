#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  echo "Loading configuration from .env.local..."
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

# Configuration
GCP_PROJECT_ID="${GCP_PROJECT_ID}"
K8S_CONTEXT="${K8S_CONTEXT}"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
USE_GCR="${USE_GCR:-true}"

# Validate required configuration
if [ -z "$GCP_PROJECT_ID" ] || [ -z "$K8S_CONTEXT" ]; then
  echo "❌ Error: Required configuration missing!"
  echo ""
  echo "Please run: ./scripts/setup-local-config.sh"
  echo ""
  echo "Or set environment variables manually:"
  echo "  export GCP_PROJECT_ID=your-project-id"
  echo "  export K8S_CONTEXT=your-k8s-context"
  echo "  export K8S_NAMESPACE=your-namespace"
  exit 1
fi

echo "========================================"
echo "Deploying to Kubernetes"
echo "========================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Context: $K8S_CONTEXT"
echo "Namespace: $K8S_NAMESPACE"
echo "Use GCR: $USE_GCR"
echo "========================================"
echo ""

# Step 0: Bump versions for all services and commit
echo "Step 0: Bumping versions for all services..."
./scripts/bump-and-commit-version.sh all

# Export environment variables
export GCP_PROJECT_ID
export USE_GCR

# Apply secrets before deploying
./scripts/k8s-apply-secrets.sh "$K8S_NAMESPACE"

# Run the build and deploy script
./scripts/k8s-build-and-deploy.sh "$K8S_CONTEXT" "$K8S_NAMESPACE"

echo ""
echo "✅ Deployment complete!"
echo ""

# Update service IPs in .env.local
./scripts/update-env-ips.sh "$K8S_NAMESPACE"

echo "To check status: kubectl get pods -n $K8S_NAMESPACE"
echo "To view logs: kubectl logs -f <pod-name> -n $K8S_NAMESPACE"

