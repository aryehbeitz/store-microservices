# Honey Store - Microservices Demo

A complete e-commerce microservices application built with Angular, Node.js, Express, MongoDB, and Temporal, demonstrating modern cloud-native development practices.

## Overview

This is a honey production items and accessories store featuring:

- **Frontend**: Angular SPA with shopping cart and checkout
- **Backend**: Node.js/Express API with MongoDB
- **Payment API**: Async payment microservice with Temporal workflows
- **Payment Worker**: Temporal workflow worker (2 replicas)
- **Payment Dashboard**: Live monitoring UI with Socket.io visualization
- **Temporal**: Workflow orchestration engine
- **PostgreSQL**: Temporal's persistence layer
- **MongoDB**: Application data store
- **Kubernetes**: Full K8s deployment with Ingress/TLS support

## Architecture

```
                          ┌──────────────────┐
                          │    Ingress/TLS   │
                          │  (nginx + cert)  │
                          └──────┬───────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                   │
              ▼                  ▼                   ▼
      ┌──────────────┐  ┌──────────────┐   ┌───────────────┐
      │   Frontend   │  │   Payment    │   │  Payment API  │
      │   :80        │  │  Dashboard   │   │  :8080        │
      └──────┬───────┘  │   :80        │   └───────┬───────┘
             │          └──────────────┘           │
             │ HTTP/Socket.io              ┌───────┤
             ▼                             │       │
      ┌──────────────┐                    │       ▼
      │   Backend    │◄───Webhook────┐    │  ┌──────────┐
      │   :3000      │               │    │  │ Temporal  │
      └──────┬───────┘               │    │  │  :7233   │
             │                       │    │  └────┬─────┘
             ▼                       │    │       │
      ┌──────────────┐               │    │  ┌────▼──────┐
      │   MongoDB    │               │    │  │ Payment   │
      │   :27017     │               │    └──│ Worker    │
      └──────────────┘               │       │ (x2)     │
                                     │       └──────────┘
                                     │
                              ┌──────┴───────┐
                              │  PostgreSQL  │
                              │    :5432     │
                              └──────────────┘
```

**Request Flow:**
1. Frontend → Backend (API calls: orders, products, etc.)
2. Backend → MongoDB (data persistence)
3. Backend → Payment API (initiate payment with webhook URL)
4. Payment API → Temporal → Payment Worker (async workflow execution)
5. Payment API → Backend (webhook callback with payment result)
6. Backend → Frontend (Socket.io real-time updates for order status)

## Quick Start

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
- Detect and let you select your K8s context and namespace
- Generate strong MongoDB and PostgreSQL passwords
- Configure Artifact Registry location and repo
- Optionally set up Ingress with TLS (domain, ingress class, TLS secret)
- Save everything to `.env.local` (automatically gitignored)

### 2. Install Dependencies and Deploy

```bash
pnpm setup
```

This single command will:
- Install all dependencies
- Build all Docker images
- Deploy to Kubernetes:
  - PostgreSQL (Temporal persistence)
  - Temporal (workflow engine)
  - MongoDB (application data)
  - Backend service
  - Payment API microservice
  - Payment Worker (2 replicas)
  - Payment Dashboard
  - Frontend application
  - Ingress with TLS (if configured)

### 3. Access Deployed Services

**With Ingress/TLS enabled:**
```bash
# URLs are shown after deployment, e.g.:
# Frontend:  https://<namespace>-sandbox.<domain>
# Dashboard: https://<namespace>-dashboard-sandbox.<domain>
# API:       https://<namespace>-api-sandbox.<domain>
```

**Without Ingress (ClusterIP + port-forward):**
```bash
kubectl get svc -n <your-namespace>
# Use port-forwarding to access services locally
```

### 4. Develop Locally with K8s Backend

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

#### Option 2: Backend Development (Recommended for API work)

**Important:** Start frontend first!

```bash
# Terminal 1: Start frontend
pnpm dev:frontend

# Terminal 2: Start backend
pnpm dev:backend
```

#### Option 3: Ngrok (Public URLs for webhook testing)

```bash
pnpm dev:ngrok
```

Creates public HTTPS URLs for all services. Great for webhook testing!

#### Option 4: Telepresence (Hybrid development)

```bash
# Terminal 1: Connect and intercept backend
pnpm telepresence:backend

# Terminal 2: Run local backend
pnpm start:backend
```

---

## Kubernetes Deployment

### Deploy

After running `setup-local-config.sh`, deploy with a single command:

