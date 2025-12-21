#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Port Forwarding + Local Dev (All)  ${NC}"
echo -e "${BLUE}======================================${NC}\n"

echo -e "${YELLOW}This setup allows:${NC}"
echo -e "  • Frontend runs locally (live code changes!)"
echo -e "  • Backend runs locally (live code changes!)"
echo -e "  • Port forwarding connects to K8s services (MongoDB, Payment API)"
echo -e "  • Perfect for full-stack development"
echo ""

# Function to check if port forwarding is already running
check_port_forward() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start port forwarding in background
start_port_forward() {
    local service=$1
    local port=$2
    local display_name=$3

    echo -e "${BLUE}Starting port forward for ${display_name}...${NC}"

    if check_port_forward $port; then
        echo -e "${YELLOW}Port $port already in use. Killing existing process...${NC}"
        lsof -ti:$port | xargs kill -9 2>/dev/null
        sleep 1
    fi

    # Get the target port from the service
    local target_port
    case $service in
        "mongodb")
            target_port=27017
            ;;
        "payment-api")
            target_port=8080
            ;;
        *)
            target_port=$port
            ;;
    esac

    kubectl port-forward service/$service -n meetup3 $port:$target_port > /dev/null 2>&1 &
    local pid=$!

    sleep 2

    if ps -p $pid > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ${display_name} available at http://localhost:$port${NC}"
        echo $pid > /tmp/port-forward-$service.pid
    else
        echo -e "${RED}✗ Failed to start port forward for ${display_name}${NC}"
    fi
}

echo "Setting up port forwards for K8s services..."
echo -e "${YELLOW}Note: Using namespace 'meetup3'${NC}"
echo ""

# Start port forwards for services the local apps need
start_port_forward "mongodb" "27017" "MongoDB"
start_port_forward "payment-api" "8082" "Payment API"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Service URLs                       ${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}MongoDB:          mongodb://localhost:27017/honey-store${NC}"
echo -e "${GREEN}Payment API:      http://localhost:8082${NC}"
echo ""

# Check if backend LoadBalancer exists for webhooks
BACKEND_LB_IP=$(kubectl get svc backend -n meetup3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -n "$BACKEND_LB_IP" ]; then
    BACKEND_PUBLIC_URL="http://${BACKEND_LB_IP}:3000"
    echo -e "${GREEN}Backend LoadBalancer: $BACKEND_PUBLIC_URL${NC}"
    echo -e "${YELLOW}Webhooks will work via LoadBalancer!${NC}"
else
    echo -e "${YELLOW}No Backend LoadBalancer found.${NC}"
    echo -e "${YELLOW}For webhooks, you can use ngrok for webhook endpoint only${NC}"
    BACKEND_PUBLIC_URL=""
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Next Steps: Start Local Services  ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${YELLOW}Terminal 1 - Backend:${NC}"
echo "cd apps/backend"
echo ""
echo -e "${YELLOW}Set environment variables:${NC}"
echo "export MONGODB_URI=mongodb://localhost:27017/honey-store"
echo "export PAYMENT_SERVICE_URL=http://localhost:8082"
if [ -n "$BACKEND_PUBLIC_URL" ]; then
    echo "export BACKEND_PUBLIC_URL=$BACKEND_PUBLIC_URL"
else
    echo "# export BACKEND_PUBLIC_URL=<ngrok-url>  # Optional: for webhooks"
fi
echo "export CONNECTION_METHOD=port-forward"
echo "export SERVICE_LOCATION=local"
echo ""
echo -e "${YELLOW}Then start the backend:${NC}"
echo "# Option 1: Build and run (manual rebuild needed for changes)"
echo "npx nx build backend && node dist/apps/backend/main.js"
echo ""
echo "# Option 2: Use nodemon for auto-reload (install: npm install -g nodemon)"
echo "npx nx build backend && nodemon dist/apps/backend/main.js"
echo ""
echo -e "${YELLOW}Terminal 2 - Frontend:${NC}"
echo "cd apps/frontend"
echo ""
echo -e "${YELLOW}Make sure environment.ts points to:${NC}"
echo "export const environment = {"
echo "  production: false,"
echo "  backendUrl: 'http://localhost:3000'  // Local backend"
echo "};"
echo ""
echo -e "${YELLOW}Then start the frontend:${NC}"
echo "npm run start:frontend"
echo ""
echo -e "${GREEN}✓ Both services will run locally with live code changes!${NC}"
echo -e "${GREEN}✓ Port forwarding connects to K8s services${NC}"
if [ -n "$BACKEND_PUBLIC_URL" ]; then
    echo -e "${GREEN}✓ Webhooks will work via LoadBalancer${NC}"
else
    echo -e "${YELLOW}⚠ Webhooks may not work (use ngrok if needed)${NC}"
fi
echo ""

# Create stop script
cat > scripts/stop-port-forward-local-all.sh << 'EOF'
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
echo "Note: Stop your local frontend and backend processes separately (Ctrl+C in those terminals)"
EOF

chmod +x scripts/stop-port-forward-local-all.sh

echo -e "${YELLOW}Note: Port forwarding processes are running in the background${NC}"
echo -e "${YELLOW}To stop them, run: ./scripts/stop-port-forward-local-all.sh${NC}"
echo ""

# Keep script running
echo -e "${BLUE}Press Ctrl+C to stop all port forwards${NC}"
trap "bash scripts/stop-port-forward-local-all.sh; exit 0" INT

# Wait indefinitely
while true; do
    sleep 1
done

