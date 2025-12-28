#!/bin/bash

# Connect to K8s cluster without intercepting any services
# Just enables access to cluster DNS and services from local machine

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
echo -e "${BLUE}${BOLD}  Telepresence: Connect Only (No Intercepts)${NC}"
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

echo -e "${YELLOW}Connecting to Kubernetes cluster...${NC}"
telepresence connect

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to connect to cluster${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Connected to Kubernetes cluster!${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}What's Running Where:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ LOCAL (Your Machine):${NC}"
echo -e "   • Can access cluster DNS (mongodb, payment-api, etc.)"
echo -e "   • Can run local code that needs cluster services"
echo ""
echo -e "${BLUE}☁️  KUBERNETES CLUSTER:${NC}"
echo -e "   • Frontend (running in K8s)"
echo -e "   • Backend (running in K8s)"
echo -e "   • MongoDB (running in K8s)"
echo -e "   • Payment API (running in K8s)"
echo ""
echo -e "${YELLOW}ℹ️  No services are intercepted${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}What You Can Do:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  • Access cluster services from your local machine:"
echo -e "    ${BLUE}curl http://mongodb:27017${NC}"
echo -e "    ${BLUE}curl http://payment-api:8080/health${NC}"
echo ""
echo "  • Run local code that needs cluster DNS"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}To Disconnect:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${YELLOW}pnpm telepresence:stop${NC}"
echo ""
