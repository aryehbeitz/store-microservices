# 🍯 Honey Store - Microservices Demo

A complete e-commerce microservices application built with Angular, Node.js, Express, and MongoDB, demonstrating modern cloud-native development practices.

## 📋 Overview

This is a honey production items and accessories store featuring:

- **Frontend**: Angular SPA with shopping cart and checkout
- **Backend**: Node.js/Express API with MongoDB
- **Payment Service**: Async microservice with webhook integration
- **Admin Dashboard**: Live monitoring with Socket.io visualization
- **Kubernetes**: Full K8s deployment with multiple access methods

## 🏗️ Architecture

```
┌─────────────┐
│   Frontend  │ (Angular)
│   :4200     │
└──────┬──────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌──────────────┐   ┌─────────────┐
│   Backend    │◄─►│  Payment    │
│   :3000      │   │  Service    │
│              │   │  :3002      │
└──────┬───────┘   └─────────────┘
       │
       ▼
┌──────────────┐
│   MongoDB    │
│   :27017     │
└──────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- pnpm (install globally: `npm install -g pnpm` or `corepack enable`)
- Docker and Docker Compose
- Minikube or K3s
- kubectl

### 1. Install Dependencies

```bash
pnpm install
```

### 2. Start Kubernetes Cluster

```bash
./scripts/build-and-deploy.sh
```

This will:
- Start Minikube or K3s
- Build all Docker images
- Set up the Kubernetes cluster

### 3. Deploy Services

```bash
# (now included in build-and-deploy.sh)
```

This will deploy:
- MongoDB with persistent storage
- Backend service
- Payment microservice
- Frontend application

### 4. Access Services

Choose one of three methods:

#### Option 1: Port Forwarding (Simplest)

```bash
./scripts/port-forward.sh
```

- Frontend: http://localhost:8080
- Backend: http://localhost:3000
- Payment Service: http://localhost:3002
- **Admin Dashboard**: http://localhost:8080/secret-admin-dashboard-xyz

#### Option 2: Ngrok (Public URLs)

```bash
./scripts/ngrok-start.sh
```

Creates public HTTPS URLs for all services. Great for webhook testing!

#### Option 3: Telepresence (Local Development)

```bash
./scripts/telepresence-start.sh
```

Connect your local development environment to the cluster. Perfect for debugging!

---

## 🎯 Kubernetes Deployment with Namespace & Context

For production deployments or multi-environment setups, use the namespace-aware deployment scripts:

### Build and Deploy to Specific Context/Namespace

```bash
# Build and deploy everything
./scripts/k8s-build-and-deploy.sh <context-name> <namespace>

# Example for GKE:
./scripts/k8s-build-and-deploy.sh gke_my-project_us-central1_cluster-name meetup3

# Example for local cluster:
USE_GCR=false ./scripts/k8s-build-and-deploy.sh minikube meetup3
```

### Build Only

```bash
# Build all services (uses env vars or auto-detects)
./scripts/k8s-build.sh

# Build specific service
./scripts/k8s-build-service.sh backend
./scripts/k8s-build-service.sh frontend

# Or use npm scripts:
pnpm k8s:build:backend
pnpm k8s:build:frontend
pnpm k8s:build:all
```

### Deploy Only

```bash
# Deploy to specific context and namespace
./scripts/k8s-deploy.sh <context-name> <namespace>

# Example:
./scripts/k8s-deploy.sh gke_my-project_us-central1_cluster-name meetup3
```

### Redeploy Specific Service (Using npm)

```bash
# Build and redeploy a single service
pnpm k8s:build-deploy:backend
pnpm k8s:build-deploy:frontend

# Or separately:
pnpm k8s:build:backend
pnpm k8s:deploy:backend

# Or use the script directly:
./scripts/k8s-redeploy-service.sh backend
```

### Delete Deployment

```bash
# Delete all resources in a namespace
./scripts/k8s-delete.sh <context-name> <namespace>
```

### Available Scripts

- `k8s-build.sh` - Build Docker images (supports GKE Artifact Registry or local)
- `k8s-deploy.sh` - Deploy to Kubernetes with context and namespace
- `k8s-build-and-deploy.sh` - Combined build and deploy
- `k8s-build-service.sh` - Build a single service
- `k8s-redeploy-service.sh` - Redeploy a single service
- `k8s-delete.sh` - Delete all resources from namespace

### GKE Configuration

For Google Kubernetes Engine (GKE), set environment variables:

```bash
export GCP_PROJECT_ID=REDACTED_PROJECT
export USE_GCR=true  # Optional, defaults to true
export K8S_NAMESPACE=meetup3  # Optional, defaults to meetup3 for npm scripts

