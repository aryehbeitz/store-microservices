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

# Check cluster connectivity
echo "Checking cluster connectivity..."
if ! kubectl cluster-info --request-timeout=5s &> /dev/null; then
  echo "❌ Error: Cannot connect to Kubernetes cluster"
  echo ""
  echo "Possible issues:"
  echo "  1. VPN not connected (if required by your organization)"
  echo "  2. Network connectivity issues"
  echo "  3. Cluster credentials expired"
  echo "  4. Wrong kubectl context selected"
  echo ""
  echo "Solutions:"
  echo "  • Enable VPN if required by your workplace"
  echo "  • Check: kubectl config current-context"
  echo "  • Switch context: kubectl config use-context <context-name>"
  echo "  • For GKE: gcloud container clusters get-credentials <cluster-name> --region <region>"
  echo ""
  exit 1
fi
echo "✓ Cluster connectivity verified"
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
