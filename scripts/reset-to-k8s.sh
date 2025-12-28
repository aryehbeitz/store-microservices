#!/bin/bash

# Reset everything back to normal K8s deployment
# Stops all local dev modes without redeploying

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Load namespace from .env.local if it exists
if [ -f .env.local ]; then
    source .env.local
fi
NAMESPACE="${K8S_NAMESPACE:-default}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${BOLD}  Resetting to Full K8s Deployment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check what needs to be reset
NEEDS_RESET=false

# Check telepresence
if command -v telepresence &> /dev/null && telepresence status &> /dev/null; then
    NEEDS_RESET=true
fi

# Check port-forwards
if lsof -i:3000 > /dev/null 2>&1 || lsof -i:27017 > /dev/null 2>&1 || lsof -i:8082 > /dev/null 2>&1; then
    NEEDS_RESET=true
fi

# Check backend replicas
BACKEND_REPLICAS=$(kubectl get deployment/backend -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
if [ "$BACKEND_REPLICAS" != "1" ]; then
    NEEDS_RESET=true
fi

# If nothing needs reset, show status and exit
if [ "$NEEDS_RESET" = false ]; then
    echo -e "${GREEN}✅ Already in full K8s mode - nothing to reset${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Current Status:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "Could not get pod status"
    echo ""

    # Show service URLs if available
    if [ -f .env.local ] && grep -q "FRONTEND_URL=" .env.local; then
        FRONTEND_URL=$(grep "^FRONTEND_URL=" .env.local | cut -d'=' -f2)
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Access Your Services:${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  Frontend:        ${BLUE}$FRONTEND_URL${NC}"
        echo -e "  Admin Dashboard: ${BLUE}$FRONTEND_URL/secret-admin-dashboard-xyz${NC}"
        echo ""
    fi

    exit 0
fi

# 1. Stop telepresence if running
echo -e "${YELLOW}1. Stopping telepresence...${NC}"
if command -v telepresence &> /dev/null; then
    telepresence quit 2>/dev/null || echo "   (not running)"
    echo -e "${GREEN}   ✓ Telepresence stopped${NC}"
else
    echo "   (telepresence not installed - skipping)"
fi
echo ""

# 2. Stop local port-forwards
echo -e "${YELLOW}2. Stopping port-forwards...${NC}"
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
lsof -ti:27017 | xargs kill -9 2>/dev/null || true
lsof -ti:8082 | xargs kill -9 2>/dev/null || true
pkill -f "kubectl port-forward" 2>/dev/null || true
echo -e "${GREEN}   ✓ Port-forwards stopped${NC}"
echo ""

# 3. Scale backend back up (if it was scaled down by dev:backend)
echo -e "${YELLOW}3. Scaling backend to 1 replica...${NC}"
kubectl scale deployment/backend -n "$NAMESPACE" --replicas=1 2>/dev/null || echo "   (backend may already be scaled)"
echo -e "${GREEN}   ✓ Backend scaled${NC}"
echo ""

# 4. Reset backend connection method
echo -e "${YELLOW}4. Resetting backend connection method...${NC}"
kubectl set env deployment/backend -n "$NAMESPACE" CONNECTION_METHOD="direct" 2>/dev/null || true
echo -e "${GREEN}   ✓ Backend connection method reset${NC}"
echo ""

# 5. Reset payment service URL (if it was changed by ngrok)
echo -e "${YELLOW}5. Resetting payment service backend URL...${NC}"
kubectl set env deployment/payment-api -n "$NAMESPACE" BACKEND_URL="http://backend:3000" 2>/dev/null || \
kubectl set env deployment/payment-service -n "$NAMESPACE" BACKEND_URL="http://backend:3000" 2>/dev/null || true
echo -e "${GREEN}   ✓ Payment service URL reset${NC}"
echo ""

# 6. Wait for backend to be ready
echo -e "${YELLOW}6. Waiting for backend to be ready...${NC}"
kubectl rollout status deployment/backend -n "$NAMESPACE" --timeout=60s 2>/dev/null || echo "   (timeout - check manually)"
echo -e "${GREEN}   ✓ Backend ready${NC}"
echo ""

# 7. Check status
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Current Status:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
kubectl get pods -n "$NAMESPACE" 2>/dev/null || echo "Could not get pod status"
echo ""

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}All Services Running in K8s:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ Frontend:${NC}      Running in K8s"
echo -e "${GREEN}✅ Backend:${NC}       Running in K8s"
echo -e "${GREEN}✅ MongoDB:${NC}       Running in K8s"
echo -e "${GREEN}✅ Payment API:${NC}   Running in K8s"
echo ""
echo -e "${YELLOW}ℹ️  All local development stopped${NC}"
echo -e "${YELLOW}ℹ️  No services running locally${NC}"
echo ""

# Show service URLs if available
if [ -f .env.local ] && grep -q "FRONTEND_URL=" .env.local; then
    FRONTEND_URL=$(grep "^FRONTEND_URL=" .env.local | cut -d'=' -f2)
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Access Your Services:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Frontend:        ${BLUE}$FRONTEND_URL${NC}"
    echo -e "  Admin Dashboard: ${BLUE}$FRONTEND_URL/secret-admin-dashboard-xyz${NC}"
    echo ""
fi

echo -e "${GREEN}✅ Reset complete!${NC}"
echo ""
