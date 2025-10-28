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

echo "All ngrok tunnels and port forwards stopped"
