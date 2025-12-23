#!/bin/bash

set -e

# Get namespace from argument or environment
NAMESPACE="${1:-${K8S_NAMESPACE:-default}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env.local"

if [ ! -f "$ENV_FILE" ]; then
  echo "⚠️  .env.local not found. Run ./scripts/setup-local-config.sh first."
  exit 0
fi

echo ""
echo "========================================"
echo "Updating Service IPs in .env.local"
echo "========================================"
echo "Namespace: $NAMESPACE"
echo ""

# Function to get external IP or hostname for a service
get_service_url() {
  local service_name=$1
  local namespace=$2

  # Wait for external IP (max 30 seconds)
  for i in {1..30}; do
    # Try to get LoadBalancer IP
    EXTERNAL_IP=$(kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    # If no IP, try hostname (for some cloud providers)
    if [ -z "$EXTERNAL_IP" ]; then
      EXTERNAL_IP=$(kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    fi

    # If we got an IP/hostname, break
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "<pending>" ]; then
      echo "$EXTERNAL_IP"
      return 0
    fi

    # Wait a bit
    sleep 1
  done

  echo ""
  return 1
}

# Get service type first
get_service_type() {
  local service_name=$1
  local namespace=$2
  kubectl get svc "$service_name" -n "$namespace" -o jsonpath='{.spec.type}' 2>/dev/null || echo ""
}

# Check frontend service
FRONTEND_TYPE=$(get_service_type "frontend" "$NAMESPACE")
if [ "$FRONTEND_TYPE" = "LoadBalancer" ]; then
  echo "Detecting frontend IP..."
  FRONTEND_IP=$(get_service_url "frontend" "$NAMESPACE")
  if [ -n "$FRONTEND_IP" ]; then
    FRONTEND_URL="http://$FRONTEND_IP"
    echo "✓ Frontend: $FRONTEND_URL"
  else
    echo "⚠️  Frontend IP still pending"
    FRONTEND_URL=""
  fi
else
  echo "ℹ️  Frontend service type: $FRONTEND_TYPE (no external IP)"
  FRONTEND_URL=""
fi

# Check backend service
BACKEND_TYPE=$(get_service_type "backend" "$NAMESPACE")
if [ "$BACKEND_TYPE" = "LoadBalancer" ]; then
  echo "Detecting backend IP..."
  BACKEND_IP=$(get_service_url "backend" "$NAMESPACE")
  if [ -n "$BACKEND_IP" ]; then
    BACKEND_URL="http://$BACKEND_IP:3000"
    echo "✓ Backend: $BACKEND_URL"
  else
    echo "⚠️  Backend IP still pending"
    BACKEND_URL=""
  fi
else
  echo "ℹ️  Backend service type: $BACKEND_TYPE (no external IP)"
  BACKEND_URL=""
fi

# Check payment service
PAYMENT_TYPE=$(get_service_type "payment-service" "$NAMESPACE")
if [ "$PAYMENT_TYPE" = "LoadBalancer" ]; then
  echo "Detecting payment service IP..."
  PAYMENT_IP=$(get_service_url "payment-service" "$NAMESPACE")
  if [ -n "$PAYMENT_IP" ]; then
    PAYMENT_URL="http://$PAYMENT_IP:3002"
    echo "✓ Payment Service: $PAYMENT_URL"
  else
    echo "⚠️  Payment service IP still pending"
    PAYMENT_URL=""
  fi
else
  echo "ℹ️  Payment service type: $PAYMENT_TYPE (no external IP)"
  PAYMENT_URL=""
fi

# Update .env.local file
echo ""
echo "Updating .env.local..."

# Remove old service URL entries if they exist
sed -i.bak '/^FRONTEND_URL=/d; /^BACKEND_URL=/d; /^PAYMENT_SERVICE_URL=/d; /^ADMIN_DASHBOARD_URL=/d' "$ENV_FILE"

# Append new service URLs
{
  echo ""
  echo "# Service URLs (auto-updated after deployment)"
  if [ -n "$FRONTEND_URL" ]; then
    echo "FRONTEND_URL=$FRONTEND_URL"
    echo "ADMIN_DASHBOARD_URL=$FRONTEND_URL/secret-admin-dashboard-xyz"
  fi
  if [ -n "$BACKEND_URL" ]; then
    echo "BACKEND_URL=$BACKEND_URL"
  fi
  if [ -n "$PAYMENT_URL" ]; then
    echo "PAYMENT_SERVICE_URL=$PAYMENT_URL"
  fi
} >> "$ENV_FILE"

# Remove backup file
rm -f "$ENV_FILE.bak"

echo "✓ .env.local updated"
echo ""
echo "========================================"
echo "Service Access URLs"
echo "========================================"

if [ -n "$FRONTEND_URL" ]; then
  echo "Frontend:        $FRONTEND_URL"
  echo "Admin Dashboard: $FRONTEND_URL/secret-admin-dashboard-xyz"
else
  echo "Frontend:        (ClusterIP - use port-forward or Ingress)"
fi

if [ -n "$BACKEND_URL" ]; then
  echo "Backend:         $BACKEND_URL"
else
  echo "Backend:         (ClusterIP - internal only)"
fi

if [ -n "$PAYMENT_URL" ]; then
  echo "Payment Service: $PAYMENT_URL"
else
  echo "Payment Service: (ClusterIP - internal only)"
fi

echo ""
