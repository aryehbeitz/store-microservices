#!/bin/bash

# Debug frontend locally with Telepresence
# K8s frontend traffic -> your local frontend

set -e

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Debug Frontend with Telepresence"
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

echo "✅ Telepresence connected"
echo ""
echo "🔀 Intercepting frontend service..."
echo "   K8s traffic to frontend:80 → localhost:4200"
echo ""
echo "⚠️  NEXT STEPS:"
echo "   1. Open a NEW terminal"
echo "   2. Run: pnpm start:frontend"
echo "   3. Visit: http://34.75.143.108 (K8s IP → your local frontend!)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Press Ctrl+C to stop intercept"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping intercept..."
    telepresence leave frontend-$NAMESPACE 2>/dev/null || true
    echo "✅ Intercept stopped"
    echo ""
    echo "To disconnect telepresence completely:"
    echo "  telepresence quit"
    exit 0
}

trap cleanup INT TERM EXIT

# Start intercept (this blocks)
telepresence intercept frontend --port 4200 --namespace $NAMESPACE

# If we get here, intercept ended
cleanup
