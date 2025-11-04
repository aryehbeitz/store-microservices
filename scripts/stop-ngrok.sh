#!/bin/bash

echo "Stopping ngrok and port forwards..."

# Stop ngrok
if [ -f "/tmp/ngrok.pid" ]; then
    pid=$(cat "/tmp/ngrok.pid")
    if ps -p $pid > /dev/null 2>&1; then
        kill $pid
        echo "Stopped ngrok (PID: $pid)"
    fi
    rm "/tmp/ngrok.pid"
fi

# Stop port forwards
./scripts/stop-port-forward.sh 2>/dev/null

# Reset backend to default connection method
echo "Resetting backend to default connection method..."
kubectl set env deployment/backend CONNECTION_METHOD="direct"

# Restart backend to pick up new environment variables
echo "Restarting backend to pick up new environment variables..."
kubectl rollout restart deployment/backend

echo "All ngrok tunnels and port forwards stopped"
echo "Backend reset to default connection method"
