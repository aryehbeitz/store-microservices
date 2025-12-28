#!/bin/bash

# Start ngrok for local backend webhooks
# Only works when both frontend and backend are running locally

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ngrok Webhook Tunnel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if frontend is running locally
if ! lsof -i:4200 > /dev/null 2>&1; then
    echo "❌ Frontend is not running"
    echo ""
    echo "Start frontend first:"
    echo "  Terminal 1: pnpm dev:frontend"
    echo ""
    exit 1
fi

# Check if backend is running locally
if ! lsof -i:3000 > /dev/null 2>&1; then
    echo "❌ Backend is not running"
    echo ""
    echo "Start backend first:"
    echo "  Terminal 1: pnpm dev:frontend"
    echo "  Terminal 2: pnpm dev:backend"
    echo ""
    exit 1
fi

echo "✅ Frontend is running on port 4200"
echo "✅ Backend is running on port 3000"
echo ""

# Kill any existing ngrok
echo "🧹 Cleaning up existing ngrok..."
pkill -f ngrok 2>/dev/null || true
sleep 1
echo ""

echo "🚀 Starting ngrok tunnel to local backend..."
echo "   This will expose http://localhost:3000 to the internet"
echo ""

# Start ngrok in background first
ngrok http 3000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to start
sleep 3

# Get ngrok public URL
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*' | cut -d'"' -f4 | head -1)

if [ -z "$NGROK_URL" ]; then
    echo "❌ Failed to get ngrok URL"
    kill $NGROK_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Ngrok tunnel started: $NGROK_URL"
echo ""

# Update payment service to use ngrok URL
echo "🔄 Updating payment service to use ngrok URL..."
kubectl set env deployment/payment-api -n meetup3 BACKEND_URL="$NGROK_URL" 2>/dev/null || \
kubectl set env deployment/payment-service -n meetup3 BACKEND_URL="$NGROK_URL" 2>/dev/null || true
echo "✅ Payment service updated"
echo ""

echo "⚠️  IMPORTANT: Restart your backend to enable ngrok:"
echo "   1. Go to Terminal 2 (where backend is running)"
echo "   2. Press Ctrl+C"
echo "   3. Run: pnpm dev:backend"
echo "   4. Backend will detect ngrok and use it for webhooks"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ngrok tunnel active"
echo "  Press Ctrl+C to stop and restore payment service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping ngrok and restoring payment service..."

    # Kill ngrok
    kill $NGROK_PID 2>/dev/null || true
    pkill -f ngrok 2>/dev/null || true

    # Restore payment service to use K8s backend
    echo "🔄 Restoring payment service to K8s backend..."
    kubectl set env deployment/payment-api -n meetup3 BACKEND_URL="http://backend:3000" 2>/dev/null || \
    kubectl set env deployment/payment-service -n meetup3 BACKEND_URL="http://backend:3000" 2>/dev/null || true

    echo "✅ Cleanup complete"
    exit 0
}

# Trap Ctrl+C to cleanup
trap cleanup INT TERM EXIT

# Show ngrok logs (foreground)
tail -f /tmp/ngrok.log
