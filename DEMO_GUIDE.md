# 🎯 Demo Guide - Honey Store Microservices

## Quick Status Check

Before starting your demo, verify everything is running:

```bash
# Check if cluster is accessible
kubectl get pods -n meetup3

# Check services
kubectl get svc -n meetup3

# Get frontend URL (if LoadBalancer)
kubectl get svc frontend -n meetup3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Get backend URL (if LoadBalancer)
kubectl get svc backend -n meetup3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

## 🎯 Demo Overview: Connection Methods

This demo showcases **different ways to connect to Kubernetes services**, each with different webhook capabilities and code change support:

1. **Port Forward** - **Frontend runs locally** (live code changes!), backend in K8s accessed via port forwarding. **Enables frontend development**
2. **Port Forward + Local Backend** - **Backend runs locally** (live code changes!), port forwarding connects to K8s services. **Enables backend development**
3. **Port Forward + Local All** - **Both frontend AND backend run locally** (live code changes!), port forwarding connects to K8s services. **Enables full-stack development**
4. **Ngrok** - Public HTTPS URLs, webhooks work perfectly. **All services in K8s - no local development, code changes require rebuild/redeploy**
5. **Telepresence** - Local debugging with full webhook support. **Services run locally - code changes reflected immediately with hot reload!**

### ⚠️ Critical Distinction: Local Code Changes

**Port Forward (Frontend Development):**
- **Frontend runs locally** (live code changes for frontend!)
- **Backend runs in K8s** (accessed via port forwarding)
- Port forwarding connects local frontend to K8s backend
- **Use case**: Active **frontend** development with K8s backend

**Port Forward + Local Backend (Backend Development):**
- **Backend runs locally** (live code changes for backend!)
- **Other services** (MongoDB, Payment API, Frontend) run in K8s via port forwarding
- Port forwarding connects local backend to K8s services
- Webhooks work if backend has LoadBalancer or ngrok URL
- **Use case**: Active **backend** development with K8s services

**Port Forward + Local All (Full-Stack Development):**
- **Both frontend AND backend run locally** (live code changes for both!)
- **Other services** (MongoDB, Payment API) run in K8s via port forwarding
- Port forwarding connects local services to K8s services
- Webhooks work if backend has LoadBalancer or ngrok URL
- **Use case**: Active **full-stack** development with K8s services

**Ngrok:**
- **All services run inside Kubernetes pods**
- Port forwarding is **only for local access** - you can't make code changes
- Local code changes are **NOT reflected** until you:
  1. Rebuild Docker images
  2. Push to registry
  3. Redeploy to Kubernetes
- **No hot reload** - changes require full rebuild/redeploy cycle
- **Use case**: Webhook testing, no code changes needed

**Telepresence:**
- Services run **locally on your machine** (intercepted from cluster)
- Local code changes are **reflected immediately** with hot reload
- **No rebuild/redeploy needed** - perfect for active development
- Full cluster network access
- **Use case**: Active development, debugging, live code changes, full cluster integration

**Key Insight**: Port forwarding enables local development for ONE service (frontend OR backend), while other services run in K8s. Ngrok is for testing only, not development.

---

## 🚀 Demo Flow: Port Forward (Frontend Development)

**Goal**: Show how port forwarding enables frontend development with K8s backend

> **✅ Key Advantage**: **Frontend runs locally**, so **frontend code changes ARE reflected immediately**! Backend runs in K8s and is accessed via port forwarding.

> **✅ Webhook Note**: Webhooks **DO work** because the backend is in Kubernetes and the payment service uses internal cluster DNS (`http://backend:3000`) to reach it.

### Step 1: Set Up Port Forwarding for Backend

```bash
# Start port forwarding for backend (frontend will run locally)
./scripts/port-forward.sh

# This forwards:
# - Backend: localhost:3000 → backend:3000 (in K8s)
# - Payment API: localhost:8082 → payment-api:8080 (in K8s)
```

### Step 2: Start Local Frontend

```bash
# In a new terminal
cd apps/frontend

# Frontend environment.ts already points to http://localhost:3000
# Start frontend locally
npm run start:frontend

# Frontend will be available at: http://localhost:4200
```

