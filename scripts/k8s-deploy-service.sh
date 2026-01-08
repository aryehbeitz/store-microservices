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
  echo "Usage: $0 <service> [namespace]"
  echo "Services: backend, frontend, payment-service"
  echo "Example: $0 frontend meetup3"
  exit 1
fi

SERVICE="$1"
NAMESPACE="${2:-${K8S_NAMESPACE:-meetup3}}"

# Get or set Kubernetes context
K8S_CONTEXT="${K8S_CONTEXT}"
if [ -n "$K8S_CONTEXT" ]; then
  echo "Setting kubectl context to: $K8S_CONTEXT"
  kubectl config use-context "$K8S_CONTEXT" || {
    echo "Error: Failed to switch to context $K8S_CONTEXT"
    echo "Available contexts:"
    kubectl config get-contexts
    exit 1
  }
fi

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info &>/dev/null; then
  echo "Error: Cannot connect to Kubernetes cluster"
  echo "Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
  echo ""
  echo "Troubleshooting:"
  echo "1. Check your network connection"
  echo "2. Verify the cluster is running: gcloud container clusters list"
  echo "3. Update credentials: gcloud container clusters get-credentials <cluster-name> --region <region>"
  exit 1
fi

# Get GCP project ID
PROJECT_ID="${GCP_PROJECT_ID:-}"
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP_PROJECT_ID not set and unable to get from gcloud config"
    exit 1
  fi
fi

# Use Artifact Registry
REGISTRY_LOCATION="${ARTIFACT_REGISTRY_LOCATION:-us-east1}"
REGISTRY_REPO="${ARTIFACT_REGISTRY_REPO:-docker-repo}"
REGISTRY="us-east1-docker.pkg.dev/$PROJECT_ID/$REGISTRY_REPO"

case "$SERVICE" in
  backend)
    IMAGE_NAME="backend"
    DEPLOYMENT_NAME="backend"
    ;;
  frontend)
    IMAGE_NAME="frontend"
    DEPLOYMENT_NAME="frontend"
    ;;
  payment-service)
    IMAGE_NAME="payment-service"
    DEPLOYMENT_NAME="payment-service"
    ;;
  *)
    echo "Unknown service: $SERVICE"
    echo "Available services: backend, frontend, payment-service"
    exit 1
    ;;
esac

FULL_IMAGE="$REGISTRY/$IMAGE_NAME:latest"

echo "========================================"
echo "Deploying $SERVICE to Kubernetes"
echo "========================================"
echo "Context: $(kubectl config current-context 2>/dev/null || echo 'not set')"
echo "Namespace: $NAMESPACE"
echo "Image: $FULL_IMAGE"
echo "========================================"
echo ""

# Pre-flight: Validate local build
echo "Pre-flight: Validating local build..."
cd "$PROJECT_ROOT"
if ! pnpm exec nx build $SERVICE --configuration=production 2>&1 | tee /tmp/build-validation.log; then
  echo ""
  echo "❌ Error: Local build failed for $SERVICE"
  echo ""
  echo "Fix the errors above before deploying to Kubernetes."
  echo "This prevents wasting time on Docker builds that will fail."
  exit 1
fi
echo "✅ Local build validation passed"
echo ""

# Step 0: Bump version and commit
echo "Step 0: Bumping version for $SERVICE..."
./scripts/bump-and-commit-version.sh "$SERVICE"

# Step 1: Build and push the image
echo ""
echo "Step 1: Building and pushing $IMAGE_NAME..."
./scripts/k8s-build-service.sh "$SERVICE"

echo ""
echo "Step 2: Updating deployment to use new image..."

# Check if deployment exists
if ! kubectl get deployment $DEPLOYMENT_NAME -n "$NAMESPACE" &>/dev/null; then
  echo "Error: Deployment $DEPLOYMENT_NAME not found in namespace $NAMESPACE"
  echo "Available deployments:"
  kubectl get deployments -n "$NAMESPACE"
  exit 1
fi

# Update the image in the deployment, which will trigger a rollout
if ! kubectl set image deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" $IMAGE_NAME=$FULL_IMAGE; then
  echo "Error: Failed to update deployment image"
  exit 1
fi

# Ensure imagePullPolicy is Always (for GKE/Artifact Registry)
if ! kubectl patch deployment $DEPLOYMENT_NAME -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"'$IMAGE_NAME'","imagePullPolicy":"Always"}]}}}}'; then
  echo "Warning: Failed to set imagePullPolicy, but continuing..."
fi

echo ""
echo "Step 3: Waiting for rollout to complete..."
if ! kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" --timeout=300s; then
  echo "Warning: Rollout status check failed or timed out"
  echo "Checking deployment status manually..."
  kubectl get deployment $DEPLOYMENT_NAME -n "$NAMESPACE"
  kubectl get pods -l app=$DEPLOYMENT_NAME -n "$NAMESPACE"
  exit 1
fi

echo ""
echo "✅ $SERVICE deployed successfully!"
echo ""
echo "To view logs: kubectl logs -f -l app=$DEPLOYMENT_NAME -n $NAMESPACE"
echo "To check status: kubectl get pods -l app=$DEPLOYMENT_NAME -n $NAMESPACE"

