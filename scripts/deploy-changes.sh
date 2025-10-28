#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Deploying to Kubernetes            ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Check if timestamp file exists
if [ -f ".docker-timestamp" ]; then
    TIMESTAMP=$(cat .docker-timestamp)
    echo -e "${YELLOW}Using timestamped images: $TIMESTAMP${NC}\n"
else
    echo -e "${YELLOW}No timestamp found, using latest images${NC}\n"
    TIMESTAMP="latest"
fi

# Deploy services
echo -e "${BLUE}Step 1: Deploying MongoDB${NC}"
kubectl apply -f k8s/mongodb-deployment.yaml
echo -e "${GREEN}✓ MongoDB deployed${NC}\n"

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s

echo -e "\n${BLUE}Step 2: Deploying Backend${NC}"
# Update image tag in deployment
kubectl set image deployment/backend backend=honey-store/backend:$TIMESTAMP
kubectl rollout status deployment/backend --timeout=120s
echo -e "${GREEN}✓ Backend deployed${NC}\n"

echo -e "${BLUE}Step 3: Deploying Payment Service${NC}"
# Update image tag in deployment
kubectl set image deployment/payment-service payment-service=honey-store/payment-service:$TIMESTAMP
kubectl rollout status deployment/payment-service --timeout=120s
echo -e "${GREEN}✓ Payment Service deployed${NC}\n"

echo -e "${BLUE}Step 4: Deploying Frontend${NC}"
# Update image tag in deployment
kubectl set image deployment/frontend frontend=honey-store/frontend:$TIMESTAMP
kubectl rollout status deployment/frontend --timeout=120s
echo -e "${GREEN}✓ Frontend deployed${NC}\n"

# Show deployment status
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Deployment Status                  ${NC}"
echo -e "${BLUE}======================================${NC}\n"
kubectl get pods
kubectl get services

echo -e "\n${GREEN}✓ All services deployed successfully${NC}"
echo -e "\n${YELLOW}Access options:${NC}"
echo "  1. Port forwarding: ./scripts/port-forward.sh"
echo "  2. Ngrok tunnels: ./scripts/ngrok-start.sh"
echo "  3. Telepresence: ./scripts/telepresence-start.sh"
