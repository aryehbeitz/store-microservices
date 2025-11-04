#!/bin/bash

set -e

# Handle kubectl context
if [ -z "$1" ]; then
  echo "No context specified. Available contexts:"
  echo ""
  kubectl config get-contexts
  echo ""
  echo "Usage: $0 <context-name> <namespace>"
  echo "Example: $0 gke_my-project_us-central1_cluster-name meetup3"
  exit 1
fi

# Handle namespace
if [ -z "$2" ]; then
  echo "No namespace specified."
  echo ""
  echo "Usage: $0 <context-name> <namespace>"
  echo "Example: $0 gke_my-project_us-central1_cluster-name meetup3"
  exit 1
fi

CONTEXT="$1"
NAMESPACE="$2"

echo "========================================"
echo "Building Docker images..."
echo "========================================"
./scripts/k8s-build.sh

echo ""
echo "========================================"
echo "Deploying to Kubernetes..."
echo "========================================"
./scripts/k8s-deploy.sh "$CONTEXT" "$NAMESPACE"

echo ""
echo "✅ Build and deployment complete!"
echo ""
echo "To check status: kubectl get pods -n $NAMESPACE"
echo "To view logs: kubectl logs -f <pod-name> -n $NAMESPACE"