# Then run:
./scripts/k8s-build-and-deploy.sh <context> <namespace>
```

Optional environment variables:
- `ARTIFACT_REGISTRY_LOCATION` - defaults to `us-east1`
- `ARTIFACT_REGISTRY_REPO` - defaults to `docker-repo`
- `K8S_NAMESPACE` - defaults to `meetup3` for npm scripts

The scripts will automatically:
- Detect GKE contexts (`gke_*`)
- Auto-detect project ID from `gcloud config` if `GCP_PROJECT_ID` not set
- Build images for `linux/amd64` platform
- Push to Artifact Registry
- Update deployments to use registry images

### NPM Scripts for Quick Deployments

```bash
# Set environment variables once
export GCP_PROJECT_ID=REDACTED_PROJECT
export K8S_NAMESPACE=meetup3

# Build and deploy services
pnpm k8s:build-deploy:backend
pnpm k8s:build-deploy:frontend

# Check status
pnpm k8s:status

# View logs
pnpm k8s:logs:backend
pnpm k8s:logs:frontend
```

## 🔄 Development Workflows

### 1. Local Development (No Kubernetes)

For pure local development without Kubernetes:

```bash
# Terminal 1 - MongoDB
docker run -p 27017:27017 mongo:7

# Terminal 2 - Backend (with environment variables)
cd apps/backend
# Option 1: Copy env.example and edit it, then source it
cp env.example env.local
# Edit env.local with your values, then:
source env.local
pnpm start:backend

# OR Option 2: Set variables inline
MONGODB_URI=mongodb://localhost:27017/honey-store \
PAYMENT_SERVICE_URL=http://REDACTED_IP \
pnpm start:backend

# Terminal 3 - Payment Service
pnpm start:payment

# Terminal 4 - Frontend
pnpm start:frontend
```

**Access:** http://localhost:4200

**Environment Variables:**
- See `apps/backend/env.example` for all available variables
- Copy it to `env.local` and customize for your setup

**Benefits:**
- ✅ Fastest development cycle
- ✅ Full debugging capabilities
- ✅ Hot reload for all services
- ❌ No Kubernetes features
- ❌ No webhook testing

### 2. Port Forwarding (Kubernetes + Local Access)

For testing with Kubernetes but local access:

```bash
# Deploy to Kubernetes
./scripts/build-and-deploy.sh
# (now included in build-and-deploy.sh)

# Access via port forwarding
./scripts/port-forward.sh
```

**Access:** http://localhost:8080

**Benefits:**
- ✅ Real Kubernetes environment
- ✅ Production-like setup
- ✅ Simple access method
- ❌ No webhook support (orders stay pending)
- ❌ No real-time updates

### 3. Telepresence (Hybrid Development)

For debugging with Kubernetes + local services:

```bash
# Deploy to Kubernetes
./scripts/build-and-deploy.sh
# (now included in build-and-deploy.sh)

# Connect with Telepresence
./scripts/telepresence-start.sh
# Choose which service to intercept (Backend, Payment Service, or Both)

# In separate terminals, run local services:
pnpm start:backend    # If intercepting backend
pnpm start:payment    # If intercepting payment service
```

**Access:** http://localhost:8080 (frontend in K8s)

**Benefits:**
- ✅ Real Kubernetes environment
- ✅ Local debugging with hot reload
- ✅ Real webhook support (orders update automatically)
- ✅ Test with real MongoDB and other services
- ❌ More complex setup

### 4. Ngrok (Public Webhook Testing)

For testing webhooks and sharing with others:

```bash
# Deploy to Kubernetes
./scripts/build-and-deploy.sh
# (now included in build-and-deploy.sh)

