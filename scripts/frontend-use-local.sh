#!/bin/bash

# Switch frontend to use local backend
echo "Configuring frontend to use LOCAL backend (http://localhost:3000)..."

cat > apps/frontend/src/environments/environment.ts << 'EOF'
// Auto-generated - Frontend talks to LOCAL backend
export const environment = {
  production: false,
  backendUrl: 'http://localhost:3000',
};
EOF

echo "✓ Frontend configured for local backend"
echo "  Backend URL: http://localhost:3000"
