#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Honey Store - Build & Deploy       ${NC}"
echo -e "${BLUE}======================================${NC}"

# Generate unique timestamp for image tags
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
echo -e "${YELLOW}Using timestamp: $TIMESTAMP${NC}"

# Store timestamp for potential future use
echo "$TIMESTAMP" > .docker-timestamp

# Detect Kubernetes cluster
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    echo -e "${GREEN}Using Minikube${NC}"
    eval $(minikube docker-env)
elif command -v k3d &> /dev/null && k3d cluster list | grep -q "honey-store"; then
    echo -e "${GREEN}Using K3d${NC}"
    eval $(k3d kubeconfig get honey-store)
else
    echo -e "${RED}No supported Kubernetes cluster found!${NC}"
    echo "Please start Minikube or K3d first:"
    echo "  Minikube: minikube start"
    echo "  K3d: k3d cluster create honey-store"
    exit 1
fi

echo -e "\n${BLUE}Step 1: Building Docker Images${NC}"

echo "Building backend..."
docker build -t honey-store/backend:$TIMESTAMP -t honey-store/backend:latest -f apps/backend/Dockerfile .

echo "Building payment service..."
docker build -t honey-store/payment-service:$TIMESTAMP -t honey-store/payment-service:latest -f apps/payment-service/Dockerfile .

echo "Building frontend..."
docker build -t honey-store/frontend:$TIMESTAMP -t honey-store/frontend:latest -f apps/frontend/Dockerfile .

echo -e "${GREEN}✓ All images built successfully${NC}"

echo -e "\n${BLUE}Step 2: Deploying to Kubernetes${NC}"

# Deploy MongoDB
echo "Deploying MongoDB..."
kubectl apply -f k8s/mongodb-deployment.yaml
kubectl rollout status deployment/mongodb --timeout=120s
echo -e "${GREEN}✓ MongoDB deployed${NC}"

# Deploy Backend
echo "Deploying Backend..."
kubectl apply -f k8s/backend-deployment.yaml
kubectl set image deployment/backend backend=honey-store/backend:$TIMESTAMP
kubectl rollout status deployment/backend --timeout=120s
echo -e "${GREEN}✓ Backend deployed${NC}"

# Deploy Payment Service
echo "Deploying Payment Service..."
kubectl apply -f k8s/payment-service-deployment.yaml
kubectl set image deployment/payment-service payment-service=honey-store/payment-service:$TIMESTAMP
kubectl rollout status deployment/payment-service --timeout=120s
echo -e "${GREEN}✓ Payment Service deployed${NC}"

# Deploy Frontend
echo "Deploying Frontend..."
kubectl apply -f k8s/frontend-deployment.yaml
kubectl set image deployment/frontend frontend=honey-store/frontend:$TIMESTAMP
kubectl rollout status deployment/frontend --timeout=120s
echo -e "${GREEN}✓ Frontend deployed${NC}"

echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}  Deployment Status                  ${NC}"
echo -e "${BLUE}======================================${NC}"

kubectl get pods
kubectl get services

echo -e "\n${GREEN}✓ All services deployed successfully${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "1. Run './scripts/port-forward.sh' to access services locally"
echo "2. Run './scripts/ngrok-start.sh' for webhook demo with real-time updates"
echo "3. Run './scripts/telepresence-start.sh' for development with local services"

echo -e "\n${YELLOW}Service URLs (after port forwarding):${NC}"
echo "Frontend:        http://localhost:8080"
echo "Backend:         http://localhost:3000"
echo "Payment Service: http://localhost:3002"
echo "Admin Dashboard: http://localhost:8080/secret-admin-dashboard-xyz"
