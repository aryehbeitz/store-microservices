# 🛠️ Honey Store - Complete Setup Guide

This guide provides detailed installation and setup instructions for macOS and Linux.

## Table of Contents

1. [Prerequisites Installation](#prerequisites-installation)
2. [Kubernetes Setup](#kubernetes-setup)
3. [Project Setup](#project-setup)
4. [Deployment](#deployment)
5. [Access Methods](#access-methods)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites Installation

### macOS

#### 1. Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Install Node.js and pnpm

```bash
brew install node
node --version  # Should be 18 or higher

# Install pnpm globally
npm install -g pnpm
# OR use corepack (recommended for Node.js 16.10+)
corepack enable
corepack prepare pnpm@latest --activate

pnpm --version
```

#### 3. Install Docker Desktop

```bash
brew install --cask docker
```

Or download from: https://www.docker.com/products/docker-desktop

After installation, open Docker Desktop and wait for it to start.

#### 4. Install kubectl

```bash
brew install kubectl
kubectl version --client
```

#### 5. Install Minikube

```bash
brew install minikube
minikube version
```

**OR** Install K3s (alternative):

```bash
brew install k3d
k3d version
```

#### 6. Install Ngrok (Optional)

```bash
brew install ngrok

# Authenticate ngrok
ngrok config add-authtoken YOUR_TOKEN_FROM_NGROK_DASHBOARD
```

Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken

#### 7. Install Telepresence (Optional)

```bash
brew install telepresence
telepresence version
```

---

### Linux (Ubuntu/Debian)

#### 1. Install Node.js and pnpm

```bash
# Using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should be 18 or higher

# Install pnpm globally
npm install -g pnpm
# OR use corepack (recommended for Node.js 16.10+)
corepack enable
corepack prepare pnpm@latest --activate

pnpm --version
```

#### 2. Install Docker

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
```

#### 3. Install kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
```

#### 4. Install Minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube version
```

**OR** Install K3s (alternative):

```bash
# Install K3d
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d version
```

#### 5. Install Ngrok (Optional)

```bash
# Download and install ngrok
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
  sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
  sudo tee /etc/apt/sources.list.d/ngrok.list && \
  sudo apt update && sudo apt install ngrok

# Authenticate ngrok
ngrok config add-authtoken YOUR_TOKEN_FROM_NGROK_DASHBOARD
```

Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken

#### 6. Install Telepresence (Optional)

```bash
# Download and install telepresence
sudo curl -fL https://app.getambassador.io/download/tel2oss/releases/download/v2.15.1/telepresence-linux-amd64 -o /usr/local/bin/telepresence
sudo chmod +x /usr/local/bin/telepresence
telepresence version
```

---

## Kubernetes Setup

### Option A: Using Minikube

#### 1. Start Minikube

```bash
# Start with sufficient resources
minikube start --cpus=4 --memory=4096

# Verify cluster is running
minikube status

# Enable required addons
minikube addons enable ingress
minikube addons enable metrics-server
```

#### 2. Configure Docker to use Minikube's Docker daemon

```bash
# Run this in every terminal where you build Docker images
eval $(minikube docker-env)

# To make it permanent, add to your shell profile:
# For bash: ~/.bashrc
# For zsh: ~/.zshrc
echo 'eval $(minikube docker-env)' >> ~/.bashrc  # or ~/.zshrc
```

#### 3. Verify Kubernetes is working

```bash
kubectl cluster-info
kubectl get nodes
```

---

### Option B: Using K3s/K3d

#### 1. Create K3d cluster

```bash
# Create cluster with 2 worker nodes
k3d cluster create honey-store --agents 2

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=120s
```

#### 2. Verify cluster

```bash
kubectl cluster-info
kubectl get nodes
```

---

## Project Setup

### 1. Clone and Install Dependencies

```bash
# Navigate to project directory
cd store-microservices

# Install dependencies
pnpm install

# This will take a few minutes...
```

### 2. Verify Nx workspace

```bash
# List all projects
pnpm exec nx show projects

# Should show:
# - frontend
# - backend
# - payment-service
# - shared-types
```

---

## Deployment

### Step 1: Start Kubernetes and Build Images

```bash
./scripts/rebuild-dependencies.sh
```

This script will:
1. ✓ Detect and start your Kubernetes cluster (Minikube or K3d)
2. ✓ Configure Docker environment
3. ✓ Build Docker images for all services:
   - `honey-store/frontend:latest`
   - `honey-store/backend:latest`
   - `honey-store/payment-service:latest`

**Expected output:**
```
======================================
  Honey Store - Kubernetes Setup
======================================

Using Minikube
Starting Minikube...
✓ Kubernetes cluster ready and images built

Next steps:
  1. Run './scripts/deploy-changes.sh' to deploy the services
  2. Run './scripts/port-forward.sh' to access the services locally
```

### Step 2: Deploy to Kubernetes

```bash
./scripts/deploy-changes.sh
```

This script will:
1. ✓ Deploy MongoDB with persistent storage
2. ✓ Deploy Backend service
3. ✓ Deploy Payment microservice
4. ✓ Deploy Frontend application
5. ✓ Create Kubernetes services for networking

**Expected output:**
```
======================================
  Deploying to Kubernetes
======================================

Step 1: Deploying MongoDB
✓ MongoDB deployed

Step 2: Deploying Backend
✓ Backend deployed

Step 3: Deploying Payment Service
✓ Payment Service deployed

Step 4: Deploying Frontend
✓ Frontend deployed

======================================
  Deployment Status
======================================

NAME                READY   STATUS    RESTARTS   AGE
mongodb-xxx         1/1     Running   0          30s
backend-xxx         1/1     Running   0          20s
payment-service-xxx 1/1     Running   0          15s
frontend-xxx        1/1     Running   0          10s
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# Check deployment details
kubectl get deployments

# View logs if needed
kubectl logs -f deployment/backend
kubectl logs -f deployment/payment-service
```

---

## Access Methods

You have three options to access your services:

### Method 1: Port Forwarding (Recommended for Development)

**Use case:** Simple local development and testing

```bash
./scripts/port-forward.sh
```

**Access URLs:**
- Frontend: http://localhost:8080
- Backend: http://localhost:3000
- Payment Service: http://localhost:3002
- Admin Dashboard: http://localhost:8080/secret-admin-dashboard-xyz

**Features:**
- ✓ Quick and simple
- ✓ No external dependencies
- ✓ Works offline
- ✗ Only accessible from your machine

**To stop:**
```bash
# Press Ctrl+C or run:
./scripts/stop-port-forward.sh
```

---

### Method 2: Ngrok Tunnels (Public Access)

**Use case:** Testing webhooks, sharing with others, mobile testing

```bash
./scripts/ngrok-start.sh
```

**What you get:**
- Public HTTPS URLs for all services
- Ngrok web interface at http://localhost:4040
- Real-time request inspection

**Example output:**
```
======================================
  Ngrok Tunnel URLs
======================================

Backend:         https://abc123.ngrok.io
Payment Service: https://def456.ngrok.io
Frontend:        https://ghi789.ngrok.io

Ngrok Web Interface: http://localhost:4040
```

**Features:**
- ✓ Public HTTPS URLs
- ✓ Webhook testing (payment callbacks)
- ✓ Share with team/clients
- ✓ Request inspection
- ✗ Requires ngrok account
- ✗ URLs change on restart (free tier)

**To stop:**
```bash
# Press Ctrl+C or run:
./scripts/stop-ngrok.sh
```

---

### Method 3: Telepresence (Hybrid Local/Remote)

**Use case:** Debugging services locally while connected to cluster

```bash
./scripts/telepresence-start.sh
```

**Interactive menu:**
```
Choose which service to intercept:
  1) Backend
  2) Payment Service
  3) Both
  4) None (just connect to cluster)

Enter your choice (1-4):
```

**Example workflow (choosing option 1 - Backend):**

1. Run telepresence script and select option 1
2. In another terminal, run your local backend:
   ```bash
   pnpm start:backend
   ```
3. Your local backend now handles all requests from the cluster!

**Features:**
- ✓ Debug locally with cluster context
- ✓ Hot reload during development
- ✓ Access all cluster services
- ✓ Test with real MongoDB, other services
- ✗ More complex setup
- ✗ Requires telepresence installation

**To stop:**
```bash
# Press Ctrl+C or run:
./scripts/stop-telepresence.sh
```

---

## Testing the Application

### 1. Access the Frontend

Open http://localhost:8080 (or your ngrok URL)

### 2. Browse Products

- View honey products, equipment, and accessories
- Filter by category
- Add items to cart

### 3. Checkout

- Go to cart
- Fill in customer details:
  - Name: John Doe
  - Email: john@example.com
  - Address: 123 Main St, Anytown, USA
- Place order

### 4. Monitor with Admin Dashboard

Open http://localhost:8080/secret-admin-dashboard-xyz

**What you'll see:**
- Service architecture diagram
- Live service health status
- Connection method indicators (colors)
- Real-time request flows (animated)
- Request logs

**Try this:**
1. Toggle "Simulate Payment Error"
2. Place an order
3. Watch the payment fail in real-time with red indicators

### 5. Observe Connection Methods

**Test different connection types:**

```bash
# Start with port forwarding (Blue circles)
./scripts/port-forward.sh

# Check admin dashboard - services show blue

# Stop and switch to ngrok (Purple circles)
./scripts/stop-port-forward.sh
./scripts/ngrok-start.sh

# Check admin dashboard - services show purple

# Switch to telepresence (Orange circles)
./scripts/stop-ngrok.sh
./scripts/telepresence-start.sh

# Check admin dashboard - services show orange
```

---

## Troubleshooting

### Issue: Minikube won't start

```bash
# Delete and recreate
minikube delete
minikube start --cpus=4 --memory=4096
```

### Issue: Pods stuck in "ImagePullBackOff"

```bash
# Ensure you're using minikube's Docker daemon
eval $(minikube docker-env)

# Rebuild images
./scripts/rebuild-dependencies.sh
```

### Issue: Port already in use

```bash
# Find process using port 3000
lsof -ti:3000

# Kill process
lsof -ti:3000 | xargs kill -9

# Or use different ports in scripts
```

### Issue: MongoDB connection failed

```bash
# Check MongoDB pod
kubectl logs deployment/mongodb

# Restart MongoDB
kubectl rollout restart deployment/mongodb

# Wait for it to be ready
kubectl wait --for=condition=ready pod -l app=mongodb --timeout=120s
```

### Issue: Services can't communicate

```bash
# Check service DNS
kubectl exec -it deployment/backend -- nslookup mongodb
kubectl exec -it deployment/backend -- nslookup payment-service

# Check service endpoints
kubectl get endpoints
```

### Issue: Ngrok authentication failed

```bash
# Re-authenticate
ngrok config add-authtoken YOUR_TOKEN

# Verify config
ngrok config check
```

### Issue: Telepresence connection failed

```bash
# Reset telepresence
telepresence quit
telepresence uninstall --everything

# Reconnect
telepresence connect
```

### Issue: pnpm install fails

```bash
# Clear pnpm cache
pnpm store prune

# Remove node_modules and lockfile
rm -rf node_modules pnpm-lock.yaml

# Reinstall
pnpm install
```

---

## Useful Commands

### Kubernetes

```bash
# View all resources
kubectl get all

# Describe a pod
kubectl describe pod <pod-name>

# View logs
kubectl logs -f deployment/backend

# Execute command in pod
kubectl exec -it deployment/backend -- sh

# Port forward manually
kubectl port-forward service/backend 3000:3000

# Delete deployment
kubectl delete deployment backend

# Restart deployment
kubectl rollout restart deployment/backend

# Check resource usage
kubectl top pods
kubectl top nodes
```

### Docker

```bash
# List images
docker images | grep honey-store

# Remove images
docker rmi honey-store/backend:latest

# View container logs
docker logs <container-id>

# Clean up unused images
docker image prune -a
```

### Nx Workspace

```bash
# List projects
pnpm exec nx show projects

# Build specific project
pnpm exec nx build backend

# Serve locally
pnpm exec nx serve frontend
pnpm exec nx serve backend
pnpm exec nx serve payment-service

# Run all builds
pnpm exec nx run-many --target=build --all
```

---

## Next Steps

1. **Explore the code**: Check out the Angular components and Express services
2. **Modify products**: Edit `apps/frontend/src/app/services/product.service.ts`
3. **Add features**: Implement user authentication, order history, etc.
4. **Deploy to cloud**: Adapt K8s manifests for GKE, EKS, or AKS
5. **Add monitoring**: Integrate Prometheus and Grafana
6. **Set up CI/CD**: Create GitHub Actions workflows

---

## Support

For issues or questions:
1. Check the [troubleshooting section](#troubleshooting)
2. Review logs: `kubectl logs deployment/<service-name>`
3. Check GitHub issues

---

**Happy coding! 🍯**
