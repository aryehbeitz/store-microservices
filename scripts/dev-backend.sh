#!/bin/bash

# Develop backend locally with frontend already running

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Backend Development Mode"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if frontend is running
if ! lsof -i:4200 > /dev/null 2>&1; then
    echo "❌ Frontend is not running"
    echo ""
    echo "Start frontend first with:"
    echo "  pnpm dev:frontend"
    echo ""
    exit 1
fi

echo "✅ Frontend is running on port 4200"
echo ""

# Configure frontend to use local backend
echo "📝 Configuring frontend to use LOCAL backend..."
./scripts/frontend-use-local.sh
echo ""

# Kill any existing backend on port 3000
echo "🧹 Cleaning up port 3000..."
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
sleep 1
echo ""

# Load credentials from .env.local
if [ -f .env.local ]; then
    source .env.local
fi

# Set required environment variables for backend
export MONGODB_URI="mongodb://${MONGODB_USERNAME}:${MONGODB_PASSWORD}@localhost:27017/${MONGODB_DATABASE}?authSource=admin"
export PAYMENT_SERVICE_URL=${PAYMENT_SERVICE_URL:-http://localhost:8082}
export SERVICE_LOCATION=local

# Check if ngrok is running and get the public URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4 | head -1)
if [ -n "$NGROK_URL" ]; then
    export BACKEND_PUBLIC_URL="$NGROK_URL"
    export CONNECTION_METHOD=ngrok
    echo "✅ Ngrok detected: $NGROK_URL"
else
    export CONNECTION_METHOD=local
    echo "⚠️  Ngrok not detected - webhooks will not work"
    echo "   Start ngrok in another terminal: pnpm dev:ngrok"
fi

echo "🔌 Setting up dependencies..."
echo "   MongoDB: Port-forwarding to K8s..."
# Kill existing MongoDB port-forward
lsof -ti:27017 | xargs kill -9 2>/dev/null || true
kubectl port-forward -n meetup3 svc/mongodb 27017:27017 > /tmp/port-forward-mongodb.log 2>&1 &
MONGODB_PF_PID=$!
sleep 2

echo "   Payment API: Port-forwarding to K8s..."
# Kill existing Payment port-forward
lsof -ti:8082 | xargs kill -9 2>/dev/null || true
kubectl port-forward -n meetup3 svc/payment-api 8082:8080 > /tmp/port-forward-payment.log 2>&1 &
PAYMENT_PF_PID=$!
sleep 2
echo ""

echo "🚀 Starting local backend with live reload..."
echo "   Backend will be available at: http://localhost:3000"
echo "   MongoDB: mongodb://${MONGODB_USERNAME}:***@localhost:27017/${MONGODB_DATABASE}"
echo "   Payment API: $PAYMENT_SERVICE_URL"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping and cleaning up..."

    # Kill backend
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true

    # Kill port-forwards
    if [ -n "$MONGODB_PF_PID" ]; then
        kill $MONGODB_PF_PID 2>/dev/null || true
    fi
    if [ -n "$PAYMENT_PF_PID" ]; then
        kill $PAYMENT_PF_PID 2>/dev/null || true
    fi
    lsof -ti:27017 | xargs kill -9 2>/dev/null || true
    lsof -ti:8082 | xargs kill -9 2>/dev/null || true

    echo "✅ Cleanup complete"
    exit 0
}

# Trap Ctrl+C to cleanup
trap cleanup INT TERM EXIT

# Start backend with tsx (bypasses nx serve issue)
npx tsx --watch apps/backend/src/main.ts

# If backend exits, cleanup
cleanup
