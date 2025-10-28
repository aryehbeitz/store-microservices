#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Honey Store - Watch Mode            ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Function to get version from package.json
get_version() {
    local service=$1
    local package_json="apps/$service/package.json"
    if [ -f "$package_json" ]; then
        node -p "require('./$package_json').version" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Function to build and deploy a specific service
deploy_service() {
    local service=$1
    local timestamp=$(date +%Y%m%d-%H%M%S)

    echo -e "${YELLOW}🔄 Building and deploying $service...${NC}"

    # Build Docker image
    docker build -t honey-store/$service:$timestamp -t honey-store/$service:latest -f apps/$service/Dockerfile . > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Docker image built for $service${NC}"

        # Deploy to Kubernetes
        case $service in
            "frontend")
                kubectl set image deployment/frontend frontend=honey-store/frontend:$timestamp > /dev/null 2>&1
                kubectl rollout status deployment/frontend --timeout=60s > /dev/null 2>&1
                ;;
            "backend")
                kubectl set image deployment/backend backend=honey-store/backend:$timestamp > /dev/null 2>&1
                kubectl rollout status deployment/backend --timeout=60s > /dev/null 2>&1
                ;;
            "payment-service")
                kubectl set image deployment/payment-service payment-service=honey-store/payment-service:$timestamp > /dev/null 2>&1
                kubectl rollout status deployment/payment-service --timeout=60s > /dev/null 2>&1
                ;;
        esac

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $service deployed successfully${NC}"

            # If it's frontend, show notification info
            if [ "$service" = "frontend" ]; then
                echo -e "${YELLOW}📱 Frontend updated! Check browser for reload notification${NC}"
            fi
        else
            echo -e "${RED}✗ Failed to deploy $service${NC}"
        fi
    else
        echo -e "${RED}✗ Failed to build $service${NC}"
    fi
}

# Function to show notification in browser (if possible)
show_notification() {
    local service=$1
    local version=$2

    # Try to send a simple HTTP request to trigger frontend notification
    # This is a simple approach - in a real app you'd use WebSockets or Server-Sent Events
    curl -s "http://localhost:3000/api/version-update" \
        -H "Content-Type: application/json" \
        -d "{\"service\":\"$service\",\"version\":\"$version\"}" > /dev/null 2>&1 || true
}

# Initialize version tracking
frontend_version=$(get_version frontend)
backend_version=$(get_version backend)
payment_version=$(get_version payment-service)

echo -e "${YELLOW}Initial versions:${NC}"
echo -e "  Frontend: ${frontend_version}"
echo -e "  Backend: ${backend_version}"
echo -e "  Payment Service: ${payment_version}"
echo -e "\n${YELLOW}Watching for version changes...${NC}"
echo -e "${YELLOW}Use 'npm run version:<service>' to bump versions${NC}\n"

# Watch loop
while true; do
    sleep 2

    # Check frontend for version changes
    current_frontend=$(get_version frontend)
    if [ "$current_frontend" != "$frontend_version" ] && [ "$current_frontend" != "unknown" ]; then
        echo -e "${GREEN}🚀 Version change detected for frontend: $frontend_version → $current_frontend${NC}"
        frontend_version=$current_frontend
        deploy_service frontend
        show_notification frontend $current_frontend
        echo -e "${YELLOW}Continuing to watch...${NC}\n"
    fi

    # Check backend for version changes
    current_backend=$(get_version backend)
    if [ "$current_backend" != "$backend_version" ] && [ "$current_backend" != "unknown" ]; then
        echo -e "${GREEN}🚀 Version change detected for backend: $backend_version → $current_backend${NC}"
        backend_version=$current_backend
        deploy_service backend
        show_notification backend $current_backend
        echo -e "${YELLOW}Continuing to watch...${NC}\n"
    fi

    # Check payment-service for version changes
    current_payment=$(get_version payment-service)
    if [ "$current_payment" != "$payment_version" ] && [ "$current_payment" != "unknown" ]; then
        echo -e "${GREEN}🚀 Version change detected for payment-service: $payment_version → $current_payment${NC}"
        payment_version=$current_payment
        deploy_service payment-service
        show_notification payment-service $current_payment
        echo -e "${YELLOW}Continuing to watch...${NC}\n"
    fi
done
