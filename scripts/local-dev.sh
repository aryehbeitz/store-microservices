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
FRONTEND_PID=""
BACKEND_PID=""
PORT_FORWARD_PID=""

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

    npm run start:frontend > /tmp/frontend-local-dev.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > /tmp/frontend-local-dev.pid

    # Wait for frontend to start
    sleep 5
    if ps -p $FRONTEND_PID > /dev/null 2>&1 && check_port 4200; then
        FRONTEND_RUNNING=true
        echo -e "${GREEN}✓ Frontend started (PID: $FRONTEND_PID)${NC}"
    else
        echo -e "${RED}✗ Failed to start frontend${NC}"
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
    npx nx build backend > /tmp/backend-build.log 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Backend build failed. Check /tmp/backend-build.log${NC}"
        return
    fi

    node dist/apps/backend/main.js > /tmp/backend-local-dev.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > /tmp/backend-local-dev.pid

    # Wait for backend to start
    sleep 3
    if ps -p $BACKEND_PID > /dev/null 2>&1 && check_port 3000; then
        BACKEND_RUNNING=true
        echo -e "${GREEN}✓ Backend started (PID: $BACKEND_PID)${NC}"
    else
        echo -e "${RED}✗ Failed to start backend. Check /tmp/backend-local-dev.log${NC}"
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

# Function to check current status
check_status() {
    # Check frontend
    if [ -f "/tmp/frontend-local-dev.pid" ]; then
        local pid=$(cat /tmp/frontend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1 && check_port 4200; then
            FRONTEND_RUNNING=true
            FRONTEND_PID=$pid
        else
            FRONTEND_RUNNING=false
            FRONTEND_PID=""
        fi
    else
        FRONTEND_RUNNING=false
        FRONTEND_PID=""
    fi

    # Check backend
    if [ -f "/tmp/backend-local-dev.pid" ]; then
        local pid=$(cat /tmp/backend-local-dev.pid)
        if ps -p $pid > /dev/null 2>&1 && check_port 3000; then
            BACKEND_RUNNING=true
            BACKEND_PID=$pid
        else
            BACKEND_RUNNING=false
            BACKEND_PID=""
        fi
    else
        BACKEND_RUNNING=false
        BACKEND_PID=""
    fi
}

# Function to display URLs
display_urls() {
    clear
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Local Development Manager          ${NC}"
    echo -e "${BLUE}======================================${NC}\n"

    check_status

    echo -e "${CYAN}Service Status:${NC}"
    if $FRONTEND_RUNNING; then
        echo -e "  Frontend: ${GREEN}● Running${NC} (PID: $FRONTEND_PID)"
    else
        echo -e "  Frontend: ${RED}○ Stopped${NC}"
    fi

    if $BACKEND_RUNNING; then
        echo -e "  Backend:  ${GREEN}● Running${NC} (PID: $BACKEND_PID)"
    else
        echo -e "  Backend:  ${RED}○ Stopped${NC}"
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

    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}  Menu                                ${NC}"
    echo -e "${BLUE}======================================${NC}"
    echo ""
    if $FRONTEND_RUNNING; then
        echo -e "  ${YELLOW}1)${NC} Stop Frontend"
    else
        echo -e "  ${GREEN}1)${NC} Start Frontend"
    fi

    if $BACKEND_RUNNING; then
        echo -e "  ${YELLOW}2)${NC} Stop Backend"
    else
        echo -e "  ${GREEN}2)${NC} Start Backend"
    fi

    echo -e "  ${CYAN}3)${NC} View Frontend Logs"
    echo -e "  ${CYAN}4)${NC} View Backend Logs"
    echo -e "  ${CYAN}5)${NC} Rebuild Backend"
    echo -e "  ${RED}6)${NC} Stop All & Exit"
    echo ""
    echo -e "${YELLOW}Select option (1-6) or 'r' to refresh:${NC} "
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Cleaning up...${NC}"
    stop_frontend
    stop_backend
    stop_port_forward
    exit 0
}

trap cleanup INT TERM

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
            if $FRONTEND_RUNNING; then
                stop_frontend
            else
                start_frontend
            fi
            sleep 1
            ;;
        2)
            if $BACKEND_RUNNING; then
                stop_backend
            else
                start_backend
            fi
            sleep 1
            ;;
        3)
            clear
            echo -e "${CYAN}Frontend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            tail -20 /tmp/frontend-local-dev.log 2>/dev/null || echo "No logs available"
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        4)
            clear
            echo -e "${CYAN}Backend Logs (last 20 lines):${NC}"
            echo -e "${BLUE}======================================${NC}"
            tail -20 /tmp/backend-local-dev.log 2>/dev/null || echo "No logs available"
            echo ""
            echo -e "${YELLOW}Press Enter to return...${NC}"
            read
            ;;
        5)
            echo -e "${BLUE}Rebuilding backend...${NC}"
            cd "$(dirname "$0")/.." || exit 1
            npx nx build backend > /tmp/backend-build.log 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Backend rebuilt successfully${NC}"
                if $BACKEND_RUNNING; then
                    echo -e "${YELLOW}Restarting backend...${NC}"
                    stop_backend
                    sleep 1
                    start_backend
                fi
            else
                echo -e "${RED}✗ Build failed. Check /tmp/backend-build.log${NC}"
            fi
            sleep 2
            ;;
        6)
            cleanup
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