### Step 3: Demonstrate Live Frontend Code Changes

1. **Open Frontend**: http://localhost:4200
2. **Modify Frontend Code**:
   - Edit `apps/frontend/src/app/components/product-list/product-list.component.html`
   - Change the heading text
   - Save the file
3. **Watch Hot Reload**:
   - Frontend automatically reloads (Angular dev server)
   - **No Docker rebuild needed!**
   - **No Kubernetes redeploy needed!**
   - See your changes immediately
4. **Test with Backend**:
   - Place an order
   - **Explain**: "Frontend runs locally with live changes, but uses backend in K8s via port forwarding"

### Step 4: Show Webhooks Working

1. **Place an Order**:
   - Browse products → Add to cart → Checkout
   - Fill in customer details and place order
   - **Key Point**: "Order is created immediately"
2. **Watch Order Status**:
   - Order shows as **"pending"**
   - Wait 15 seconds... **Status updates to "approved"!**
   - **Explain**: "Webhooks work because backend is in Kubernetes and payment service uses cluster DNS"
   - **Key Point**: "Frontend runs locally, but backend in K8s can receive webhooks via cluster DNS"

### Step 4: Check Backend Logs

```bash
# In a separate terminal
kubectl logs -f deployment/backend -n meetup3

# Place another order and watch logs
# You'll see: Payment request sent successfully
# But NO webhook received message
```

**Talking Points**:
- "Port forwarding is great for quick testing, but it doesn't work for webhooks because external services can't reach localhost URLs."
- "**Important limitation**: Services run in Kubernetes, so local code changes require rebuilding Docker images and redeploying. No hot reload."
- "**Next**: We'll show a variation where the backend runs locally for live code changes!"

---

## 🔄 Demo Flow: Port Forward + Local Backend (Backend Development)

**Goal**: Show how port forwarding enables a hybrid setup - **local backend** with live code changes, while using K8s services

> **✅ Key Advantage**: **Backend runs locally**, so **backend code changes ARE reflected immediately**! Port forwarding connects local backend to K8s services (MongoDB, Payment API). Frontend still runs in K8s.

### Step 1: Set Up Port Forwarding for K8s Services

```bash
# Start port forwarding for services the backend needs
./scripts/port-forward-local-backend.sh

# This forwards:
# - MongoDB: localhost:27017 → mongodb:27017
# - Payment API: localhost:8082 → payment-api:8080
# - Frontend: localhost:8080 → frontend:80
```

### Step 2: Start Local Backend

```bash
# In a new terminal
cd apps/backend

# Set environment variables
export MONGODB_URI=mongodb://localhost:27017/honey-store
export PAYMENT_SERVICE_URL=http://localhost:8082
export CONNECTION_METHOD=port-forward
export SERVICE_LOCATION=local

# If backend has LoadBalancer, set for webhooks:
export BACKEND_PUBLIC_URL=http://<backend-loadbalancer-ip>:3000

# Start backend locally
npm run start:backend
```

### Step 3: Demonstrate Live Code Changes

1. **Open Frontend**: http://localhost:8080
2. **Modify Backend Code**:
   - Edit `apps/backend/src/main.ts`
   - Add console.log or modify behavior
   - Save the file
3. **Watch Hot Reload**:
   - Backend automatically restarts (if using nodemon/watch)
   - **No Docker rebuild needed!**
   - **No Kubernetes redeploy needed!**
4. **Test Changes**:
   - Place an order
   - See your code changes in action immediately
   - **Explain**: "The backend runs locally, so code changes are instant. But it still uses MongoDB and Payment API from Kubernetes via port forwarding!"

### Step 4: Show Hybrid Architecture

**Explain the setup:**
```
Local Machine:
  └─ Backend (localhost:3000) ← Runs locally, live code changes!
      ├─ MongoDB ← Port forward to K8s (localhost:27017)
      └─ Payment API ← Port forward to K8s (localhost:8082)

Kubernetes Cluster:
  ├─ MongoDB (mongodb:27017)
  ├─ Payment API (payment-api:8080)
  └─ Frontend (frontend:80) ← Port forward to localhost:8080
```

