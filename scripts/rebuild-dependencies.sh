#!/bin/bash

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Honey Store - Rebuild Dependencies ${NC}"
echo -e "${BLUE}======================================${NC}\n"

# Check if minikube or k3d is available
if command -v minikube &> /dev/null; then
    CLUSTER_TYPE="minikube"
    echo -e "${GREEN}Using Minikube${NC}"
elif command -v k3d &> /dev/null; then
    CLUSTER_TYPE="k3d"
    echo -e "${GREEN}Using K3d${NC}"
else
    echo -e "${YELLOW}Neither minikube nor k3d found. Please install one of them first.${NC}"
    echo "Installation instructions are in docs/SETUP.md"
    exit 1
fi

# Start cluster
echo -e "\n${BLUE}Step 1: Starting Kubernetes cluster${NC}"
if [ "$CLUSTER_TYPE" = "minikube" ]; then
    # Check if minikube is running
    minikube status &> /dev/null
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "Starting Minikube..."
        # Try to delete if in bad state
        minikube delete &> /dev/null
        minikube start --cpus=2 --memory=4096
    else
        echo "Minikube is already running"
    fi

    # Use minikube docker daemon
    eval $(minikube docker-env)
elif [ "$CLUSTER_TYPE" = "k3d" ]; then
    k3d cluster list | grep honey-store &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Creating K3d cluster..."
        k3d cluster create honey-store --agents 2
    else
        echo "K3d cluster already exists"
    fi
fi

# Build Docker images
echo -e "\n${BLUE}Step 2: Building Docker images${NC}"
echo "Building backend..."
docker build -t honey-store/backend:latest -f apps/backend/Dockerfile .

echo "Building payment service..."
docker build -t honey-store/payment-service:latest -f apps/payment-service/Dockerfile .

echo "Building frontend..."
docker build -t honey-store/frontend:latest -f apps/frontend/Dockerfile .

echo -e "\n${GREEN}✓ Kubernetes cluster ready and images built${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Run './scripts/deploy-changes.sh' to deploy the services"
echo "  2. Run './scripts/port-forward.sh' to access the services locally"
