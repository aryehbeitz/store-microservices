#!/bin/bash

# Local Development Manager
# Interactive menu to start/stop local frontend and backend
# URLs update dynamically based on what's running

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# State tracking
FRONTEND_RUNNING=false
BACKEND_RUNNING=false
NGROK_RUNNING=false
TELEPRESENCE_RUNNING=false
FRONTEND_PID=""
BACKEND_PID=""
PORT_FORWARD_PID=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if port is in use
check_port() {
    local port=$1
    lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1
}

# Function to start port forwarding for K8s services (MongoDB, Payment API)
# These are needed when running services locally
start_port_forward() {
    local started=false

    # Start MongoDB port forward if not running (needed for local backend)
    if ! check_port 27017; then
        echo -e "${BLUE}Starting MongoDB port forward (for local services)...${NC}"
        kubectl port-forward service/mongodb -n meetup3 27017:27017 > /dev/null 2>&1 &
        echo $! > /tmp/port-forward-mongodb.pid
        started=true
    fi

    # Start Payment API port forward if not running (needed for local backend)
    if ! check_port 8082; then
        echo -e "${BLUE}Starting Payment API port forward (for local services)...${NC}"
        kubectl port-forward service/payment-api -n meetup3 8082:8080 > /dev/null 2>&1 &
        echo $! > /tmp/port-forward-payment.pid
        started=true
    fi

    # Note: Frontend and Backend are accessed directly via K8s LoadBalancer IPs
    # No port-forwarding needed for them

    if $started; then
        sleep 2
        echo -e "${GREEN}✓ Port forwarding for K8s services started${NC}"
    fi
}

# Function to stop port forwarding
stop_port_forward() {
    for pidfile in /tmp/port-forward-*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            if ps -p $pid > /dev/null 2>&1; then
                kill $pid 2>/dev/null
            fi
            rm "$pidfile" 2>/dev/null
        fi
    done
}


# Function to start local frontend
start_frontend() {
    if $FRONTEND_RUNNING; then
        echo -e "${YELLOW}Frontend is already running${NC}"
        return
    fi

    echo -e "${BLUE}Starting local frontend...${NC}"
    cd "$(dirname "$0")/.." || exit 1

    pnpm start:frontend > /tmp/frontend-local-dev.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > /tmp/frontend-local-dev.pid

    # Wait for frontend to start (first build takes ~15 seconds)
    echo -e "${YELLOW}Building frontend... (this may take 15-20 seconds)${NC}"
    sleep 15

    # Check if it's running
    if ps -p $FRONTEND_PID > /dev/null 2>&1 && check_port 4200; then
        FRONTEND_RUNNING=true
        echo -e "${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"
        echo -e "${GREEN}✓ Available at http://localhost:4200${NC}"
    else
        echo -e "${RED}✗ Failed to start frontend${NC}"
        echo -e "${YELLOW}Check logs: tail -f /tmp/frontend-local-dev.log${NC}"
        FRONTEND_RUNNING=false
    fi
}