**Key Points:**
- Backend runs locally → Live code changes
- Port forwarding connects local backend to K8s services
- Frontend can still access backend (via port-forward or LoadBalancer)
- Webhooks work if backend has LoadBalancer IP or ngrok URL

### Step 5: Compare with Regular Port Forward

**Regular Port Forward:**
- All services in K8s
- No live code changes
- Simple setup

**Port Forward + Local Backend:**
- Backend runs locally
- Live code changes!
- Still uses K8s services via port forwarding
- Best of both worlds

**Talking Points**:
- "This hybrid approach gives you live code changes for the **backend** while still using Kubernetes services."
- "Port forwarding bridges the gap between local backend development and cluster services."
- "Perfect when you're actively developing the **backend** but want to use real K8s services."
- "Note: Frontend still runs in K8s - this is for **backend** development only."

---

## 🌐 Demo Flow: Ngrok (The Solution)

**Goal**: Show how ngrok enables webhooks to work

> **⚠️ Important**: With ngrok, services still run in Kubernetes pods. **Local code changes are NOT reflected** - you must rebuild and redeploy to see changes.

### Step 1: Stop Port Forwarding

```bash
# Stop port forwarding (Ctrl+C or run stop script)
./scripts/stop-port-forward.sh
```

### Step 2: Set Up Ngrok

```bash
# Start ngrok (creates public HTTPS tunnel)
./scripts/ngrok-start.sh

# This will:
# - Set up port forwarding
# - Create ngrok tunnel for backend
# - Update backend with ngrok URL
# - Restart backend to pick up new URL
```

**Output will show**:
- Backend (Ngrok): `https://abc123.ngrok.io`
- Frontend (Local): `http://localhost:8080`
- Webhook Demo: Orders will update in real-time!

### Step 3: Demonstrate Webhooks Working

1. **Open Frontend**: http://localhost:8080
2. **Open Orders Page**: http://localhost:8080/orders
   - Notice the success message: "Orders update in real-time via webhooks"
   - Connection method badge shows: **NGROK** (purple)
3. **Place an Order**:
   - Browse → Add to cart → Checkout → Place order
   - **Watch**: Order shows as "pending"
   - **Wait 15 seconds** (payment delay)
   - **Magic**: Order status automatically updates to **"approved"**!
   - **No refresh needed!**
   - **Explain**: "The payment service sent a webhook to our ngrok URL, which tunnels it to our backend"

### Step 4: Show Admin Dashboard with Ngrok

1. **Open Admin Dashboard**: http://localhost:8080/secret-admin-dashboard-xyz
2. **Show Service Visualization**:
   - Connection method: **NGROK** (purple indicator)
   - Webhook status: Enabled ✓
3. **Place Another Order** (while dashboard is open):
   - Watch request flow: Frontend → Backend → Payment Service
   - **After 15 seconds**: Webhook return arrow appears!
   - **Explain**: "You can see the complete request cycle, including the webhook callback"

### Step 5: Show Ngrok Web Interface

1. **Open Ngrok Dashboard**: http://localhost:4040
2. **Show Webhook Requests**:
   - Point out incoming webhook requests from payment service
   - Show request/response details
   - **Explain**: "Ngrok provides a web interface to inspect all traffic, including webhooks"

### Step 6: Check Backend Logs

```bash
# In a separate terminal
kubectl logs -f deployment/backend -n meetup3

# Place another order and watch logs
# You'll see:
# - Payment request sent successfully
# - Webhook received! (after 15 seconds)
# - Order status updated to approved
```

**Talking Points**:
- "Ngrok creates a public HTTPS tunnel, so external services can send webhooks. This is perfect for development and testing, but remember that free ngrok URLs change on restart."
- "**Important limitation**: Services run in Kubernetes, so local code changes require rebuilding Docker images and redeploying. No hot reload."

---

## 🔧 Demo Flow: Telepresence (Local Debugging)

**Goal**: Show local debugging with full webhook support

> **✅ Key Advantage**: With Telepresence, you intercept services to run them locally. **Local code changes ARE reflected** with hot reload! This is the only method that supports live development.

### Step 1: Stop Ngrok

```bash
# Stop ngrok
./scripts/stop-ngrok.sh
```

### Step 2: Set Up Telepresence

