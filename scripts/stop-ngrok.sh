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

# Reset services to default connection method
echo "Resetting services to default connection method..."
kubectl set env deployment/payment-service CONNECTION_METHOD="direct"
kubectl set env deployment/backend CONNECTION_METHOD="direct"

# Restart services to pick up new environment variables
echo "Restarting services to pick up new environment variables..."
kubectl rollout restart deployment/payment-service
kubectl rollout restart deployment/backend

echo "All ngrok tunnels and port forwards stopped"
echo "Services reset to default connection method"
