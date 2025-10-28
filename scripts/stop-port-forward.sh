#!/bin/bash

echo "Stopping port forwards..."

for pidfile in /tmp/port-forward-*.pid; do
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile")
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid
            echo "Stopped port forward (PID: $pid)"
        fi
        rm "$pidfile"
    fi
done

echo "All port forwards stopped"