```bash
# Start telepresence
./scripts/telepresence-start.sh

# Choose option 1: Backend
# This will intercept the backend service
```

**What happens**:
- Telepresence connects to Kubernetes cluster
- Backend service is intercepted
- Traffic to backend in cluster routes to your local machine
- Backend environment updated to `CONNECTION_METHOD=telepresence`

### Step 3: Start Local Backend

```bash
# In a new terminal
cd apps/backend

# Set environment variables (or use env.example)
export MONGODB_URI=mongodb://mongodb.meetup3.svc.cluster.local:27017/honey-store
export PAYMENT_SERVICE_URL=http://payment-api.meetup3.svc.cluster.local:8080
export BACKEND_PUBLIC_URL=http://backend.meetup3.svc.cluster.local:3000

# Start local backend
npm run start:backend
```

**Key Point**: "Your local backend is now handling requests from the cluster, but you can debug it locally with breakpoints and hot reload!"

### Step 4: Demonstrate Local Debugging

1. **Open Frontend**: http://localhost:8080 (or use port-forward for frontend)
2. **Open Orders Page**: http://localhost:8080/orders
   - Connection method badge shows: **TELEPRESENCE** (orange)
   - Webhook status: Enabled ✓
3. **Add Debugging**:
   - Open `apps/backend/src/main.ts` in your IDE
   - Add a breakpoint in the webhook handler (around line 500+)
   - Or add `console.log('Webhook received!', req.body)` in webhook handler
4. **Place an Order**:
   - Browse → Add to cart → Checkout → Place order
   - **Watch**: Order shows as "pending"
   - **After 15 seconds**:
     - Breakpoint hits (if using debugger)
     - Console log appears in your local terminal
     - Order status updates to "approved"
   - **Explain**: "You can debug webhooks locally, set breakpoints, inspect the payload, and see exactly what the payment service sent"

### Step 5: Show Admin Dashboard with Telepresence

1. **Open Admin Dashboard**: http://localhost:8080/secret-admin-dashboard-xyz
2. **Show Service Visualization**:
   - Connection method: **TELEPRESENCE** (orange indicator)
   - Webhook status: Enabled ✓
3. **Place Another Order** (while dashboard is open):
   - Watch complete request flow including webhook
   - **Explain**: "Even though the backend is running locally, it's still part of the cluster network, so webhooks work perfectly"

### Step 6: Demonstrate Live Code Changes

> **This is the key differentiator of Telepresence!**

1. **Modify Webhook Handler**:
   - Edit `apps/backend/src/main.ts`
   - Add custom logging or modify webhook processing
   - Save the file
2. **Watch Hot Reload**:
   - Backend automatically restarts (if using nodemon/watch mode)
   - Changes take effect immediately
   - **No Docker rebuild needed!**
   - **No Kubernetes redeploy needed!**
3. **Place Another Order**:
   - See your changes in action immediately
   - **Explain**: "This is the power of Telepresence - you can develop and debug in real-time while connected to the full cluster environment. This is the ONLY method where local code changes are reflected without rebuilding Docker images or redeploying to Kubernetes."

**Talking Points**:
- "Telepresence is perfect for development because you get the best of both worlds: local debugging capabilities with full cluster connectivity, including webhooks."
- "**Key advantage**: This is the ONLY method where local code changes are reflected immediately with hot reload. Perfect for active development!"

---

## 🎤 Comparison Table

| Feature | Port Forward | Port Forward + Local Backend | Port Forward + Local All | Ngrok | Telepresence |
|---------|-------------|------------------------------|-------------------------|-------|--------------|
| **Setup Complexity** | ⭐ Simple | ⭐⭐ Medium | ⭐⭐ Medium | ⭐⭐ Medium | ⭐⭐⭐ Complex |
| **Webhook Support** | ✅ Yes (cluster DNS) | ✅ Yes* (if LoadBalancer/ngrok) | ✅ Yes* (if LoadBalancer/ngrok) | ✅ Yes | ✅ Yes |
| **Public Access** | ❌ No | ❌ No | ❌ No | ✅ Yes | ❌ No |
| **Local Debugging** | ✅ Yes (frontend only) | ✅ Yes (backend only) | ✅ Yes (both) | ❌ No | ✅ Yes |
| **Hot Reload / Live Code Changes** | ✅ Yes (frontend only) | ✅ Yes (backend only) | ✅ Yes (both) | ❌ No | ✅ Yes |
| **Code Changes Reflected** | ✅ Yes (frontend) | ✅ Yes (backend) | ✅ Yes (both) | ❌ No (must rebuild/redeploy) | ✅ Yes (hot reload) |
| **Uses K8s Services** | ✅ Yes (backend in K8s) | ✅ Yes (via port-forward) | ✅ Yes (via port-forward) | ✅ Yes (all) | ✅ Yes (via intercept) |
| **Best For** | **Frontend** development | **Backend** development | **Full-stack** development | Webhook testing | Full development (any service) |

