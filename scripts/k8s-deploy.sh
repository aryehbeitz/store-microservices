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
  echo "Example: $0 gke_my-project_us-central1_cluster-name honey-store"
  exit 1
fi

# Handle namespace
if [ -z "$2" ]; then
  echo "No namespace specified."
  echo ""
  echo "Usage: $0 <context-name> <namespace>"
  echo "Example: $0 gke_my-project_us-central1_cluster-name honey-store"
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
USE_GCR="${USE_GCR:-false}"
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
    REGISTRY_PREFIX="${REGISTRY_LOCATION}-docker.pkg.dev/$PROJECT_ID/$REGISTRY_REPO/"
    echo "Using Artifact Registry: $REGISTRY_PREFIX"
  fi
fi

# Helper: sed command to replace namespace placeholder
namespace_sed="s/NAMESPACE_PLACEHOLDER/$NAMESPACE/g"

# Helper: build full sed command for a manifest with optional image replacement
build_sed_cmd() {
  local image_name="$1"
  local sed_cmd="$namespace_sed"
  if [ "$USE_GCR" = "true" ] && [ -n "$REGISTRY_PREFIX" ]; then
    sed_cmd="$sed_cmd; s|image: honey-store/${image_name}:latest|image: ${REGISTRY_PREFIX}${image_name}:latest|g"
    sed_cmd="$sed_cmd; s|imagePullPolicy: IfNotPresent|imagePullPolicy: Always|g"
  fi
  echo "$sed_cmd"
}

# Build ALLOWED_ORIGINS for backend
ALLOWED_ORIGINS="http://localhost:4200"
if [ "${ENABLE_INGRESS}" = "true" ]; then
  ALLOWED_ORIGINS="$ALLOWED_ORIGINS,https://${FRONTEND_HOST},https://${DASHBOARD_HOST}"
fi

# Create namespace
echo "Creating namespace: $NAMESPACE"
sed "$namespace_sed" k8s/namespace.yaml | kubectl apply -f -

# Apply secrets from .env.local
echo "Applying secrets..."
"$SCRIPT_DIR/k8s-apply-secrets.sh" "$NAMESPACE"

# Create PostgreSQL secret
echo "Creating PostgreSQL secret..."
kubectl create secret generic postgresql-secret \
  --from-literal=postgresql-user="${POSTGRESQL_USERNAME:-temporal}" \
  --from-literal=postgresql-password="${POSTGRESQL_PASSWORD:-temporal}" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL
echo "Deploying PostgreSQL..."
sed "$namespace_sed" k8s/postgresql-statefulset.yaml | kubectl apply -f -

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgresql -n "$NAMESPACE" --timeout=300s || echo "PostgreSQL may still be starting..."

# Deploy Temporal
echo "Deploying Temporal..."
sed "$namespace_sed" k8s/temporal-deployment.yaml | kubectl apply -f -

echo "Waiting for Temporal to be ready..."
kubectl wait --for=condition=ready pod -l app=temporal -n "$NAMESPACE" --timeout=300s || echo "Temporal may still be starting..."

# Deploy MongoDB
echo "Deploying MongoDB..."
sed "$namespace_sed" k8s/mongodb-deployment.yaml | kubectl apply -f -

echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb -n "$NAMESPACE" --timeout=300s || echo "MongoDB may still be starting..."

# Deploy Backend
echo "Deploying Backend..."
SED_CMD=$(build_sed_cmd "backend")
SED_CMD="$SED_CMD; s|value: \"ALLOWED_ORIGINS_PLACEHOLDER\"|value: \"$ALLOWED_ORIGINS\"|g"
sed "$SED_CMD" k8s/backend-deployment.yaml | kubectl apply -f -

# Deploy Payment API
echo "Deploying Payment API..."
SED_CMD=$(build_sed_cmd "payment-service")
sed "$SED_CMD" k8s/payment-service-deployment.yaml | kubectl apply -f -

# Deploy Payment Worker
echo "Deploying Payment Worker..."
SED_CMD=$(build_sed_cmd "payment-worker")
sed "$SED_CMD" k8s/payment-worker-deployment.yaml | kubectl apply -f -

# Deploy Payment Dashboard
echo "Deploying Payment Dashboard..."
SED_CMD=$(build_sed_cmd "payment-dashboard")
sed "$SED_CMD" k8s/payment-dashboard-deployment.yaml | kubectl apply -f -