# Function to stop local frontend
stop_frontend() {
    if ! $FRONTEND_RUNNING; then
        echo -e "${YELLOW}Frontend is not running${NC}"
        return
    fi

    if [ -f "/tmp/frontend-local-dev.pid" ]; then
        local pid=$(cat /tmp/frontend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null
            echo -e "${GREEN}✓ Frontend stopped${NC}"
        fi
        rm /tmp/frontend-local-dev.pid 2>/dev/null
    fi

    # Also kill any process on port 4200
    lsof -ti:4200 | xargs kill -9 2>/dev/null

    FRONTEND_RUNNING=false
    FRONTEND_PID=""
}

# Function to start local backend
start_backend() {
    if $BACKEND_RUNNING; then
        echo -e "${YELLOW}Backend is already running${NC}"
        return
    fi

    echo -e "${BLUE}Starting local backend...${NC}"
    cd "$(dirname "$0")/.." || exit 1

    # Set environment variables
    export MONGODB_URI=mongodb://localhost:27017/honey-store
    export PAYMENT_SERVICE_URL=http://localhost:8082
    export CONNECTION_METHOD=port-forward
    export SERVICE_LOCATION=local

    # Build and start backend
    echo -e "${YELLOW}Building backend...${NC}"
    pnpm exec nx build backend > /tmp/backend-build.log 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Backend build failed${NC}"
        echo -e "${YELLOW}Check logs: tail -f /tmp/backend-build.log${NC}"
        return
    fi
    echo -e "${GREEN}✓ Backend built successfully${NC}"

    echo -e "${YELLOW}Starting backend...${NC}"
    node dist/apps/backend/main.js > /tmp/backend-local-dev.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > /tmp/backend-local-dev.pid

    # Wait for backend to start
    sleep 3
    if ps -p $BACKEND_PID > /dev/null 2>&1 && check_port 3000; then
        BACKEND_RUNNING=true
        echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
        echo -e "${GREEN}✓ Available at http://localhost:3000${NC}"
    else
        echo -e "${RED}✗ Failed to start backend${NC}"
        echo -e "${YELLOW}Check logs: tail -f /tmp/backend-local-dev.log${NC}"
        BACKEND_RUNNING=false
    fi
}

# Function to stop local backend
stop_backend() {
    if ! $BACKEND_RUNNING; then
        echo -e "${YELLOW}Backend is not running${NC}"
        return
    fi

    if [ -f "/tmp/backend-local-dev.pid" ]; then
        local pid=$(cat /tmp/backend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1; then
            kill $pid 2>/dev/null
            echo -e "${GREEN}✓ Backend stopped${NC}"
        fi
        rm /tmp/backend-local-dev.pid 2>/dev/null
    fi

    # Don't kill port 3000 - it might be used by something else
    # Only kill our specific backend process

    BACKEND_RUNNING=false
    BACKEND_PID=""
}

# Function to start ngrok
start_ngrok() {
    if $NGROK_RUNNING; then
        echo -e "${YELLOW}Ngrok is already running${NC}"
        return
    fi

    echo -e "${BLUE}Starting ngrok tunnel...${NC}"
    "$SCRIPT_DIR/ngrok-start.sh" > /tmp/ngrok-manager.log 2>&1 &
    sleep 5

    if pgrep -f "ngrok http" > /dev/null; then
        NGROK_RUNNING=true
        echo -e "${GREEN}✓ Ngrok started (check http://localhost:4040 for tunnel URL)${NC}"
    else
        echo -e "${RED}✗ Failed to start ngrok${NC}"
        NGROK_RUNNING=false
    fi
    sleep 2
}

# Function to stop ngrok
stop_ngrok() {
    if ! $NGROK_RUNNING; then
        echo -e "${YELLOW}Ngrok is not running${NC}"
        return
    fi

    echo -e "${BLUE}Stopping ngrok...${NC}"
    "$SCRIPT_DIR/stop-ngrok.sh" > /dev/null 2>&1
    NGROK_RUNNING=false
    echo -e "${GREEN}✓ Ngrok stopped${NC}"
    sleep 1
}

# Function to start telepresence
start_telepresence() {
    if $TELEPRESENCE_RUNNING; then
        echo -e "${YELLOW}Telepresence is already running${NC}"
        return
    fi

    echo -e "${BLUE}Starting telepresence connection...${NC}"
    telepresence connect --namespace meetup3 > /tmp/telepresence-manager.log 2>&1

    if telepresence status > /dev/null 2>&1; then
        TELEPRESENCE_RUNNING=true
        echo -e "${GREEN}✓ Telepresence connected${NC}"
        echo -e "${CYAN}Tip: You can now intercept services with 'telepresence intercept backend --port 3000:3000'${NC}"
    else
        echo -e "${RED}✗ Failed to start telepresence${NC}"
        TELEPRESENCE_RUNNING=false
    fi
    sleep 2
}

# Function to stop telepresence
stop_telepresence() {
    if ! $TELEPRESENCE_RUNNING; then
        echo -e "${YELLOW}Telepresence is not running${NC}"
        return
    fi

    echo -e "${BLUE}Stopping telepresence...${NC}"
    telepresence quit > /dev/null 2>&1
    TELEPRESENCE_RUNNING=false
    echo -e "${GREEN}✓ Telepresence stopped${NC}"
    sleep 1
}

# Function to show reset commands
reset_to_k8s() {
    clear
    echo -e "${CYAN}Reset to K8s Only:${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo -e "${YELLOW}This will show commands to stop all local services and reset to K8s-only state${NC}"
    echo ""

    local has_services=false

    if $FRONTEND_RUNNING; then
        echo -e "${CYAN}Stop Frontend:${NC}"
        echo -e "${GREEN}kill $FRONTEND_PID${NC}"
        echo ""
        has_services=true
    fi

    if $BACKEND_RUNNING; then
        echo -e "${CYAN}Stop Backend:${NC}"
        echo -e "${GREEN}kill $BACKEND_PID${NC}"
        echo ""
        has_services=true
    fi

    if $NGROK_RUNNING; then
        echo -e "${CYAN}Stop Ngrok:${NC}"
        echo -e "${GREEN}pnpm ngrok:stop${NC}"
        echo ""
        has_services=true
    fi

    if $TELEPRESENCE_RUNNING; then
        echo -e "${CYAN}Stop Telepresence:${NC}"
        echo -e "${GREEN}pnpm telepresence:stop${NC}"
        echo ""
        has_services=true
    fi

    echo -e "${CYAN}Reset Backend to Direct Connection:${NC}"
    echo -e "${GREEN}pnpm k8s:reset${NC}"
    echo ""
    echo -e "${CYAN}Or directly:${NC}"
    echo -e "${GREEN}kubectl set env deployment/backend -n meetup3 CONNECTION_METHOD=\"direct\"${NC}"
    echo -e "${GREEN}kubectl rollout restart deployment/backend -n meetup3${NC}"
    echo ""

    if ! $has_services; then
        echo -e "${YELLOW}No local services running - only need to reset backend connection${NC}"
        echo ""
    fi

    echo -e "${YELLOW}Press Enter to return...${NC}"
    read
}

# Function to check current status
check_status() {
    # Check frontend - process running is primary check, port is bonus
    if [ -f "/tmp/frontend-local-dev.pid" ]; then
        local pid=$(cat /tmp/frontend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1; then
            FRONTEND_RUNNING=true
            FRONTEND_PID=$pid
        else
            FRONTEND_RUNNING=false
            FRONTEND_PID=""
            # Clean up stale PID file
            rm -f /tmp/frontend-local-dev.pid 2>/dev/null
        fi
    else
        FRONTEND_RUNNING=false
        FRONTEND_PID=""
    fi

    # Check backend - process running is primary check, port is bonus
    if [ -f "/tmp/backend-local-dev.pid" ]; then
        local pid=$(cat /tmp/backend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1; then
            BACKEND_RUNNING=true
            BACKEND_PID=$pid
        else
            BACKEND_RUNNING=false
            BACKEND_PID=""
            # Clean up stale PID file
            rm -f /tmp/backend-local-dev.pid 2>/dev/null
        fi
    else
        BACKEND_RUNNING=false
        BACKEND_PID=""
    fi

    # Check ngrok
    if pgrep -f "ngrok http" > /dev/null; then
        NGROK_RUNNING=true
    else
        NGROK_RUNNING=false
    fi

    # Check telepresence
    if telepresence status > /dev/null 2>&1; then
        TELEPRESENCE_RUNNING=true
    else
        TELEPRESENCE_RUNNING=false
    fi
}

# Function to display URLs
display_urls() {
    clear
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Local Development Manager          ${NC}"
    echo -e "${BLUE}======================================${NC}\n"

    check_status

    # Check frontend backend configuration
    FRONTEND_BACKEND_URL=$(grep -o "backendUrl: '[^']*'" apps/frontend/src/environments/environment.ts 2>/dev/null | cut -d"'" -f2)

    echo -e "${CYAN}Local Services:${NC}"
    if $FRONTEND_RUNNING; then
        echo -e "  Frontend:     ${GREEN}● Running Locally${NC} (PID: $FRONTEND_PID)"
        if [ -n "$FRONTEND_BACKEND_URL" ]; then
            echo -e "                ${CYAN}→ Backend: $FRONTEND_BACKEND_URL${NC}"
        fi
    else
        echo -e "  Frontend:     ${YELLOW}○ Locally Stopped${NC} (running in K8s)"
        if [ -n "$FRONTEND_BACKEND_URL" ]; then
            echo -e "                ${CYAN}→ Configured for: $FRONTEND_BACKEND_URL${NC}"
        fi
    fi

    if $BACKEND_RUNNING; then
        echo -e "  Backend:      ${GREEN}● Running Locally${NC} (PID: $BACKEND_PID)"
    else
        echo -e "  Backend:      ${YELLOW}○ Locally Stopped${NC} (running in K8s)"
    fi

    echo ""
    echo -e "${CYAN}Access Methods:${NC}"
    if $NGROK_RUNNING; then
        echo -e "  Ngrok:        ${GREEN}● Active${NC} (webhooks enabled)"
    else
        echo -e "  Ngrok:        ${YELLOW}○ Inactive${NC}"
    fi

    if $TELEPRESENCE_RUNNING; then
        echo -e "  Telepresence: ${GREEN}● Connected${NC} (cluster access)"
    else
        echo -e "  Telepresence: ${YELLOW}○ Disconnected${NC}"
    fi

    echo ""
    echo -e "${CYAN}Available URLs:${NC}"

    # Frontend URLs
    if $FRONTEND_RUNNING; then
        echo -e "  ${GREEN}Frontend:        http://localhost:4200 (local)${NC}"
        echo -e "  ${GREEN}Admin Dashboard: http://localhost:4200/secret-admin-dashboard-xyz${NC}"
    else
        # Get K8s frontend URL (LoadBalancer or service)
        FRONTEND_K8S_IP=$(kubectl get svc frontend -n meetup3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$FRONTEND_K8S_IP" ]; then
            echo -e "  ${YELLOW}Frontend:        http://${FRONTEND_K8S_IP} (K8s LoadBalancer)${NC}"
            echo -e "  ${YELLOW}Admin Dashboard: http://${FRONTEND_K8S_IP}/secret-admin-dashboard-xyz${NC}"
        else
            echo -e "  ${YELLOW}Frontend:        (access via K8s service directly)${NC}"
        fi
    fi

    # Backend URLs
    if $BACKEND_RUNNING; then
        echo -e "  ${GREEN}Backend API:      http://localhost:3000 (local)${NC}"
        echo -e "  ${GREEN}Backend Health:   http://localhost:3000/health${NC}"
    else
        # Get K8s backend URL (LoadBalancer or service)
        BACKEND_K8S_IP=$(kubectl get svc backend -n meetup3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$BACKEND_K8S_IP" ]; then
            echo -e "  ${YELLOW}Backend API:      http://${BACKEND_K8S_IP}:3000 (K8s LoadBalancer)${NC}"
            echo -e "  ${YELLOW}Backend Health:   http://${BACKEND_K8S_IP}:3000/health${NC}"
        else
            echo -e "  ${YELLOW}Backend API:      (access via K8s service directly)${NC}"
        fi
    fi

    echo ""
    echo -e "${CYAN}K8s Services (port-forward for local services):${NC}"
    if check_port 27017; then
        echo -e "  ${GREEN}MongoDB:          mongodb://localhost:27017/honey-store${NC}"
    else
        echo -e "  ${YELLOW}MongoDB:          (use K8s service directly or start port-forward)${NC}"
    fi

    if check_port 8082; then
        echo -e "  ${GREEN}Payment API:      http://localhost:8082${NC}"
    else
        echo -e "  ${YELLOW}Payment API:      (use K8s service directly or start port-forward)${NC}"
    fi

    # Show ngrok URL if running
    if $NGROK_RUNNING; then
        echo ""
        echo -e "${CYAN}Ngrok Tunnel (for webhooks):${NC}"
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"https://[^"]*"' | head -1 | sed 's/"public_url":"//;s/"//')
        if [ -n "$NGROK_URL" ]; then
            echo -e "  ${GREEN}Backend:          $NGROK_URL${NC}"
            echo -e "  ${GREEN}Ngrok Inspector:  http://localhost:4040${NC}"
        else
            echo -e "  ${YELLOW}Backend:          Check http://localhost:4040 for tunnel URL${NC}"
        fi
    fi

    # Show telepresence info if running
    if $TELEPRESENCE_RUNNING; then
        echo ""
        echo -e "${CYAN}Telepresence (cluster access):${NC}"
        echo -e "  ${GREEN}Connected to:     meetup3 namespace${NC}"
        echo -e "  ${CYAN}Tip: Use 'telepresence intercept backend --port 3000:3000' to debug${NC}"
    fi

    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Menu                                ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${CYAN}1)${NC} Frontend Commands"
    echo -e "  ${CYAN}2)${NC} Backend Commands"
    echo -e "  ${CYAN}3)${NC} Ngrok Commands"
    echo -e "  ${CYAN}4)${NC} Telepresence Commands"

    echo ""
    echo -e "${CYAN}Logs:${NC}"
    echo -e "  ${CYAN}5)${NC} View Local Frontend Logs"
    echo -e "  ${CYAN}6)${NC} View Local Backend Logs"
    echo -e "  ${CYAN}7)${NC} View K8s Frontend Logs"
    echo -e "  ${CYAN}8)${NC} View K8s Backend Logs"

    echo ""
    echo -e "${CYAN}Tools:${NC}"
    echo -e "  ${BLUE}9)${NC} Reset to K8s Only"

    echo ""
    echo -e "${CYAN}Exit:${NC}"
    echo -e "  ${YELLOW}10)${NC} Exit (refresh status)"
    echo ""
    echo -e "${YELLOW}Select (1-10) or 'r' to refresh:${NC} "
}

# Exit handler
exit_script() {
    echo -e "\n${YELLOW}Exiting...${NC}"
    exit 0
}

trap exit_script INT TERM

# Initialize port forwarding for K8s services (MongoDB, Payment API)
# These are needed when running services locally
start_port_forward

# Check current status
check_status

# Main loop
while true; do
    display_urls
    read -r choice

    case $choice in
        1)
            clear
            echo -e "${CYAN}Frontend Commands:${NC}"
            echo -e "${BLUE}======================================${NC}"
            echo ""
            if $FRONTEND_RUNNING; then
                echo -e "${YELLOW}Frontend is currently running (PID: $FRONTEND_PID)${NC}"
                echo ""
                echo -e "${CYAN}To stop:${NC}"
                echo -e "${GREEN}kill $FRONTEND_PID${NC}"
                echo ""
                echo -e "${CYAN}To view logs:${NC}"
                echo -e "${GREEN}tail -f /tmp/frontend-local-dev.log${NC}"
            else
                echo -e "${YELLOW}Frontend is not running locally${NC}"
                echo ""
                echo -e "${CYAN}Configure backend target:${NC}"
                echo -e "${GREEN}pnpm frontend:use-local${NC}      # Use local backend (localhost:3000)"
                echo -e "${GREEN}pnpm frontend:use-k8s${NC}        # Use K8s backend (port-forward)"
                echo ""
                echo -e "${CYAN}Then start:${NC}"
                echo -e "${GREEN}pnpm start:frontend${NC}"
                echo ""
                echo -e "${CYAN}In background with logging:${NC}"
                echo -e "${GREEN}pnpm start:frontend > /tmp/frontend-local-dev.log 2>&1 &${NC}"
                echo -e "${GREEN}echo \$! > /tmp/frontend-local-dev.pid${NC}"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        2)
            clear
            echo -e "${CYAN}Backend Commands:${NC}"
            echo -e "${BLUE}======================================${NC}"
            echo ""
            if $BACKEND_RUNNING; then
                echo -e "${YELLOW}Backend is currently running (PID: $BACKEND_PID)${NC}"
                echo ""
                echo -e "${CYAN}To stop:${NC}"
                echo -e "${GREEN}kill $BACKEND_PID${NC}"
                echo ""
                echo -e "${CYAN}To view logs:${NC}"
                echo -e "${GREEN}tail -f /tmp/backend-local-dev.log${NC}"
            else
                echo -e "${YELLOW}Backend is not running locally${NC}"
                echo ""
                echo -e "${CYAN}Set environment variables:${NC}"
                echo -e "${GREEN}export MONGODB_URI=mongodb://localhost:27017/honey-store${NC}"
                echo -e "${GREEN}export PAYMENT_SERVICE_URL=http://localhost:8082${NC}"
                echo -e "${GREEN}export CONNECTION_METHOD=port-forward${NC}"
                echo -e "${GREEN}export SERVICE_LOCATION=local${NC}"
                echo ""
                echo -e "${CYAN}Then start:${NC}"
                echo -e "${GREEN}pnpm start:backend${NC}"
                echo ""
                echo -e "${CYAN}In background with logging:${NC}"
                echo -e "${GREEN}pnpm start:backend > /tmp/backend-local-dev.log 2>&1 &${NC}"
                echo ""
                echo -e "${CYAN}Then save PID:${NC}"
                echo -e "${GREEN}echo \$! > /tmp/backend-local-dev.pid${NC}"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        3)
            clear
            echo -e "${CYAN}Ngrok Commands:${NC}"
            echo -e "${BLUE}======================================${NC}"
            echo ""
            if $NGROK_RUNNING; then
                echo -e "${YELLOW}Ngrok is currently running${NC}"
                echo ""
                echo -e "${CYAN}To stop:${NC}"
                echo -e "${GREEN}pnpm ngrok:stop${NC}"
                echo -e "${CYAN}Or directly:${NC}"
                echo -e "${GREEN}./scripts/stop-ngrok.sh${NC}"
                echo ""
                echo -e "${CYAN}To view tunnel URL:${NC}"
                echo -e "${GREEN}curl -s http://localhost:4040/api/tunnels | jq '.tunnels[0].public_url'${NC}"
                echo ""
                echo -e "${CYAN}Ngrok Inspector:${NC}"
                echo -e "${GREEN}open http://localhost:4040${NC}"
            else
                echo -e "${YELLOW}Ngrok is not running${NC}"
                echo ""
                echo -e "${CYAN}To start:${NC}"
                echo -e "${GREEN}pnpm ngrok:start${NC}"
                echo ""
                echo -e "${CYAN}What it does:${NC}"
                echo -e "  • Creates public HTTPS tunnel to backend"
                echo -e "  • Enables webhook testing"
                echo -e "  • Updates backend deployment with ngrok URL"
                echo -e "  • Provides inspector at http://localhost:4040"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        4)
            clear
            echo -e "${CYAN}Telepresence Commands:${NC}"
            echo -e "${BLUE}======================================${NC}"
            echo ""
            if $TELEPRESENCE_RUNNING; then
                echo -e "${YELLOW}Telepresence is currently connected${NC}"
                echo ""
                echo -e "${CYAN}To disconnect:${NC}"
                echo -e "${GREEN}pnpm telepresence:stop${NC}"
                echo -e "${CYAN}Or directly:${NC}"
                echo -e "${GREEN}telepresence quit${NC}"
                echo ""
                echo -e "${CYAN}To intercept backend (for debugging):${NC}"
                echo -e "${GREEN}telepresence intercept backend --port 3000:3000${NC}"
                echo ""
                echo -e "${CYAN}Then run backend locally:${NC}"
                echo -e "${GREEN}export MONGODB_URI=mongodb://mongodb.meetup3.svc.cluster.local:27017/honey-store${NC}"
                echo -e "${GREEN}export PAYMENT_SERVICE_URL=http://payment-api.meetup3.svc.cluster.local:8080${NC}"
                echo -e "${GREEN}pnpm start:backend${NC}"
                echo ""
                echo -e "${CYAN}To check status:${NC}"
                echo -e "${GREEN}telepresence status${NC}"
            else
                echo -e "${YELLOW}Telepresence is not connected${NC}"
                echo ""
                echo -e "${CYAN}To connect:${NC}"
                echo -e "${GREEN}pnpm telepresence:start${NC}"
                echo ""
                echo -e "${CYAN}Or directly:${NC}"
                echo -e "${GREEN}telepresence connect --namespace meetup3${NC}"
                echo ""
                echo -e "${CYAN}What it does:${NC}"
                echo -e "  • Connects your machine to K8s cluster"
                echo -e "  • Enables direct access to cluster services"
                echo -e "  • Allows intercepting services for local debugging"
                echo -e "  • Full cluster DNS resolution"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        5)
            clear
            echo -e "${CYAN}Local Frontend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            if [ -f "/tmp/frontend-local-dev.log" ]; then
                tail -20 /tmp/frontend-local-dev.log
            else
                echo -e "${YELLOW}No local frontend logs available (service not started locally)${NC}"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        6)
            clear
            echo -e "${CYAN}Local Backend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            if [ -f "/tmp/backend-local-dev.log" ]; then
                tail -20 /tmp/backend-local-dev.log
            else
                echo -e "${YELLOW}No local backend logs available (service not started locally)${NC}"
            fi
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        7)
            clear
            echo -e "${CYAN}K8s Frontend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            kubectl logs -n meetup3 -l app=frontend --tail=20 2>/dev/null || echo -e "${RED}Failed to fetch K8s frontend logs${NC}"
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        8)
            clear
            echo -e "${CYAN}K8s Backend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            kubectl logs -n meetup3 -l app=backend -c backend --tail=20 2>/dev/null || echo -e "${RED}Failed to fetch K8s backend logs${NC}"
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        9)
            reset_to_k8s
            ;;
        10)
            # Just refresh and continue
            ;;
        r|R)
            # Just refresh
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 1
            ;;
    esac
done