---

## 🎬 Complete Demo Script (15-Minute Version)

### Part 1: Port Forward - Frontend Development (3 minutes)

1. **Setup** (1m)
   - Run `./scripts/port-forward.sh` (forwards backend)
   - Start local frontend: `cd apps/frontend && npm run start:frontend`
   - Open frontend at http://localhost:4200
   - **Emphasize**: "Frontend runs locally - code changes are live!"

2. **Demonstrate Live Frontend Changes** (1.5m)
   - Modify frontend code (change heading text)
   - Show hot reload in action
   - **Explain**: "Frontend runs locally, but uses backend in K8s via port forwarding"
   - Place an order - show webhooks work (backend in K8s)

3. **Wrap Up** (30s)
   - "Port forwarding enables frontend development"
   - "Frontend: local with live changes, Backend: K8s via port-forward"
   - "Webhooks work because backend is in K8s"

### Part 1.5: Port Forward + Local Backend - Backend Development (3 minutes)

1. **Setup** (1m)
   - Stop regular port forward
   - Run `./scripts/port-forward-local-backend.sh`
   - Start local backend with environment variables
   - **Emphasize**: "Backend runs locally - **backend** code changes are live!"

2. **Demonstrate Live Changes** (1.5m)
   - Modify **backend** code
   - Show hot reload in action
   - Place order - see changes immediately
   - **Explain**: "Backend runs locally, but uses K8s services via port forwarding. Frontend still in K8s."

3. **Wrap Up** (30s)
   - "Hybrid approach: local **backend** + K8s services"
   - "Best for **backend** development: live code changes + real K8s services"

### Part 2: Ngrok - The Solution (5 minutes)

1. **Setup** (1m)
   - Stop port forwarding
   - Run `./scripts/ngrok-start.sh`
   - Show ngrok URL
   - Explain: "This creates a public HTTPS tunnel"
   - **Emphasize**: "Services still run in Kubernetes - code changes require rebuild/redeploy"

2. **Demonstrate Solution** (3m)
   - Open orders page - show NGROK badge and success message
   - Place an order
   - Watch it automatically update after 15 seconds
   - Show admin dashboard - webhook return appears
   - Open ngrok web interface - show webhook requests
   - **Note**: "Webhooks work, but code changes still need rebuild/redeploy"

3. **Wrap Up** (1m)
   - "Ngrok enables webhooks by providing a public URL"
   - "Perfect for testing, but URLs change on restart"
   - "Still no live code changes - must rebuild/redeploy"

### Part 3: Telepresence - Local Debugging (7 minutes)

1. **Setup** (2m)
   - Stop ngrok
   - Run `./scripts/telepresence-start.sh`
   - Intercept backend
   - Start local backend with environment variables
   - Explain: "Backend runs locally but is part of cluster network"
   - **Emphasize**: "This is the KEY difference - backend runs locally, so code changes are live!"

2. **Demonstrate Debugging** (4m)
   - Open orders page - show TELEPRESENCE badge
   - Add breakpoint or console.log in webhook handler
   - Place an order
   - Show breakpoint hits / console output
   - Show order updates automatically
   - **Live Code Change Demo**:
     - Modify webhook handler code
     - Save file
     - Show hot reload in action (no rebuild needed!)
     - Place another order - see changes immediately
   - **Emphasize**: "This is the ONLY method where code changes are instant!"

