#!/bin/bash

# Debug backend locally with Telepresence
# K8s backend traffic -> your local backend

set -e

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Debug Backend with Telepresence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if telepresence is installed
if ! command -v telepresence &> /dev/null; then
    echo "❌ Telepresence is not installed"
    echo ""
    echo "Install it: brew install datawire/blackbird/telepresence"
    exit 1
fi

# Connect to cluster if not connected
if ! telepresence status | grep -q "Connected"; then
    echo "🔌 Connecting to K8s cluster..."
    telepresence connect
    echo ""
fi

# Load credentials from .env.local
if [ -f .env.local ]; then
    source .env.local
fi

echo "✅ Telepresence connected"
echo ""
echo "🔀 Intercepting backend service..."
echo "   K8s traffic to backend:3000 → localhost:3000"
echo ""
echo "⚠️  NEXT STEPS:"
echo "   1. Open a NEW terminal"
echo "   2. Run these commands:"
echo ""
echo "      export MONGODB_URI=\"mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@mongodb:27017/${MONGODB_DATABASE}?authSource=admin\""
echo "      export PAYMENT_SERVICE_URL=\"http://payment-api:8080\""
echo "      export SERVICE_LOCATION=cloud"
echo "      export CONNECTION_METHOD=telepresence"
echo "      pnpm start:backend"
echo ""
echo "   3. Visit: http://34.75.143.108 (K8s frontend → your local backend!)"
echo "   4. Set breakpoints in VS Code and debug!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Press Ctrl+C to stop intercept"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping intercept..."
    telepresence leave backend-$NAMESPACE 2>/dev/null || true
    echo "✅ Intercept stopped"
    echo ""
    echo "To disconnect telepresence completely:"
    echo "  telepresence quit"
    exit 0
}

trap cleanup INT TERM EXIT

# Start intercept (this blocks)
telepresence intercept backend --port 3000 --namespace $NAMESPACE

# If we get here, intercept ended
cleanup