```bash
# Uses K8S_CONTEXT and K8S_NAMESPACE from .env.local
./scripts/k8s-deploy.sh

# Or specify explicitly
./scripts/k8s-deploy.sh <context-name> <namespace>
```

### Watch Deployment

Monitor pods as they come up:

```bash
kubectl get pods -n <your-namespace> -w
```

### Verify Deployment

```bash
./scripts/verify-deployment.sh <namespace>
```

Checks all pods, services, ingress endpoints, and scans for hardcoded secrets.

### Build and Deploy a Single Service

After code changes, rebuild and redeploy one service:

```bash
pnpm k8s:build-deploy:backend      # For backend
pnpm k8s:build-deploy:frontend     # For frontend
pnpm k8s:build-deploy:payment      # For payment service
```

### Delete Deployment

```bash
# Uses K8S_CONTEXT and K8S_NAMESPACE from .env.local
./scripts/k8s-delete.sh

# Or specify explicitly
./scripts/k8s-delete.sh <context-name> <namespace>
```

This removes all resources including PVCs, secrets, ingress, and the namespace itself.

## Ingress & TLS

When Ingress is enabled during setup, all user-facing services are accessed via HTTPS through a single Ingress controller:

| Service           | URL Pattern                                       |
|-------------------|---------------------------------------------------|
| Frontend          | `https://<namespace>-sandbox.<domain>`             |
| Payment Dashboard | `https://<namespace>-dashboard-sandbox.<domain>`   |
| Payment API       | `https://<namespace>-api-sandbox.<domain>`         |

**How it works:**
- All services use `ClusterIP` (no LoadBalancers)
- A single Ingress resource routes traffic by hostname
- TLS is terminated at the Ingress using a pre-existing wildcard certificate
- The TLS secret is copied from a source namespace during deployment

**Configuration** (in `.env.local`):
- `ENABLE_INGRESS=true` — enable Ingress routing
- `BASE_DOMAIN` — your base domain
- `INGRESS_CLASS` — ingress controller class (default: nginx)
- `TLS_SECRET_NAME` — name of the TLS secret to use
- `TLS_SECRET_SOURCE_NAMESPACE` — namespace containing the TLS secret

## Features

### Customer Features

- Browse honey products and beekeeping equipment
- Add items to cart (localStorage)
- Checkout with order placement
- Async payment processing via Temporal workflows
- Order confirmation

### Admin Dashboard Features

The payment dashboard provides:

- **Live Service Visualization**: See all services and their health status
- **Real-time Request Monitoring**: Watch requests flow between services
- **Payment Configuration**: Toggle payment errors and adjust processing delays
- **Request Logs**: View detailed logs of all service-to-service communication

## Project Structure

```
store-microservices/
├── apps/
│   ├── frontend/              # Angular application
│   ├── backend/               # Express API
│   └── payment-service/       # Payment microservice (API + Worker)
├── libs/
│   └── shared/types/          # Shared TypeScript types
├── k8s/                       # Kubernetes manifests
│   ├── namespace.yaml
│   ├── ingress.yaml           # Ingress with TLS
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── payment-service-deployment.yaml  # Payment API
│   ├── payment-dashboard-deployment.yaml
│   ├── payment-worker-deployment.yaml
│   ├── mongodb-deployment.yaml
│   ├── postgresql-statefulset.yaml
│   └── temporal-deployment.yaml
├── scripts/                   # Automation scripts
│   ├── setup-local-config.sh  # Interactive environment setup
│   ├── k8s-deploy.sh          # Deploy all services
│   ├── k8s-delete.sh          # Delete all services
│   ├── k8s-apply-secrets.sh   # Create secrets from .env.local
│   ├── verify-deployment.sh   # Verify deployment health
│   ├── update-env-ips.sh      # Update service URLs
│   ├── k8s-build.sh           # Build Docker images
│   └── ...                    # Dev workflow scripts
└── docs/
    └── SETUP.md               # Detailed setup instructions
```

## Technologies

### Frontend
- Angular 17, TypeScript, RxJS, Socket.io-client

### Backend
- Node.js, Express, MongoDB/Mongoose, Socket.io

### Payment System
- Temporal (workflow orchestration), PostgreSQL

### Infrastructure
- Docker, Kubernetes, Nx Monorepo, Nginx Ingress, TLS/HTTPS

## Stopping Services

```bash
# Reset everything back to K8s
pnpm reset

# Stop dev commands — just press Ctrl+C (cleanup is automatic)

# Delete entire K8s deployment (namespace + all resources)
./scripts/k8s-delete.sh
```

## License

MIT
