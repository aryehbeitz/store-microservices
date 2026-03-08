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

# Load config
export $(cat "$ENV_FILE" | grep -v '^#' | grep -v '^$' | xargs)

echo ""
echo "========================================"
echo "Updating Service URLs in .env.local"
echo "========================================"
echo "Namespace: $NAMESPACE"
echo ""

# Remove old service URL entries if they exist
sed -i.bak '/^FRONTEND_URL=/d; /^BACKEND_URL=/d; /^PAYMENT_SERVICE_URL=/d; /^ADMIN_DASHBOARD_URL=/d' "$ENV_FILE"
rm -f "$ENV_FILE.bak"

# If Ingress is enabled, use ingress hostnames instead of LoadBalancer IPs
if [ "${ENABLE_INGRESS}" = "true" ]; then
  echo "Ingress is enabled — using hostname-based URLs."
  echo ""

  FRONTEND_URL="https://${FRONTEND_HOST}"
  ADMIN_DASHBOARD_URL="https://${FRONTEND_HOST}/secret-admin-dashboard-xyz"

  {
    echo ""
    echo "# Service URLs (Ingress-based)"
    echo "FRONTEND_URL=$FRONTEND_URL"
    echo "ADMIN_DASHBOARD_URL=$ADMIN_DASHBOARD_URL"
  } >> "$ENV_FILE"

  echo "✓ .env.local updated with Ingress URLs"
  echo ""
  echo "========================================"
  echo "Service Access URLs"
  echo "========================================"
  echo "Frontend:        $FRONTEND_URL"
  echo "Admin Dashboard: $ADMIN_DASHBOARD_URL"
  echo "Dashboard:       https://${DASHBOARD_HOST}"
  echo "API:             https://${API_HOST}"
  echo ""

  # Check ingress status
  echo "Ingress status:"
  kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "  (no ingress found)"
  echo ""
  exit 0
fi

# Fallback: LoadBalancer IP detection
echo "Ingress not enabled — detecting LoadBalancer IPs..."
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

# Check payment API service
PAYMENT_TYPE=$(get_service_type "payment-api" "$NAMESPACE")
if [ "$PAYMENT_TYPE" = "LoadBalancer" ]; then
  echo "Detecting payment API IP..."
  PAYMENT_IP=$(get_service_url "payment-api" "$NAMESPACE")
  if [ -n "$PAYMENT_IP" ]; then
    PAYMENT_URL="http://$PAYMENT_IP:8080"
    echo "✓ Payment API: $PAYMENT_URL"
  else
    echo "⚠️  Payment API IP still pending"
    PAYMENT_URL=""
  fi
else
  echo "ℹ️  Payment API service type: $PAYMENT_TYPE (no external IP)"
  PAYMENT_URL=""
fi

# Update .env.local file
echo ""
echo "Updating .env.local..."

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
  echo "Payment API:     $PAYMENT_URL"
else
  echo "Payment API:     (ClusterIP - internal only)"
fi

echo ""
