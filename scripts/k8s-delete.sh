#!/bin/bash

set -e

# Load local configuration if it exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

# Handle kubectl context (arg > .env.local > error)
CONTEXT="${1:-${K8S_CONTEXT:-}}"
if [ -z "$CONTEXT" ]; then
  echo "No context specified. Available contexts:"
  echo ""
  kubectl config get-contexts
  echo ""
  echo "Usage: $0 [context-name] [namespace]"
  echo "Or configure K8S_CONTEXT and K8S_NAMESPACE in .env.local"
  exit 1
fi

# Handle namespace (arg > .env.local > error)
NAMESPACE="${2:-${K8S_NAMESPACE:-}}"
if [ -z "$NAMESPACE" ]; then
  echo "No namespace specified."
  echo ""
  echo "Usage: $0 [context-name] [namespace]"
  echo "Or configure K8S_CONTEXT and K8S_NAMESPACE in .env.local"
  exit 1
fi

echo "Switching to context: $CONTEXT"
kubectl config use-context "$CONTEXT"

# Verify context switch
CURRENT_CONTEXT=$(kubectl config current-context)
if [ "$CURRENT_CONTEXT" != "$CONTEXT" ]; then
  echo "Error: Failed to switch to context $CONTEXT"
  echo "Current context is: $CURRENT_CONTEXT"
  exit 1
fi

echo "Deleting Kubernetes resources in context: $CURRENT_CONTEXT"
echo "Deleting from namespace: $NAMESPACE"
echo ""

namespace_sed="s/NAMESPACE_PLACEHOLDER/$NAMESPACE/g"

# Delete ingress
echo "Deleting Ingress..."
sed "$namespace_sed" k8s/ingress.yaml | kubectl delete -f - --ignore-not-found=true 2>/dev/null || true

# Delete application services
echo "Deleting Frontend..."
sed "$namespace_sed" k8s/frontend-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting Payment Dashboard..."
sed "$namespace_sed" k8s/payment-dashboard-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting Payment Worker..."
sed "$namespace_sed" k8s/payment-worker-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting Payment API..."
sed "$namespace_sed" k8s/payment-service-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting Backend..."
sed "$namespace_sed" k8s/backend-deployment.yaml | kubectl delete -f - --ignore-not-found=true

# Delete data services
echo "Deleting MongoDB..."
sed "$namespace_sed" k8s/mongodb-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting Temporal..."
sed "$namespace_sed" k8s/temporal-deployment.yaml | kubectl delete -f - --ignore-not-found=true
echo "Deleting PostgreSQL..."
sed "$namespace_sed" k8s/postgresql-statefulset.yaml | kubectl delete -f - --ignore-not-found=true

# Delete copied TLS secret if it exists
if [ -n "${TLS_SECRET_NAME}" ]; then
  echo "Deleting TLS secret copy..."
  kubectl delete secret "${TLS_SECRET_NAME}" -n "$NAMESPACE" --ignore-not-found=true
fi

# Delete secrets
echo "Deleting secrets..."
kubectl delete secret mongodb-secret -n "$NAMESPACE" --ignore-not-found=true
kubectl delete secret postgresql-secret -n "$NAMESPACE" --ignore-not-found=true

# Delete namespace (this will delete all resources in the namespace)
echo "Deleting namespace: $NAMESPACE"
kubectl delete namespace "$NAMESPACE" --ignore-not-found=true

echo ""
echo "✅ All resources deleted from namespace: $NAMESPACE"
