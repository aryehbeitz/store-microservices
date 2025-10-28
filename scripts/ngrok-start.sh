#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Ngrok Tunnel Setup                 ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Check if ngrok is installed
if ! command -v ngrok &> /dev/null; then
    echo -e "${RED}Ngrok is not installed!${NC}"
    echo "Please install ngrok from https://ngrok.com/download"
    echo "Or use: brew install ngrok (macOS) / snap install ngrok (Linux)"
    exit 1
fi

# Check if ngrok is authenticated
if ! ngrok config check &> /dev/null; then
    echo -e "${YELLOW}Ngrok is not authenticated.${NC}"
    echo "Please run: ngrok authtoken YOUR_AUTH_TOKEN"
    echo "Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
fi

echo "Starting port forwards first..."
# Kill any existing port forwards
./scripts/stop-port-forward.sh 2>/dev/null

# Start port forwards in background
kubectl port-forward service/backend 3000:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!
echo $BACKEND_PF_PID > /tmp/port-forward-backend.pid

kubectl port-forward service/payment-service 3002:3002 > /dev/null 2>&1 &
PAYMENT_PF_PID=$!
echo $PAYMENT_PF_PID > /tmp/port-forward-payment-service.pid

kubectl port-forward service/frontend 8080:80 > /dev/null 2>&1 &
FRONTEND_PF_PID=$!
echo $FRONTEND_PF_PID > /tmp/port-forward-frontend.pid

sleep 3

echo -e "${GREEN}✓ Port forwards established${NC}\n"

# Create ngrok configuration
cat > /tmp/ngrok-honey-store.yml << EOF
version: "2"
authtoken: $(ngrok config get-authtoken)
tunnels:
  backend:
    proto: http
    addr: 3000
  payment:
    proto: http
    addr: 3002
  frontend:
    proto: http
    addr: 8080
EOF

echo "Starting ngrok tunnels..."
ngrok start --all --config /tmp/ngrok-honey-store.yml > /tmp/ngrok-output.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > /tmp/ngrok.pid

sleep 5

echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}  Ngrok Tunnel URLs                  ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Get tunnel URLs from ngrok API
if command -v curl &> /dev/null; then
    TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$TUNNELS" ]; then
        echo "$TUNNELS" | grep -o '"public_url":"[^"]*"' | while read -r line; do
            url=$(echo $line | sed 's/"public_url":"//;s/"//')
            if [[ $url == *"backend"* ]]; then
                echo -e "${GREEN}Backend:         $url${NC}"
            elif [[ $url == *"payment"* ]]; then
                echo -e "${GREEN}Payment Service: $url${NC}"
            elif [[ $url == *"frontend"* ]]; then
                echo -e "${GREEN}Frontend:        $url${NC}"
            else
                echo -e "${GREEN}Tunnel:          $url${NC}"
            fi
        done

        echo -e "\n${YELLOW}Ngrok Web Interface: http://localhost:4040${NC}"
    else
        echo -e "${YELLOW}Could not fetch tunnel URLs from ngrok API${NC}"
        echo -e "${YELLOW}Check ngrok web interface at: http://localhost:4040${NC}"
    fi
else
    echo -e "${YELLOW}Please check ngrok web interface at: http://localhost:4040${NC}"
fi

echo -e "\n${BLUE}======================================${NC}"
echo -e "${YELLOW}Note: Tunnels are running in the background${NC}"
echo -e "${YELLOW}To stop them, run: ./scripts/stop-ngrok.sh${NC}"
echo -e "\n${BLUE}Press Ctrl+C to stop all ngrok tunnels${NC}"

# Create stop script
cat > scripts/stop-ngrok.sh << 'EOF'
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
EOF

chmod +x scripts/stop-ngrok.sh

# Trap Ctrl+C
trap "./scripts/stop-ngrok.sh; exit 0" INT

# Keep script running
while true; do
    sleep 1
done
