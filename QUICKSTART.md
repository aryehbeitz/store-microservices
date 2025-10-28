# 🚀 Quick Start Guide

Get the Honey Store up and running in 5 minutes!

## Prerequisites

- Node.js 18+
- Docker
- kubectl
- Minikube or K3s

> **Don't have these?** See [docs/SETUP.md](docs/SETUP.md) for installation instructions.

## 3-Step Setup

### Step 1: Install Dependencies

```bash
npm install
```

**Time:** ~2 minutes

---

### Step 2: Start Kubernetes & Build Images

```bash
./scripts/rebuild-dependencies.sh
```

**This will:**
- ✓ Start your Kubernetes cluster (Minikube or K3s)
- ✓ Build Docker images for all services
- ✓ Configure Docker environment

**Time:** ~3-5 minutes

---

### Step 3: Deploy Services

```bash
./scripts/deploy-changes.sh
```

**This will:**
- ✓ Deploy MongoDB
- ✓ Deploy Backend
- ✓ Deploy Payment Service
- ✓ Deploy Frontend

**Time:** ~1 minute

---

## Access the Application

### Option 1: Port Forwarding (Easiest)

```bash
./scripts/port-forward.sh
```

**Open in browser:**
- **Store:** http://localhost:8080
- **Admin Dashboard:** http://localhost:8080/secret-admin-dashboard-xyz

Press `Ctrl+C` to stop.

---

### Option 2: Ngrok (Public URLs)

```bash
./scripts/ngrok-start.sh
```

Get public HTTPS URLs for all services!

---

### Option 3: Telepresence (Development)

```bash
./scripts/telepresence-start.sh
```

Debug locally while connected to the cluster!

**Then run local services:**
```bash
# In separate terminals:
npm run start:backend    # If intercepting backend
npm run start:payment    # If intercepting payment service
```

---

## Try It Out

### 1. Shop for Honey 🍯

1. Go to http://localhost:8080
2. Browse products
3. Add items to cart
4. Go to checkout
5. Fill in your details
6. Place order!

### 2. Monitor Services 📊

1. Open **Admin Dashboard**: http://localhost:8080/secret-admin-dashboard-xyz
2. Watch live request flows
3. See service health
4. View logs in real-time

### 3. Simulate Payment Error 🔴

1. In Admin Dashboard, toggle **"Simulate Payment Error"**
2. Place a new order
3. Watch it fail in real-time!
4. See red indicators and error logs

### 4. Test Orders Page 📋

1. Go to **Orders page**: http://localhost:8080/orders
2. Place an order and see it appear
3. Notice the connection method indicators:
   - **Port Forward**: Orders stay "pending" (no webhooks)
   - **Telepresence/Ngrok**: Orders update automatically (real webhooks)
4. Try retrying failed payments

---

## What's Next?

- 📖 Read the [Architecture Guide](docs/ARCHITECTURE.md)
- 🛠️ Check the [Full Setup Guide](docs/SETUP.md)
- 🎨 Customize products in `apps/frontend/src/app/services/product.service.ts`
- 🔧 Modify services and rebuild

---

## Common Commands

```bash
# Stop port forwards
./scripts/stop-port-forward.sh

# Stop ngrok
./scripts/stop-ngrok.sh

# Stop telepresence
./scripts/stop-telepresence.sh

# Check pod status
kubectl get pods

# View logs
kubectl logs -f deployment/backend

# Rebuild and redeploy
./scripts/rebuild-dependencies.sh
./scripts/deploy-changes.sh
```

---

## Troubleshooting

### Pods won't start?

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Port already in use?

```bash
./scripts/stop-port-forward.sh
lsof -ti:3000 | xargs kill -9
```

### Need to restart everything?

```bash
minikube delete
minikube start --cpus=4 --memory=4096
./scripts/rebuild-dependencies.sh
./scripts/deploy-changes.sh
```

---

## Support

For detailed help, see:
- [Full Setup Guide](docs/SETUP.md)
- [Architecture Documentation](docs/ARCHITECTURE.md)
- [Main README](README.md)

---

**Happy coding! 🍯✨**
