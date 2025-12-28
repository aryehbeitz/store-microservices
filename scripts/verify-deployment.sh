#!/bin/bash

# Verify K8s deployment and show frontend IP

NAMESPACE="${K8S_NAMESPACE:-meetup3}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deployment Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check pods
echo "📦 Pods:"
kubectl get pods -n "$NAMESPACE" -o wide | grep -E "NAME|frontend|backend|mongodb|payment"
echo ""

# Check services
echo "🌐 Services:"
kubectl get svc -n "$NAMESPACE" | grep -E "NAME|frontend|backend|mongodb|payment"
echo ""

# Get frontend IP
FRONTEND_IP=$(kubectl get svc frontend -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$FRONTEND_IP" ]; then
    echo "✅ Frontend URL: http://$FRONTEND_IP"
    echo ""

    # Test frontend health
    if curl -s -o /dev/null -w "%{http_code}" "http://$FRONTEND_IP" | grep -q "200"; then
        echo "✅ Frontend is responding"
    else
        echo "⚠️  Frontend not responding yet"
    fi
else
    echo "❌ Frontend LoadBalancer IP not found"
fi

echo ""