# Deploy Frontend
echo "Deploying Frontend..."
SED_CMD=$(build_sed_cmd "frontend")
sed "$SED_CMD" k8s/frontend-deployment.yaml | kubectl apply -f -

# Deploy Ingress (if enabled)
if [ "${ENABLE_INGRESS}" = "true" ]; then
  echo ""
  echo "Setting up Ingress with TLS..."

  # Copy TLS secret if configured
  if [ -n "${TLS_SECRET_NAME}" ] && [ -n "${TLS_SECRET_SOURCE_NAMESPACE}" ]; then
    echo "Copying TLS secret '${TLS_SECRET_NAME}' from namespace '${TLS_SECRET_SOURCE_NAMESPACE}'..."
    kubectl get secret "${TLS_SECRET_NAME}" -n "${TLS_SECRET_SOURCE_NAMESPACE}" -o yaml \
      | sed "s/namespace: ${TLS_SECRET_SOURCE_NAMESPACE}/namespace: $NAMESPACE/g" \
      | kubectl apply -n "$NAMESPACE" -f -
  fi

  # Apply ingress manifest with placeholder replacements
  INGRESS_SED="$namespace_sed"
  INGRESS_SED="$INGRESS_SED; s/INGRESS_CLASS_PLACEHOLDER/${INGRESS_CLASS:-nginx}/g"
  INGRESS_SED="$INGRESS_SED; s/FRONTEND_HOST_PLACEHOLDER/${FRONTEND_HOST}/g"
  INGRESS_SED="$INGRESS_SED; s/DASHBOARD_HOST_PLACEHOLDER/${DASHBOARD_HOST}/g"
  INGRESS_SED="$INGRESS_SED; s/API_HOST_PLACEHOLDER/${API_HOST}/g"
  INGRESS_SED="$INGRESS_SED; s/TLS_SECRET_PLACEHOLDER/${TLS_SECRET_NAME:-honey-store-tls}/g"

  sed "$INGRESS_SED" k8s/ingress.yaml | kubectl apply -f -
  echo "✓ Ingress deployed"
fi

echo ""
echo "✅ Deployment complete!"
echo ""

# Force restart deployments to ensure latest images are pulled
echo "Restarting deployments to pull latest images..."
kubectl rollout restart deployment/backend -n "$NAMESPACE"
kubectl rollout restart deployment/frontend -n "$NAMESPACE"
kubectl rollout restart deployment/payment-api -n "$NAMESPACE"
kubectl rollout restart deployment/payment-worker -n "$NAMESPACE"
kubectl rollout restart deployment/payment-dashboard -n "$NAMESPACE"

echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=300s || echo "Backend may still be starting..."
kubectl rollout status deployment/frontend -n "$NAMESPACE" --timeout=300s || echo "Frontend may still be starting..."
kubectl rollout status deployment/payment-api -n "$NAMESPACE" --timeout=300s || echo "Payment API may still be starting..."
kubectl rollout status deployment/payment-worker -n "$NAMESPACE" --timeout=300s || echo "Payment Worker may still be starting..."
kubectl rollout status deployment/payment-dashboard -n "$NAMESPACE" --timeout=300s || echo "Payment Dashboard may still be starting..."

echo ""
echo "Available services:"
echo "  - Backend:           ClusterIP (kubectl get svc backend -n $NAMESPACE)"
echo "  - Frontend:          ClusterIP (kubectl get svc frontend -n $NAMESPACE)"
echo "  - Payment API:       ClusterIP (kubectl get svc payment-api -n $NAMESPACE)"
echo "  - Payment Dashboard: ClusterIP (kubectl get svc payment-dashboard -n $NAMESPACE)"
echo "  - Payment Worker:    (no service - worker only)"
echo "  - MongoDB:           ClusterIP (kubectl get svc mongodb -n $NAMESPACE)"
echo "  - PostgreSQL:        Headless  (kubectl get svc postgresql -n $NAMESPACE)"
echo "  - Temporal:          ClusterIP (kubectl get svc temporal -n $NAMESPACE)"

if [ "${ENABLE_INGRESS}" = "true" ]; then
  echo ""
  echo "Ingress URLs:"
  echo "  - Frontend:  https://${FRONTEND_HOST}"
  echo "  - Dashboard: https://${DASHBOARD_HOST}"
  echo "  - API:       https://${API_HOST}"
fi

echo ""
echo "To check status: kubectl get pods -n $NAMESPACE"
echo "To view logs: kubectl logs -f <pod-name> -n $NAMESPACE"
echo "To get service URLs: kubectl get svc -n $NAMESPACE"
