#!/bin/bash

# Verify K8s deployment and show access URLs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_ROOT/.env.local" ]; then
  export $(cat "$PROJECT_ROOT/.env.local" | grep -v '^#' | grep -v '^$' | xargs)
fi

NAMESPACE="${1:-${K8S_NAMESPACE:-default}}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deployment Verification"
echo "  Namespace: $NAMESPACE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check pods
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || echo "  (cannot list pods)"
echo ""

# Check services
echo "Services:"
kubectl get svc -n "$NAMESPACE" 2>/dev/null || echo "  (cannot list services)"
echo ""

# Check statefulsets
echo "StatefulSets:"
kubectl get statefulsets -n "$NAMESPACE" 2>/dev/null || echo "  (none)"
echo ""

# Count pod statuses
TOTAL=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
RUNNING=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
NOT_READY=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Running" | grep -v "Completed" | wc -l | tr -d ' ')

echo "Pod Summary: $RUNNING/$TOTAL running"
if [ "$NOT_READY" -gt 0 ]; then
  echo "  Warning: $NOT_READY pod(s) not ready:"
  kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v "Running" | grep -v "Completed"
fi
echo ""

# Ingress check
if [ "${ENABLE_INGRESS}" = "true" ]; then
  echo "Ingress:"
  kubectl get ingress -n "$NAMESPACE" 2>/dev/null || echo "  (no ingress found)"
  echo ""

  echo "Testing HTTPS endpoints..."
  for host in "$FRONTEND_HOST" "$DASHBOARD_HOST" "$API_HOST"; do
    if [ -n "$host" ]; then
      status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$host" 2>/dev/null || echo "000")
      if [ "$status" = "200" ] || [ "$status" = "301" ] || [ "$status" = "302" ]; then
        echo "  ✓ https://$host -> $status"
      else
        echo "  ✗ https://$host -> $status"
      fi
    fi
  done
  echo ""

  echo "Access URLs:"
  echo "  Frontend:  https://${FRONTEND_HOST}"
  echo "  Dashboard: https://${DASHBOARD_HOST}"
  echo "  API:       https://${API_HOST}"
else
  # Fallback: check LoadBalancer IPs
  FRONTEND_IP=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ -n "$FRONTEND_IP" ]; then
    echo "Frontend URL: http://$FRONTEND_IP"
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$FRONTEND_IP" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
      echo "  ✓ Frontend is responding"
    else
      echo "  ✗ Frontend not responding (HTTP $status)"
    fi
  else
    echo "Frontend: ClusterIP only (use port-forward or enable Ingress)"
  fi
fi

echo ""

# Check for secrets (should NOT be in manifests)
echo "Security check:"
secret_hits=$(grep -r "password\|secret.*:" k8s/ --include="*.yaml" 2>/dev/null | grep -v "secretKeyRef\|secretName\|Secret\|secret:" | grep -v "PLACEHOLDER" | grep -v "mongodb-secret\|postgresql-secret" || echo "")
if [ -z "$secret_hits" ]; then
  echo "  ✓ No hardcoded secrets found in k8s manifests"
else
  echo "  ✗ Potential secrets found in manifests:"
  echo "$secret_hits"
fi

echo ""
