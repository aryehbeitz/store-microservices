#!/bin/bash

# Intercept backend service - run local backend while keeping everything else in K8s
# Your local backend will handle all requests from K8s frontend

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}${BOLD}  Telepresence: Backend Intercept${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if telepresence is installed
if ! command -v telepresence &> /dev/null; then
    echo -e "${RED}❌ Telepresence is not installed!${NC}"
    echo ""
    echo "Install with:"
    echo -e "${BLUE}  macOS:${NC}   brew install telepresence"
    echo -e "${BLUE}  Linux:${NC}   curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.15.1/telepresence-linux-amd64 -o /usr/local/bin/telepresence && chmod +x /usr/local/bin/telepresence"
    echo ""
    exit 1
fi

# Load namespace from .env.local if it exists
if [ -f .env.local ]; then
    source .env.local
fi
NAMESPACE="${K8S_NAMESPACE:-default}"

echo -e "${YELLOW}Step 1: Connecting to Kubernetes cluster...${NC}"
telepresence connect

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to connect to cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Connected${NC}"
echo ""

echo -e "${YELLOW}Step 2: Updating backend connection method...${NC}"
kubectl set env deployment/backend -n "$NAMESPACE" CONNECTION_METHOD="telepresence" 2>/dev/null || true
echo -e "${GREEN}✅ Backend configured for telepresence${NC}"
echo ""

echo -e "${YELLOW}Step 3: Intercepting backend service...${NC}"
telepresence intercept backend --port 3000:3000 -n "$NAMESPACE"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to intercept backend${NC}"
    telepresence quit
    exit 1
fi
echo -e "${GREEN}✅ Backend intercepted${NC}"
echo ""

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}What's Running Where:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ LOCAL (Your Machine - Live Changes):${NC}"
echo -e "   • Backend (run with: ${YELLOW}pnpm start:backend${NC})"
echo -e "     → Handles all requests from K8s frontend"
echo -e "     → Code changes reload automatically"
echo -e "     → Can access cluster DNS directly"
echo ""
echo -e "${BLUE}☁️  KUBERNETES CLUSTER (Cannot Change):${NC}"
echo -e "   • Frontend (deployed - test at LoadBalancer IP)"
echo -e "   • MongoDB (accessible via: mongodb:27017)"
echo -e "   • Payment API (accessible via: payment-api:8080)"
echo ""
echo -e "${GREEN}✅ WEBHOOKS:${NC}"
echo -e "   • Payment webhooks work natively"
echo -e "   • Payment API → Your local backend (via cluster)"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Next Steps:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}1. In a NEW terminal, run your local backend:${NC}"
echo ""
echo -e "   ${BLUE}pnpm start:backend${NC}"
echo ""
echo -e "${YELLOW}2. Test with the REAL deployed frontend:${NC}"
echo ""
if [ -f .env.local ] && grep -q "FRONTEND_URL=" .env.local; then
    FRONTEND_URL=$(grep "^FRONTEND_URL=" .env.local | cut -d'=' -f2)
    echo -e "   Frontend:        ${BLUE}$FRONTEND_URL${NC}"
    echo -e "   Admin Dashboard: ${BLUE}$FRONTEND_URL/secret-admin-dashboard-xyz${NC}"
else
    echo -e "   Check deployment output for frontend URL"
fi
echo ""
echo -e "${YELLOW}3. Make backend changes and see them immediately in the frontend${NC}"
echo ""
echo -e "${YELLOW}4. When done, stop telepresence:${NC}"
echo ""
echo -e "   ${BLUE}pnpm telepresence:stop${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
