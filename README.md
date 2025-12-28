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
             │ HTTP/Socket.io
             │
             ▼
      ┌──────────────┐
      │   Backend    │◄───┐
      │   :3000      │    │ Webhook
      └──────┬───────┘    │ callback
             │            │
             ├────────────┼─────────┐
             │            │         │
             ▼            │         ▼
      ┌──────────────┐    │   ┌─────────────┐
      │   MongoDB    │    │   │  Payment    │
      │   :27017     │    └──◄│  Service    │
      └──────────────┘        │  :8080      │
                              └─────────────┘


    Socket.io updates
```

**Request Flow:**
1. Frontend → Backend (API calls: orders, products, etc.)
2. Backend → MongoDB (data persistence)
3. Backend → Payment Service (initiate payment with webhook URL)
4. Payment Service → Backend (webhook callback with payment result)
5. Backend → Frontend (Socket.io real-time updates for order status)

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- pnpm (install globally: `npm install -g pnpm` or `corepack enable`)
- Docker and Docker Compose
- Kubernetes cluster (GKE, Minikube, or K3s)
- kubectl

### TL;DR - Quick Commands

```bash
# First time setup
./scripts/setup-local-config.sh
pnpm setup                     # Installs deps and deploys to K8s

# Development workflows
pnpm dev:frontend              # Frontend dev with K8s backend

# For backend dev (run frontend first!):
pnpm dev:frontend              # Terminal 1: Start frontend
pnpm dev:backend               # Terminal 2: Start backend

# Advanced workflows
pnpm dev:ngrok                 # Enable webhooks for payment testing
pnpm telepresence:backend      # Run local backend with K8s services (webhooks work!)
pnpm telepresence:connect      # Just connect to cluster (no intercepts)

# Reset to full K8s deployment
pnpm reset                     # Stop all dev modes, restore K8s services

# Access deployed services - check deployment output for URLs
```

### 1. Configure Your Environment

```bash
# Run interactive setup to configure GCP, K8s, and MongoDB credentials
./scripts/setup-local-config.sh
```

This will:
- Detect and let you select your GCP project
- Detect and let you select your K8s context
- Detect and let you select your namespace
- Generate a strong MongoDB password (or let you enter your own)
- Save everything to `.env.local` (automatically gitignored)

After deployment, service IPs are automatically detected and saved to `.env.local`

### 2. Install Dependencies and Deploy

```bash
pnpm setup
```

This single command will:
- Install all dependencies
- Build all Docker images
- Deploy to Kubernetes:
  - MongoDB with persistent storage
  - Backend service
  - Payment microservice
  - Frontend application

### 3. Develop Locally with K8s Backend

Choose your development mode:

#### Option 1: Frontend Development (Recommended for UI work)

```bash
pnpm dev:frontend
```

This single command:
- Configures frontend to use K8s backend
- Starts port-forwarding to backend
- Starts frontend with live reload on http://localhost:4200
- Cleans up everything when you press Ctrl+C

The script will print all service URLs when ready.

#### Option 2: Backend Development (Recommended for API work)

**Important:** Start frontend first!

```bash
# Terminal 1: Start frontend
pnpm dev:frontend

# Terminal 2: Start backend
pnpm dev:backend
```

This command:
- Requires local frontend to be running first
- Connects local frontend to local backend automatically
- Starts port-forwarding to MongoDB and Payment API
- Starts backend locally with live reload
- Scales down K8s backend to avoid conflicts

The script will print all service URLs when ready.

#### Option 3: Ngrok (Public URLs for webhook testing)

```bash
pnpm dev:ngrok
```

Creates public HTTPS URLs for all services. Great for webhook testing!

#### Option 4: Telepresence (Hybrid development)

**Prerequisites:** Deploy services to K8s first (steps 1-3 above)

**Option 4a: Backend Development (Most useful)**

```bash
# Terminal 1: Connect and intercept backend
pnpm telepresence:backend

# Terminal 2: Run local backend
pnpm start:backend
```

The script shows you exactly what's running where:
- ✅ **LOCAL (Live Changes):** Your backend
- ☁️ **K8S (Cannot Change):** Frontend, MongoDB, Payment API
- ✅ **WEBHOOKS:** Work natively (no ngrok needed!)

Test with real deployed frontend. Your local backend handles all requests.

**Option 4b: Connect Only (No intercepts)**

```bash
pnpm telepresence:connect
```

Just connect to cluster network. Access cluster services from local machine without intercepting anything.

#### Option 5: Full K8s Access (View deployed services)

Access your deployed services directly via their LoadBalancer IPs:

```bash
# Get service URLs
kubectl get svc -n <your-namespace>
```

Service URLs are displayed after deployment completes.

---

## 🎯 Kubernetes Deployment with Namespace & Context

For production deployments or multi-environment setups, use the namespace-aware deployment scripts:

### Build and Deploy to Specific Context/Namespace

```bash
# Build and deploy everything
./scripts/k8s-build-and-deploy.sh <context-name> <namespace>

# Example for GKE:
./scripts/k8s-build-and-deploy.sh gke_my-project_us-central1_cluster-name <namespace>

# Example for local cluster:
USE_GCR=false ./scripts/k8s-build-and-deploy.sh minikube <namespace>
```

### Quick Redeploy After Code Changes (Uses .env.local)

After making code changes, quickly rebuild and redeploy a single service:

```bash
pnpm k8s:build-deploy:backend      # For backend
pnpm k8s:build-deploy:frontend     # For frontend
pnpm k8s:build-deploy:payment      # For payment service

These commands:
- Use configuration from `.env.local` (no need to specify context/namespace)
- Build the Docker image with your changes
- Push to Artifact Registry
- Restart the deployment automatically

### Delete Deployment

```bash
# Delete all resources in a namespace
./scripts/k8s-delete.sh <context-name> <namespace>
```

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
1. Browse products in the frontend (local dev or deployed)
2. Add items to cart
3. Checkout with customer details
4. Watch payment process in admin dashboard

### 2. Payment Failure Simulation
1. Open admin dashboard at `/secret-admin-dashboard-xyz`
2. Toggle "Simulate Payment Error"
3. Place an order
4. Watch the payment fail in real-time

### 3. Local Development Workflow
1. Frontend-only work: `pnpm dev:frontend`
2. Backend work: Start `pnpm dev:frontend`, then in another terminal `pnpm dev:backend`
3. Make code changes - see instant updates in http://localhost:4200
4. Backend changes reload automatically
5. Use `pnpm dev:ngrok` to test webhooks with real payment processing

## 🚦 Stopping Services

```bash
# Reset everything back to K8s (stops telepresence, port-forwards, scales up backend)
pnpm reset

# Stop dev commands (pnpm dev:frontend or pnpm dev:backend)
# Just press Ctrl+C - cleanup happens automatically!

# Stop ngrok
# Press Ctrl+C in the ngrok terminal - auto-restores payment service

# Stop telepresence
pnpm telepresence:stop

# Stop Kubernetes cluster
minikube stop
# or for k3d:
k3d cluster delete honey-store
# or for GKE:
# Services keep running - manage via kubectl or GCP Console
```

## 📝 License

MIT

## 🤝 Contributing

This is a demo project for educational purposes.

---

Made with ❤️ for demonstrating microservices architecture
