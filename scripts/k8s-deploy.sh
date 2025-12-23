#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  echo "Loading configuration from .env.local..."
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

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

echo "Switching to context: $CONTEXT"
kubectl config use-context "$CONTEXT"

# Verify context switch
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "$CONTEXT" ]; then
  echo "Error: Failed to switch to context $CONTEXT"
  echo "Current context is: $CURRENT_CONTEXT"
  exit 1
fi

echo "Deploying to Kubernetes in context: $CURRENT_CONTEXT"
echo "Namespace: $NAMESPACE"
echo ""

# Detect if GKE and set up registry image paths
USE_GCR="false"
REGISTRY_PREFIX=""

if [[ "$CONTEXT" == gke_* ]]; then
  USE_GCR="true"
  PROJECT_ID="${GCP_PROJECT_ID:-}"
  if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
  fi
  if [ -z "$PROJECT_ID" ]; then
    echo "Warning: GKE context detected but GCP_PROJECT_ID not set."
    echo "Images will use local names. Set GCP_PROJECT_ID to use registry images."
  else
    # Use Artifact Registry (modern) instead of GCR (deprecated)
    REGISTRY_LOCATION="${ARTIFACT_REGISTRY_LOCATION:-us-east1}"
    REGISTRY_REPO="${ARTIFACT_REGISTRY_REPO:-docker-repo}"
    REGISTRY_PREFIX="us-east1-docker.pkg.dev/$PROJECT_ID/$REGISTRY_REPO/"
    echo "Using Artifact Registry: $REGISTRY_PREFIX"
  fi
fi

# Create namespace
echo "Creating namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE" || true

# Deploy MongoDB
echo "Deploying MongoDB..."
SED_CMD="s/namespace: payment-system/namespace: $NAMESPACE/g"
sed "$SED_CMD" k8s/mongodb-deployment.yaml | kubectl apply -f -

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb -n "$NAMESPACE" --timeout=300s || echo "MongoDB may still be starting..."

# Deploy Backend
echo "Deploying Backend..."
SED_CMD="s/namespace: payment-system/namespace: $NAMESPACE/g"
if [ "$USE_GCR" = "true" ] && [ -n "$REGISTRY_PREFIX" ]; then
  SED_CMD="$SED_CMD; s|image: honey-store/backend:latest|image: ${REGISTRY_PREFIX}backend:latest|g"
  SED_CMD="$SED_CMD; s|imagePullPolicy: Never|imagePullPolicy: Always|g"
fi
sed "$SED_CMD" k8s/backend-deployment.yaml | kubectl apply -f -

# Deploy Frontend
echo "Deploying Frontend..."
SED_CMD="s/namespace: payment-system/namespace: $NAMESPACE/g"
if [ "$USE_GCR" = "true" ] && [ -n "$REGISTRY_PREFIX" ]; then
  SED_CMD="$SED_CMD; s|image: honey-store/frontend:latest|image: ${REGISTRY_PREFIX}frontend:latest|g"
  SED_CMD="$SED_CMD; s|imagePullPolicy: Never|imagePullPolicy: Always|g"
fi
sed "$SED_CMD" k8s/frontend-deployment.yaml | kubectl apply -f -

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available deployment/backend -n "$NAMESPACE" --timeout=300s || echo "Backend may still be starting..."
kubectl wait --for=condition=available deployment/frontend -n "$NAMESPACE" --timeout=300s || echo "Frontend may still be starting..."

echo ""
echo "Available services:"
echo "  - Backend: ClusterIP (check with: kubectl get svc backend -n $NAMESPACE)"
echo "  - Frontend: ClusterIP (check with: kubectl get svc frontend -n $NAMESPACE)"
echo "  - MongoDB: ClusterIP (check with: kubectl get svc mongodb -n $NAMESPACE)"
echo ""
echo "To check status: kubectl get pods -n $NAMESPACE"
echo "To view logs: kubectl logs -f <pod-name> -n $NAMESPACE"
echo "To get service URLs: kubectl get svc -n $NAMESPACE"

