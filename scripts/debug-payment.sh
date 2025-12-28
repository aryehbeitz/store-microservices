#!/bin/bash

# Debug payment service locally with Telepresence
# K8s payment-api traffic -> your local payment service

set -e

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Debug Payment Service with Telepresence"
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
echo "🔀 Intercepting payment-api service..."
echo "   K8s traffic to payment-api:8080 → localhost:8080"
echo ""
echo "⚠️  NEXT STEPS:"
echo "   1. Open a NEW terminal"
echo "   2. Run: pnpm start:payment"
echo "   3. Set breakpoints in payment service code!"
echo "   4. Create an order and watch your breakpoints hit ⭐"
echo ""
echo "📝 Note: This is the ONLY way to debug payment service with breakpoints!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Press Ctrl+C to stop intercept"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping intercept..."
    telepresence leave payment-api-$NAMESPACE 2>/dev/null || true
    echo "✅ Intercept stopped"
    echo ""
    echo "To disconnect telepresence completely:"
    echo "  telepresence quit"
    exit 0
}

trap cleanup INT TERM EXIT

# Start intercept (this blocks)
telepresence intercept payment-api --port 8080 --namespace $NAMESPACE

# If we get here, intercept ended
cleanup