3. **Wrap Up** (1m)
   - "Telepresence gives you local debugging with full cluster connectivity"
   - "Best for development when you need to debug webhooks"
   - "**Only method with live code changes** - perfect for active development"

---

## 🔧 Troubleshooting During Demo

## 📊 Admin Dashboard Deep Dive

The Admin Dashboard (`/secret-admin-dashboard-xyz`) is a powerful tool for all three connection methods:

### Features Available in All Modes

1. **Service Visualization**
   - Service nodes (Frontend, Backend, MongoDB, Payment Service)
   - Health indicators (green = healthy)
   - Connection method badge (PORT-FORWARD / NGROK / TELEPRESENCE)

2. **Request Flow Visualization**
   - Animated arrows showing requests between services
   - Real-time updates as requests happen
   - Color-coded by connection method

3. **Request Logs**
   - Detailed logs of all service-to-service calls
   - Request ID, source → destination
   - Method, path, status code, duration
   - Filterable and searchable

4. **Payment Configuration**
   - "Simulate Payment Error" toggle
   - Payment delay adjustment (currently 15 seconds)
   - Test error handling scenarios

### Connection Method Indicators

- **🔵 Blue (PORT-FORWARD)**: Webhooks work via cluster DNS (all services in K8s)
- **🟢 Green (PORT-FORWARD + LOCAL)**: Backend runs locally, webhooks work if LoadBalancer/ngrok
- **🟣 Purple (NGROK)**: Webhooks enabled via public URL, orders update automatically
- **🟠 Orange (TELEPRESENCE)**: Webhooks enabled, local debugging available

## 🏗️ Architecture Overview

```
Frontend (Angular)
  ↓ HTTP
Backend (Node.js/Express)
  ↓ HTTP
Payment Service (External - webhook-test)
  ↓ Webhook (async, 15 second delay)
Backend (receives webhook)
  ↓ Socket.IO
Frontend (real-time update)
```

### Key Technologies

- **Microservices**: Independent, scalable services
- **Webhooks**: Async communication pattern (demonstrated in Ngrok/Telepresence)
- **Socket.IO**: Real-time updates to frontend
- **Kubernetes**: Container orchestration
- **MongoDB**: Data persistence

## 🔧 Troubleshooting During Demo

### Port Forward Issues

**If Frontend Won't Load**
```bash
# Check if port forwarding is running
lsof -i :8080

# Restart port forwarding
./scripts/stop-port-forward.sh
./scripts/port-forward.sh
```

**If Orders Stay Pending (Expected with Port Forward)**
- This is normal! Port forwarding doesn't support webhooks
- Explain: "This is the limitation we're demonstrating"
- Move to Ngrok demo to show the solution

### Ngrok Issues

**If Ngrok Won't Start**
```bash
# Check if ngrok is installed
which ngrok

# Check if authenticated
ngrok config check

# If not authenticated:
ngrok authtoken YOUR_TOKEN
```

**If Webhooks Still Don't Work with Ngrok**
```bash
# Check backend logs for webhook URL
kubectl logs -n meetup3 -l app=backend | grep webhook

# Verify BACKEND_PUBLIC_URL is set
kubectl get deployment backend -n meetup3 -o jsonpath='{.spec.template.spec.containers[0].env}'

# Check ngrok web interface
# Open http://localhost:4040 and verify tunnel is active
```

**If Ngrok URL Changes**
- Free ngrok URLs change on restart
- Re-run `./scripts/ngrok-start.sh` to get new URL
- Backend will be automatically updated

### Telepresence Issues

**If Telepresence Won't Connect**
```bash
# Check telepresence status
telepresence status

# Reconnect
telepresence quit
telepresence connect
```

**If Local Backend Can't Connect to MongoDB**
```bash
# Verify MongoDB service name and namespace
kubectl get svc -n meetup3 | grep mongo

# Use correct service name in MONGODB_URI:
# mongodb://mongodb.<namespace>.svc.cluster.local:27017/honey-store
```

**If Webhooks Don't Work with Telepresence**
```bash
# Verify BACKEND_PUBLIC_URL is set correctly
# Should be: http://backend.<namespace>.svc.cluster.local:3000

# Check backend logs
# (will show in your local terminal if backend is intercepted)

# Verify payment service can reach backend
kubectl exec -n meetup3 -it deployment/backend -- curl -v http://backend.meetup3.svc.cluster.local:3000/health
```

