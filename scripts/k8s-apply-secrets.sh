#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  echo "Loading configuration from .env.local..."
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

# Get namespace from argument or environment
NAMESPACE="${1:-${K8S_NAMESPACE:-default}}"

echo "========================================"
echo "Creating Kubernetes Secrets"
echo "========================================"
echo "Namespace: $NAMESPACE"
echo ""

# Validate MongoDB credentials
if [ -z "$MONGODB_USERNAME" ] || [ -z "$MONGODB_PASSWORD" ]; then
  echo "❌ Error: MongoDB credentials not found in .env.local"
  echo ""
  echo "Please run: ./scripts/setup-local-config.sh"
  echo ""
  exit 1
fi

echo "Creating MongoDB secret..."
kubectl create secret generic mongodb-secret \
  --from-literal=mongodb-root-username="$MONGODB_USERNAME" \
  --from-literal=mongodb-root-password="$MONGODB_PASSWORD" \
  --from-literal=mongodb-database="${MONGODB_DATABASE:-honey-store}" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ MongoDB secret created/updated"
echo ""
echo "✅ All secrets configured successfully!"
