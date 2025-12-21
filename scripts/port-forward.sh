#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Port Forwarding for Frontend Dev  ${NC}"
echo -e "${BLUE}======================================${NC}\n"

echo -e "${YELLOW}This setup allows:${NC}"
echo -e "  • Frontend runs locally (live code changes!)"
echo -e "  • Backend runs in K8s (accessed via port forwarding)"
echo -e "  • Perfect for frontend development"
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
        "frontend")
            target_port=80
            ;;
        "backend")
            target_port=3000
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

echo "Setting up port forwards for all services..."
echo -e "${YELLOW}Note: Using namespace 'meetup3'${NC}"
echo ""

# Start port forward for backend only (frontend runs locally)
start_port_forward "backend" "3000" "Backend"
start_port_forward "payment-api" "8082" "Payment API"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Service URLs                       ${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Backend (K8s):    http://localhost:3000${NC}"
echo -e "${GREEN}Payment API:      http://localhost:8082${NC}"
echo ""
echo -e "${YELLOW}Frontend will run locally (see next steps)${NC}"
echo ""

# Set PAYMENT_SERVICE_URL for backend
# Backend runs in cluster, so use cluster service name (not localhost)
PAYMENT_SERVICE_URL="http://payment-api:8080"
echo -e "${YELLOW}Setting PAYMENT_SERVICE_URL to http://payment-api:8080 (cluster service)...${NC}"

# Update backend to use direct connection method and payment service URL
echo -e "\n${YELLOW}Updating backend environment variables...${NC}"
kubectl set env deployment/backend -n meetup3 CONNECTION_METHOD="direct" PAYMENT_SERVICE_URL="$PAYMENT_SERVICE_URL"
echo -e "${GREEN}✓ Backend environment updated${NC}"

# Restart backend to pick up new environment variables
echo -e "\n${YELLOW}Restarting backend to pick up new environment variables...${NC}"
kubectl rollout restart deployment/backend -n meetup3
echo -e "${GREEN}✓ Backend restarted successfully${NC}"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Next Steps: Start Local Frontend   ${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${YELLOW}In a new terminal, run:${NC}"
echo ""
echo "cd apps/frontend"
echo ""
echo -e "${YELLOW}Make sure environment.ts points to:${NC}"
echo "export const environment = {"
echo "  production: false,"
echo "  backendUrl: 'http://localhost:3000'  // Backend via port forwarding"
echo "};"
echo ""
echo -e "${YELLOW}Then start the frontend:${NC}"
echo "pnpm start:frontend"
echo ""
echo -e "${GREEN}✓ Frontend will run locally with live code changes!${NC}"
echo -e "${GREEN}✓ Backend accessed via port forwarding (http://localhost:3000)${NC}"
echo ""

echo ""
echo -e "${YELLOW}Note: Port forwarding processes are running in the background${NC}"
echo -e "${YELLOW}To stop them, run: ./scripts/stop-port-forward.sh${NC}"
echo ""

# Create stop script
cat > scripts/stop-port-forward.sh << 'EOF'
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
EOF

chmod +x scripts/stop-port-forward.sh

# Keep script running
echo -e "${BLUE}Press Ctrl+C to stop all port forwards${NC}"
trap "bash scripts/stop-port-forward.sh; exit 0" INT

# Wait indefinitely
while true; do
    sleep 1
done
