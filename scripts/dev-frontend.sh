#!/bin/bash

# Develop frontend locally with K8s backend

set -e

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Frontend Development Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "ℹ️  Other available commands:"
echo "   • pnpm dev:backend - Debug backend locally"
echo "   • pnpm debug:payment - Debug payment service with Telepresence"
echo ""

# 1. Configure frontend to use K8s backend
echo "📝 Configuring frontend to use K8s backend..."
./scripts/frontend-use-k8s.sh
echo ""

# 2. Kill any existing frontend on port 4200
echo "🧹 Cleaning up port 4200..."
lsof -ti:4200 | xargs kill -9 2>/dev/null || true
echo ""

# 3. Start kubectl port-forward in background
echo "🔌 Starting port-forward to K8s backend..."
# Kill existing port-forward on 3000
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
sleep 1

# Start port-forward
kubectl port-forward -n "$NAMESPACE" svc/backend 3000:3000 > /tmp/port-forward-backend.log 2>&1 &
PF_PID=$!
echo "   Port-forward PID: $PF_PID"
sleep 2

# Test backend connection
if curl -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "   ✅ Backend is accessible on localhost:3000"
else
    echo "   ⚠️  Backend not responding yet, but continuing..."
fi
echo ""

# 4. Start frontend
echo "🚀 Starting frontend with live reload..."
echo "   Frontend will be available at: http://localhost:4200"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping and cleaning up..."

    # Kill port-forward
    if [ -n "$PF_PID" ]; then
        kill $PF_PID 2>/dev/null || true
    fi
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true

    # Kill frontend
    lsof -ti:4200 | xargs kill -9 2>/dev/null || true

    echo "✅ Cleanup complete"
    exit 0
}

# Trap Ctrl+C to cleanup
trap cleanup INT TERM EXIT

# Start frontend (this will block)
pnpm start:frontend

# If frontend exits, cleanup
cleanup