### General Issues

**If Frontend Pod Won't Start**
```bash
# Check pod status
kubectl get pods -n meetup3 -l app=frontend
kubectl describe pod <pod-name> -n meetup3

# Check logs
kubectl logs -n meetup3 -l app=frontend --tail=50

# Restart if needed
kubectl rollout restart deployment/frontend -n meetup3
```

**If Backend Pod Won't Start**
```bash
# Check pod status
kubectl get pods -n meetup3 -l app=backend
kubectl describe pod <pod-name> -n meetup3

# Check logs
kubectl logs -n meetup3 -l app=backend --tail=50

# Restart if needed
kubectl rollout restart deployment/backend -n meetup3
```

**If Payment Service is Unreachable**
```bash
# Verify payment service is deployed in meetup3 namespace
kubectl get svc -n meetup3 | grep payment

# Test connectivity from backend pod
kubectl exec -n meetup3 -it deployment/backend -- curl -v http://payment-api:8080/health
```

## 📋 Pre-Demo Checklist

### Before Starting

- [ ] Verify cluster is accessible: `kubectl get pods -n meetup3`
- [ ] Verify all pods are running: `kubectl get pods -n meetup3`
- [ ] Check payment service is deployed: `kubectl get svc -n meetup3 | grep payment`
- [ ] Have ngrok installed and authenticated (for Ngrok demo)
- [ ] Have telepresence installed (for Telepresence demo)
- [ ] Test each connection method script works
- [ ] Have backup plan if cluster is not accessible

### For Each Connection Method

**Port Forward:**
- [ ] Script runs without errors
- [ ] Frontend accessible at http://localhost:8080
- [ ] Orders page shows PORT-FORWARD badge
- [ ] Test order stays pending (expected behavior)

**Ngrok:**
- [ ] Ngrok is authenticated
- [ ] Script runs and shows ngrok URL
- [ ] Frontend accessible at http://localhost:8080
- [ ] Orders page shows NGROK badge
- [ ] Test order updates automatically after 15 seconds

**Telepresence:**
- [ ] Telepresence can connect to cluster
- [ ] Local backend can start with correct env vars
- [ ] Frontend accessible (via port-forward or LoadBalancer)
- [ ] Orders page shows TELEPRESENCE badge
- [ ] Test order updates automatically
- [ ] Can set breakpoints and debug locally

## 🎬 Quick Demo Scripts

### 5-Minute Version (Port Forward Only)

1. **Introduction** (30s)
   - "Microservices e-commerce app on Kubernetes"
   - "Demonstrating connection methods and webhook challenges"

2. **Port Forward Demo** (2m)
   - Set up port forwarding
   - Place order, show it stays pending
   - Explain webhook limitation

3. **Ngrok Solution** (2m)
   - Switch to ngrok
   - Place order, show automatic update
   - Explain how ngrok enables webhooks

4. **Wrap Up** (30s)
   - Quick comparison
   - Q&A

### 10-Minute Version (All Three Methods)

Follow the complete demo flow above:
- Port Forward (3m) - Show the problem
- Ngrok (4m) - Show the solution
- Telepresence (3m) - Show local debugging

### 15-Minute Version (Full Deep Dive)

Follow the complete demo flow plus:
- Detailed admin dashboard walkthrough
- Show error simulation
- Explain architecture in detail
- Show Kubernetes resources
- Discuss scaling and deployment strategies
- Live debugging demonstration with Telepresence

## 📚 Quick Reference Commands

### Port Forward (Frontend Development)
```bash
# Start port forwarding for backend
./scripts/port-forward.sh

# In new terminal, start local frontend:
cd apps/frontend
npm run start:frontend

# Access
# Frontend: http://localhost:4200 (local)
# Backend: http://localhost:3000 (K8s via port-forward)

# Stop
./scripts/stop-port-forward.sh
# (Stop frontend separately with Ctrl+C)
```

