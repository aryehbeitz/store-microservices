#!/bin/bash

# Debug Payment Service with Telepresence
# This script intercepts the payment-api service in K8s and runs it locally with debugger enabled

set -e

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "🚀 Starting Payment Service Debug Setup..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."

    # Leave any existing intercepts
    telepresence leave payment-api 2>/dev/null || true

    # Kill processes on ports
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
    lsof -ti:9229 | xargs kill -9 2>/dev/null || true

    telepresence quit 2>/dev/null || true

    echo "✅ Cleanup complete"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Clean up any existing intercepts and processes first
echo "🧹 Cleaning up any existing intercepts and processes..."
telepresence leave payment-api 2>/dev/null || true
lsof -ti:8080 | xargs kill -9 2>/dev/null || true
lsof -ti:9229 | xargs kill -9 2>/dev/null || true
sleep 1
echo ""

# Connect to Telepresence
echo "📡 Connecting to Telepresence in namespace: $NAMESPACE"
telepresence connect --namespace "$NAMESPACE" 2>&1 | grep -v "^$" || true

echo ""
echo "🔍 Setting up intercept for payment-api..."

# Start intercept (namespace is inherited from connection)
telepresence intercept payment-api \
    --port 8080:8080 \
    --env-file /tmp/payment-intercept.env &

INTERCEPT_PID=$!

# Wait a moment for intercept to start
sleep 3

# Check if intercept is active
if telepresence list 2>/dev/null | grep -q "payment-api: intercepted"; then
    echo "✅ Intercept active!"
else
    echo "⚠️  Intercept may not be fully active yet, but starting local service..."
fi

# Get frontend URL
FRONTEND_IP=$(kubectl get service frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
if [ -z "$FRONTEND_IP" ]; then
    FRONTEND_URL="(Frontend IP not found)"
else
    FRONTEND_URL="http://$FRONTEND_IP"
fi

echo ""
echo "🐛 Starting local payment service with debugger..."
echo "   Port: 8080"
echo "   Debugger: ws://127.0.0.1:9229"
echo "   VS Code: Attach to Node Process (port 9229)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Ready! Set breakpoints and trigger payment flow"
echo ""
echo "🌐 Frontend: $FRONTEND_URL"
echo "   (Create an order to trigger payment flow)"
echo ""
echo "Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Start local payment service with debugger
cd "$(dirname "$0")/.."
export PORT=8080
export BACKEND_URL="http://backend:3000"
export SERVICE_LOCATION=local
export CONNECTION_METHOD=telepresence

npx tsx --inspect --watch apps/payment-service/src/main.ts
