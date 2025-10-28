#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Deploying to Kubernetes            ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Deploy services
echo -e "${BLUE}Step 1: Deploying MongoDB${NC}"
kubectl apply -f k8s/mongodb-deployment.yaml
echo -e "${GREEN}✓ MongoDB deployed${NC}\n"

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s

echo -e "\n${BLUE}Step 2: Deploying Backend${NC}"
kubectl apply -f k8s/backend-deployment.yaml
echo -e "${GREEN}✓ Backend deployed${NC}\n"

echo -e "${BLUE}Step 3: Deploying Payment Service${NC}"
kubectl apply -f k8s/payment-service-deployment.yaml
echo -e "${GREEN}✓ Payment Service deployed${NC}\n"

echo -e "${BLUE}Step 4: Deploying Frontend${NC}"
kubectl apply -f k8s/frontend-deployment.yaml
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