### Port Forward + Local Backend
```bash
# Start port forwarding for K8s services
./scripts/port-forward-local-backend.sh

# In new terminal, start local backend:
cd apps/backend
export MONGODB_URI=mongodb://localhost:27017/honey-store
export PAYMENT_SERVICE_URL=http://localhost:8082
export CONNECTION_METHOD=port-forward
npx nx build backend && nodemon dist/apps/backend/main.js

# Stop
./scripts/stop-port-forward-local-backend.sh
# (Stop backend separately with Ctrl+C)
```

### Port Forward + Local All
```bash
# Start port forwarding for K8s services
./scripts/port-forward-local-all.sh

# Terminal 1 - Backend:
cd apps/backend
export MONGODB_URI=mongodb://localhost:27017/honey-store
export PAYMENT_SERVICE_URL=http://localhost:8082
export CONNECTION_METHOD=port-forward
npx nx build backend && nodemon dist/apps/backend/main.js

# Terminal 2 - Frontend:
cd apps/frontend
npm run start:frontend

# Stop
./scripts/stop-port-forward-local-all.sh
# (Stop frontend and backend separately with Ctrl+C)
```

### Ngrok
```bash
# Start
./scripts/ngrok-start.sh

# Stop
./scripts/stop-ngrok.sh

# Access
# Frontend: http://localhost:8080
# Backend: https://<ngrok-url>.ngrok.io
# Ngrok Dashboard: http://localhost:4040
# Admin: http://localhost:8080/secret-admin-dashboard-xyz
```

### Telepresence
```bash
# Start
./scripts/telepresence-start.sh
# Choose: 1) Backend

# In separate terminal, start local backend:
cd apps/backend
export MONGODB_URI=mongodb://mongodb.meetup3.svc.cluster.local:27017/honey-store
export PAYMENT_SERVICE_URL=http://payment-api.meetup3.svc.cluster.local:8080
export BACKEND_PUBLIC_URL=http://backend.meetup3.svc.cluster.local:3000
npm run start:backend

# Stop
./scripts/stop-telepresence.sh
```

### Useful kubectl Commands
```bash
# Check pods
kubectl get pods -n meetup3

# Check services
kubectl get svc -n meetup3

# View logs
kubectl logs -f deployment/backend -n meetup3
kubectl logs -f deployment/frontend -n meetup3

# Restart services
kubectl rollout restart deployment/backend -n meetup3
kubectl rollout restart deployment/frontend -n meetup3

# Check environment variables
kubectl get deployment backend -n meetup3 -o jsonpath='{.spec.template.spec.containers[0].env}'
```

## 🎯 Key Demo Points Summary

### Port Forward (Frontend Development)
- ✅ **Frontend runs locally** (live code changes for frontend!)
- ✅ Backend in K8s accessed via port forwarding
- ✅ **Webhooks work** (backend in K8s, services use cluster DNS)
- ⚠️ Only **frontend** has live changes (backend in K8s)
- **Use Case**: Active **frontend** development with K8s backend

### Port Forward + Local Backend
- ✅ **Backend runs locally** (live code changes for backend!)
- ✅ Uses K8s services via port forwarding
- ✅ Webhooks work if backend has LoadBalancer/ngrok
- ⚠️ Only **backend** has live changes (frontend and other services in K8s)
- **Use Case**: Active **backend** development, want to use K8s services

### Port Forward + Local All
- ✅ **Both frontend AND backend run locally** (live code changes for both!)
- ✅ Uses K8s services via port forwarding
- ✅ Webhooks work if backend has LoadBalancer/ngrok
- **Use Case**: Active **full-stack** development, want to use K8s services

### Ngrok
- ✅ Public HTTPS URL
- ✅ Webhooks work perfectly
- ✅ Orders update automatically
- ✅ Web interface for traffic inspection
- ⚠️ URLs change on restart (free tier)
- ❌ **Local code changes NOT reflected** (must rebuild/redeploy)
- **Use Case**: Webhook testing, sharing with team, no active development

### Telepresence
- ✅ Local debugging with breakpoints
- ✅ **Hot reload - local code changes reflected immediately!**
- ✅ Webhooks work perfectly
- ✅ Full cluster network access
- ⚠️ More complex setup
- **Use Case**: Active development, debugging webhooks locally, live code changes

---

**Good luck with your demo! 🍯✨**

