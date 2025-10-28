#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Telepresence Setup                 ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Check if telepresence is installed
if ! command -v telepresence &> /dev/null; then
    echo -e "${RED}Telepresence is not installed!${NC}"
    echo ""
    echo "Installation instructions:"
    echo ""
    echo -e "${BLUE}macOS:${NC}"
    echo "  brew install telepresence"
    echo ""
    echo -e "${BLUE}Linux:${NC}"
    echo "  sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.15.1/telepresence-linux-amd64 -o /usr/local/bin/telepresence"
    echo "  sudo chmod +x /usr/local/bin/telepresence"
    echo ""
    exit 1
fi

echo -e "${BLUE}Step 1: Connecting to Kubernetes cluster${NC}"
telepresence connect

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to connect to cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connected to cluster${NC}\n"

echo -e "${BLUE}Step 2: Setting up intercepts${NC}"
echo ""
echo "Choose which service to intercept:"
echo "  1) Backend"
echo "  2) Payment Service"
echo "  3) Both"
echo "  4) None (just connect to cluster)"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "\n${BLUE}Intercepting backend service...${NC}"
        telepresence intercept backend --port 3000:3000
        echo -e "${GREEN}✓ Backend service intercepted${NC}"
        echo ""
        echo "Now run your local backend:"
        echo "  cd apps/backend"
        echo "  npm run serve"
        echo ""
        echo "Your local backend will handle requests from the cluster!"
        ;;
    2)
        echo -e "\n${BLUE}Intercepting payment service...${NC}"
        telepresence intercept payment-service --port 3002:3002
        echo -e "${GREEN}✓ Payment service intercepted${NC}"
        echo ""
        echo "Now run your local payment service:"
        echo "  cd apps/payment-service"
        echo "  npm run serve"
        echo ""
        echo "Your local payment service will handle requests from the cluster!"
        ;;
    3)
        echo -e "\n${BLUE}Intercepting backend service...${NC}"
        telepresence intercept backend --port 3000:3000
        echo -e "${GREEN}✓ Backend service intercepted${NC}"
        echo ""
        echo -e "${BLUE}Intercepting payment service...${NC}"
        telepresence intercept payment-service --port 3002:3002
        echo -e "${GREEN}✓ Payment service intercepted${NC}"
        echo ""
        echo "Now run your local services in separate terminals:"
        echo ""
        echo "Terminal 1:"
        echo "  cd apps/backend && npm run serve"
        echo ""
        echo "Terminal 2:"
        echo "  cd apps/payment-service && npm run serve"
        ;;
    4)
        echo -e "${GREEN}Connected to cluster without intercepts${NC}"
        echo "You can now access cluster services from your local machine"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        telepresence quit
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Telepresence Status                ${NC}"
echo -e "${BLUE}======================================${NC}"
telepresence status

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Service Access                     ${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}You can now access cluster services directly:${NC}"
echo "  Backend:         http://backend.default.svc.cluster.local:3000"
echo "  Payment Service: http://payment-service.default.svc.cluster.local:3002"
echo "  MongoDB:         mongodb://mongodb.default.svc.cluster.local:27017"

echo ""
echo -e "${YELLOW}To stop telepresence:${NC}"
echo "  ./scripts/stop-telepresence.sh"
echo ""
echo -e "${BLUE}Press Ctrl+C to quit telepresence${NC}"

# Create stop script
cat > scripts/stop-telepresence.sh << 'EOF'
#!/bin/bash

echo "Stopping telepresence..."
telepresence leave backend 2>/dev/null
telepresence leave payment-service 2>/dev/null
telepresence quit
echo "Telepresence stopped"
EOF

chmod +x scripts/stop-telepresence.sh

# Trap Ctrl+C
trap "./scripts/stop-telepresence.sh; exit 0" INT

# Keep script running
while true; do
    sleep 1
done
