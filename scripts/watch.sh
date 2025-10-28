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
declare -A versions
versions[frontend]=$(get_version frontend)
versions[backend]=$(get_version backend)
versions[payment-service]=$(get_version payment-service)

echo -e "${YELLOW}Initial versions:${NC}"
echo -e "  Frontend: ${versions[frontend]}"
echo -e "  Backend: ${versions[backend]}"
echo -e "  Payment Service: ${versions[payment-service]}"
echo -e "\n${YELLOW}Watching for version changes...${NC}"
echo -e "${YELLOW}Use 'npm run version:<service>' to bump versions${NC}\n"

# Watch loop
while true; do
    sleep 2
    
    # Check each service for version changes
    for service in frontend backend payment-service; do
        current_version=$(get_version $service)
        
        if [ "$current_version" != "${versions[$service]}" ] && [ "$current_version" != "unknown" ]; then
            echo -e "${GREEN}🚀 Version change detected for $service: ${versions[$service]} → $current_version${NC}"
            
            # Update stored version
            versions[$service]=$current_version
            
            # Deploy the service
            deploy_service $service
            
            # Show notification
            show_notification $service $current_version
            
            echo -e "${YELLOW}Continuing to watch...${NC}\n"
        fi
    done
done
