#!/bin/bash

set -e

# Configuration
GCP_PROJECT_ID="${GCP_PROJECT_ID:-REDACTED_PROJECT}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_REDACTED_PROJECT_us-east1-b_docker-repo-sandbox}"
K8S_NAMESPACE="${K8S_NAMESPACE:-meetup3}"
USE_GCR="${USE_GCR:-true}"

echo "========================================"
echo "Deploying to Kubernetes"
echo "========================================"
echo "Project ID: $GCP_PROJECT_ID"
echo "Context: $K8S_CONTEXT"
echo "Namespace: $K8S_NAMESPACE"
echo "Use GCR: $USE_GCR"
echo "========================================"
echo ""

# Export environment variables
export GCP_PROJECT_ID
export USE_GCR

# Run the build and deploy script
./scripts/k8s-build-and-deploy.sh "$K8S_CONTEXT" "$K8S_NAMESPACE"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To check status: kubectl get pods -n $K8S_NAMESPACE"
echo "To view logs: kubectl logs -f <pod-name> -n $K8S_NAMESPACE"

