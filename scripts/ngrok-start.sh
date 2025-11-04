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

echo "Starting port forwards for all services..."
# Kill any existing port forwards
./scripts/stop-port-forward.sh 2>/dev/null

# Start port forwards for backend and frontend
kubectl port-forward service/backend 3000:3000 > /dev/null 2>&1 &
BACKEND_PF_PID=$!
echo $BACKEND_PF_PID > /tmp/port-forward-backend.pid

kubectl port-forward service/frontend 8080:80 > /dev/null 2>&1 &
FRONTEND_PF_PID=$!
echo $FRONTEND_PF_PID > /tmp/port-forward-frontend.pid

sleep 3

echo -e "${GREEN}✓ Port forwards established for all services${NC}\n"

echo -e "${YELLOW}Starting ngrok tunnel for backend (webhook receiver)...${NC}"
echo -e "${YELLOW}Note: Backend needs ngrok to receive payment webhooks${NC}"

# Start ngrok for backend (webhook receiver)
ngrok http 3000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!
echo $NGROK_PID > /tmp/ngrok.pid

# Wait for ngrok to start up
echo "Waiting for ngrok to start..."
sleep 5

echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}  Ngrok Tunnel URLs                  ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Get tunnel URL from ngrok API
if command -v curl &> /dev/null; then
    # Try multiple times to get the tunnel URL
    for i in {1..5}; do
        TUNNELS=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$TUNNELS" ] && [ "$TUNNELS" != "null" ]; then
            # Try jq first, fallback to grep/sed
            if command -v jq &> /dev/null; then
                BACKEND_URL=$(echo "$TUNNELS" | jq -r '.tunnels[0].public_url' 2>/dev/null)
                if [ -n "$BACKEND_URL" ] && [ "$BACKEND_URL" != "null" ]; then
                    echo -e "${GREEN}Backend (Ngrok):  $BACKEND_URL${NC}"
                    echo -e "${GREEN}Frontend (Local): http://localhost:8080${NC}"
                    echo -e "\n${YELLOW}Webhook Demo: Orders will update in real-time!${NC}"
                    echo -e "${YELLOW}The backend can receive webhooks via the ngrok URL${NC}"

                    # Update backend to know ngrok is available and set public URL
                    echo -e "\n${YELLOW}Updating backend to know ngrok is available...${NC}"
                    kubectl set env deployment/backend CONNECTION_METHOD="ngrok" BACKEND_PUBLIC_URL="$BACKEND_URL"
                    echo -e "${GREEN}✓ Backend environment updated${NC}"

                    # Restart backend to pick up new environment variables
                    echo -e "\n${YELLOW}Restarting backend to pick up new environment variables...${NC}"
                    kubectl rollout restart deployment/backend
                    echo -e "${GREEN}✓ Backend restarted successfully${NC}"

                    # Note about payment service URL
                    echo -e "\n${YELLOW}Note: Set PAYMENT_SERVICE_URL environment variable to point to your payment service${NC}"
                    echo -e "${YELLOW}Example: export PAYMENT_SERVICE_URL=http://your-payment-service:8080${NC}"
                else
                    echo -e "${YELLOW}Could not extract backend URL${NC}"
                fi
            else
                # Fallback without jq
                BACKEND_URL=$(echo "$TUNNELS" | grep -o '"public_url":"[^"]*"' | head -1 | sed 's/"public_url":"//;s/"//')
                if [ -n "$BACKEND_URL" ]; then
                    echo -e "${GREEN}Backend (Ngrok):  $BACKEND_URL${NC}"
                    echo -e "${GREEN}Frontend (Local): http://localhost:8080${NC}"
                    echo -e "\n${YELLOW}Webhook Demo: Orders will update in real-time!${NC}"
                    echo -e "${YELLOW}The backend can receive webhooks via the ngrok URL${NC}"

                    # Update backend to know ngrok is available and set public URL
                    echo -e "\n${YELLOW}Updating backend to know ngrok is available...${NC}"
                    kubectl set env deployment/backend CONNECTION_METHOD="ngrok" BACKEND_PUBLIC_URL="$BACKEND_URL"
                    echo -e "${GREEN}✓ Backend environment updated${NC}"

                    # Restart backend to pick up new environment variables
                    echo -e "\n${YELLOW}Restarting backend to pick up new environment variables...${NC}"
                    kubectl rollout restart deployment/backend
                    echo -e "${GREEN}✓ Backend restarted successfully${NC}"

                    # Note about payment service URL
                    echo -e "\n${YELLOW}Note: Set PAYMENT_SERVICE_URL environment variable to point to your payment service${NC}"
                    echo -e "${YELLOW}Example: export PAYMENT_SERVICE_URL=http://your-payment-service:8080${NC}"
                else
                    echo -e "${YELLOW}Could not extract backend URL${NC}"
                fi
            fi

            echo -e "\n${YELLOW}Ngrok Web Interface: http://localhost:4040${NC}"
            break
        else
            if [ $i -lt 5 ]; then
                echo "Attempt $i failed, retrying in 2 seconds..."
                sleep 2
            else
                echo -e "${YELLOW}Could not fetch tunnel URLs from ngrok API${NC}"
                echo -e "${YELLOW}Check ngrok web interface at: http://localhost:4040${NC}"
                echo -e "${YELLOW}Raw response: $TUNNELS${NC}"
            fi
        fi
    done
else
    echo -e "${YELLOW}Please check ngrok web interface at: http://localhost:4040${NC}"
fi

echo -e "\n${BLUE}======================================${NC}"
echo -e "${YELLOW}Note: Backend tunnel is running in the background${NC}"
echo -e "${YELLOW}To stop it, run: ./scripts/stop-ngrok.sh${NC}"
echo -e "\n${BLUE}Press Ctrl+C to stop ngrok tunnel${NC}"

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
