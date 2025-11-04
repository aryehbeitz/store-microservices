#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Port Forwarding Setup              ${NC}"
echo -e "${BLUE}======================================${NC}\n"

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
        *)
            target_port=$port
            ;;
    esac

    kubectl port-forward service/$service $port:$target_port > /dev/null 2>&1 &
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
echo ""

# Start port forwards
start_port_forward "backend" "3000" "Backend"
start_port_forward "frontend" "8080" "Frontend"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Service URLs                       ${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}Frontend:        http://localhost:8080${NC}"
echo -e "${GREEN}Backend:         http://localhost:3000${NC}"
echo -e "${GREEN}Admin Dashboard: http://localhost:8080/secret-admin-dashboard-xyz${NC}"
echo ""
echo -e "${YELLOW}Note: Set PAYMENT_SERVICE_URL environment variable to point to your payment service${NC}"
echo -e "${YELLOW}Example: export PAYMENT_SERVICE_URL=http://your-payment-service:8080${NC}"
echo ""

# Update backend to use direct connection method
echo -e "\n${YELLOW}Updating backend to use direct connection method...${NC}"
kubectl set env deployment/backend CONNECTION_METHOD="direct"
echo -e "${GREEN}✓ Backend environment updated to direct mode${NC}"

# Restart backend to pick up new environment variables
echo -e "\n${YELLOW}Restarting backend to pick up new environment variables...${NC}"
kubectl rollout restart deployment/backend
echo -e "${GREEN}✓ Backend restarted successfully${NC}"

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