# Create public tunnels
./scripts/ngrok-start.sh
```

**Access:** Public HTTPS URLs (shown in terminal)

**Benefits:**
- ✅ Public HTTPS URLs
- ✅ Real webhook support
- ✅ Share with team/clients
- ✅ Mobile testing
- ❌ Requires ngrok account
- ❌ URLs change on restart (free tier)

## 📊 Orders Page - Connection Method Demo

The new Orders page (`/orders`) demonstrates the difference between connection methods:

### Port Forwarding Behavior
- Orders show as "pending" and don't update automatically
- Warning: "Orders won't update automatically with port forwarding"
- Manual refresh required to see status changes

### Telepresence/Ngrok Behavior
- Orders update in real-time when payment webhooks are received
- Success message: "Orders update in real-time via webhooks"
- Live status updates without manual refresh

### Visual Indicators
- **Connection Method Badge**: Shows current method (PORT-FORWARD, NGROK, TELEPRESENCE)
- **Webhook Status**: Indicates if webhooks are enabled
- **Status Warnings**: Clear messages about update capabilities

## 🎯 Features

### Customer Features

- Browse honey products and beekeeping equipment
- Add items to cart (localStorage)
- Checkout with order placement
- Async payment processing
- Order confirmation

### Admin Dashboard Features

The hidden admin dashboard (`/secret-admin-dashboard-xyz`) provides:

- **Live Service Visualization**: See all services and their health status
- **Connection Method Tracking**: Know if services use port-forward, ngrok, or telepresence
- **Real-time Request Monitoring**: Watch requests flow between services with animated arrows
- **Payment Configuration**: Toggle payment errors and adjust processing delays
- **Request Logs**: View detailed logs of all service-to-service communication

**Color Coding:**
- 🟢 Green: Direct connection
- 🔵 Blue: Port forwarding
- 🟣 Purple: Ngrok tunnel
- 🟠 Orange: Telepresence
- ⚪ Gray: Disabled

## 📁 Project Structure

```
store-microservices/
├── apps/
│   ├── frontend/              # Angular application
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── components/
│   │   │   │   │   ├── product-list/
│   │   │   │   │   ├── cart/
│   │   │   │   │   ├── checkout/
│   │   │   │   │   └── admin-dashboard/  # Live monitoring
│   │   │   │   └── services/
│   │   │   └── environments/
│   │   ├── Dockerfile
│   │   └── nginx.conf
│   ├── backend/               # Express API
│   │   ├── src/
│   │   │   └── main.ts        # Backend with Socket.io
│   │   └── Dockerfile
│   └── payment-service/       # Payment microservice
│       ├── src/
│       │   └── main.ts        # Async payment processor
│       └── Dockerfile
├── libs/
│   └── shared/
│       └── types/             # Shared TypeScript types
│           └── src/
│               └── index.ts
├── k8s/                       # Kubernetes manifests
│   ├── mongodb-deployment.yaml
│   ├── backend-deployment.yaml
│   ├── payment-service-deployment.yaml
│   └── frontend-deployment.yaml
├── scripts/                   # Automation scripts
│   ├── rebuild-dependencies.sh # Rebuild dependencies and build images
│   ├── deploy-changes.sh     # Deploy changes to Kubernetes
│   ├── port-forward.sh       # Set up port forwarding
│   ├── ngrok-start.sh        # Create ngrok tunnels
│   └── telepresence-start.sh # Connect with telepresence
└── docs/
    └── SETUP.md              # Detailed setup instructions
```

## 🔧 Development

### Local Development (No Kubernetes)

```bash
# Terminal 1 - MongoDB
docker run -p 27017:27017 mongo:7

# Terminal 2 - Backend
pnpm start:backend

# Terminal 3 - Payment Service
pnpm start:payment

# Terminal 4 - Frontend
pnpm start:frontend
```

### Build Individual Services

```bash
# Build backend
nx build backend

# Build payment service
nx build payment-service

# Build frontend
nx build frontend
```

## 📖 Documentation

- [Setup Guide](docs/SETUP.md) - Detailed installation for macOS and Linux
- [Architecture](docs/ARCHITECTURE.md) - System design and data flow

## 🛠️ Technologies

### Frontend
- Angular 17
- TypeScript
- RxJS
- Socket.io-client

### Backend
- Node.js
- Express
- MongoDB with Mongoose
- Socket.io

### Infrastructure
- Docker
- Kubernetes (Minikube/K3s)
- Nx Monorepo
- Ngrok
- Telepresence

## 🎮 Demo Scenarios

### 1. Normal Purchase Flow
1. Browse products at http://localhost:8080
2. Add items to cart
3. Checkout with customer details
4. Watch payment process in admin dashboard

### 2. Payment Failure Simulation
1. Open admin dashboard: http://localhost:8080/secret-admin-dashboard-xyz
2. Toggle "Simulate Payment Error"
3. Place an order
4. Watch the payment fail in real-time

### 3. Connection Method Visualization
1. Start with port forwarding
2. Open admin dashboard
3. Services show blue circles (port-forward)
4. Stop and switch to ngrok
5. Services show purple circles (ngrok)
6. Switch to telepresence
7. Services show orange circles (telepresence)

## 🚦 Stopping Services

```bash
# Stop port forwards
./scripts/stop-port-forward.sh

# Stop ngrok
./scripts/stop-ngrok.sh

# Stop telepresence
./scripts/stop-telepresence.sh

# Stop Kubernetes
minikube stop
# or
k3d cluster delete honey-store
```

## 📝 License

MIT

## 🤝 Contributing

This is a demo project for educational purposes.

---

Made with ❤️ for demonstrating microservices architecture
