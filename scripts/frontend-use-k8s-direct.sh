#!/bin/bash

# Switch frontend to use K8s backend directly (LoadBalancer IP)
# Get the current K8s namespace
NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "Configuring frontend to use K8S backend directly (LoadBalancer)..."

# Try to get the LoadBalancer IP
BACKEND_IP=$(kubectl get svc backend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$BACKEND_IP" ]; then
    echo "⚠️  Backend service doesn't have a LoadBalancer IP"
    echo "   Using ClusterIP - you'll need kubectl port-forward or telepresence"
    BACKEND_URL="http://localhost:3000"
else
    BACKEND_URL="http://$BACKEND_IP:3000"
fi

cat > apps/frontend/src/environments/environment.ts << EOF
// Auto-generated - Frontend talks to K8s backend directly
export const environment = {
  production: false,
  backendUrl: '$BACKEND_URL',
};
EOF

echo "✓ Frontend configured for K8s backend (direct)"
echo "  Backend URL: $BACKEND_URL"

if [ -z "$BACKEND_IP" ]; then
    echo ""
    echo "To use this, run:"
    echo "  kubectl port-forward -n $NAMESPACE svc/backend 3000:3000"
fi
