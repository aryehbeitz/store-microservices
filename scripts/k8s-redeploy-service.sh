#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <service>"
  echo "Services: backend, frontend"
  exit 1
fi

SERVICE="$1"
K8S_NAMESPACE="${K8S_NAMESPACE:-meetup3}"

case "$SERVICE" in
  backend)
    DEPLOYMENT_NAME="backend"
    ;;
  frontend)
    DEPLOYMENT_NAME="frontend"
    ;;
  *)
    echo "Unknown service: $SERVICE"
    echo "Available services: backend, frontend"
    exit 1
    ;;
esac

echo "Restarting deployment $DEPLOYMENT_NAME in namespace: $K8S_NAMESPACE"
kubectl rollout restart deployment/$DEPLOYMENT_NAME -n "$K8S_NAMESPACE"

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/$DEPLOYMENT_NAME -n "$K8S_NAMESPACE" --timeout=300s

echo ""
echo "✅ $SERVICE redeployed successfully!"
echo "To view logs: kubectl logs -f deployment/$DEPLOYMENT_NAME -n $K8S_NAMESPACE"

