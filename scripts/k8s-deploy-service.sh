#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <service> [namespace]"
  echo "Services: backend, frontend, payment-service"
  echo "Example: $0 frontend meetup3"
  exit 1
fi

SERVICE="$1"
NAMESPACE="${2:-${K8S_NAMESPACE:-meetup3}}"

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
echo "Namespace: $NAMESPACE"
echo "Image: $FULL_IMAGE"
echo "========================================"
echo ""

# Step 1: Build and push the image
echo "Step 1: Building and pushing $IMAGE_NAME..."
./scripts/k8s-build-service.sh "$SERVICE"

echo ""
echo "Step 2: Updating deployment to use new image..."

# Update the image in the deployment, which will trigger a rollout
kubectl set image deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" $IMAGE_NAME=$FULL_IMAGE

# Ensure imagePullPolicy is Always (for GKE/Artifact Registry)
kubectl patch deployment $DEPLOYMENT_NAME -n "$NAMESPACE" -p '{"spec":{"template":{"spec":{"containers":[{"name":"'$IMAGE_NAME'","imagePullPolicy":"Always"}]}}}}'

echo ""
echo "Step 3: Waiting for rollout to complete..."
kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$NAMESPACE" --timeout=300s

echo ""
echo "✅ $SERVICE deployed successfully!"
echo ""
echo "To view logs: kubectl logs -f -l app=$DEPLOYMENT_NAME -n $NAMESPACE"
echo "To check status: kubectl get pods -l app=$DEPLOYMENT_NAME -n $NAMESPACE"

