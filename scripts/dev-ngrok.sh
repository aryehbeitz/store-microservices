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
echo "⚠️  IMPORTANT: After ngrok starts, restart your backend:"
echo "   1. Go to Terminal 2 (where backend is running)"
echo "   2. Press Ctrl+C"
echo "   3. Run: pnpm dev:backend"
echo "   4. Backend will detect ngrok and use it for webhooks"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ngrok will run in foreground"
echo "  Press Ctrl+C to stop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo "🛑 Stopping ngrok..."
    pkill -f ngrok 2>/dev/null || true
    echo "✅ Cleanup complete"
    exit 0
}

# Trap Ctrl+C to cleanup
trap cleanup INT TERM EXIT

# Start ngrok
ngrok http 3000 --log=stdout
