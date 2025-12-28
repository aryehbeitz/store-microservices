#!/bin/bash

# Switch frontend to use K8s backend (via port-forward)
echo "Configuring frontend to use K8S backend via port-forward..."

cat > apps/frontend/src/environments/environment.ts << 'EOF'
// Auto-generated - Frontend talks to K8s backend via port-forward
export const environment = {
  production: false,
  backendUrl: 'http://localhost:3000', // Port-forwarded from K8s
};
EOF

echo "✓ Frontend configured for K8s backend (port-forward)"
echo "  Backend URL: http://localhost:3000 (port-forwarded)"
echo ""
echo "Make sure K8s backend port-forward is running:"
echo "  kubectl port-forward -n meetup3 svc/backend 3000:3000"
