# Debugging Microservices: From Local to Cloud
## Presentation Plan

---

## 1. The Beginning: All Local Development

**Scenario:** Early stage development - small team, simple architecture

**Setup:**
- All microservices run on developer's local machine
- Frontend, Backend, Payment Service, Database - everything local
- Full control and easy debugging
- Set breakpoints anywhere, instant feedback

**Why this works:**
- Small number of services
- Lightweight resource requirements
- Fast iteration cycles
- Simple mental model

---

## 2. The Growth Problem: Too Many Services

**What Changed:**
- Team grows, architecture expands
- 5 services → 10 services → 20+ services
- Each service needs: CPU, memory, ports, dependencies

**The Breaking Point:**
- Laptop can't handle running 20+ services simultaneously
- Services crash due to memory constraints
- Port conflicts everywhere (8080, 3000, 5432...)
- Developer machine becomes unusably slow

**The Decision:**
- Move services to the cloud (Kubernetes cluster)
- Keep only essential services local for active development

---

## 3. Solution #1: Port Forwarding - Hybrid Approach

**The Strategy:**
- Run frontend locally (the UI you're actively developing)
- All other services run in Kubernetes cluster
- Use `kubectl port-forward` to access cloud services as if they were local

**How Port Forwarding Works:**
```bash
kubectl port-forward svc/backend 3000:3000
```
- Creates a tunnel from your local machine to the Kubernetes pod
- Local `localhost:3000` → forwards to → K8s backend pod
- From frontend's perspective, backend is "local"
- No code changes needed - same URLs work

**Benefits:**
- Lightweight - only run what you're working on
- Real production environment for other services
- Easy to set up and tear down

**Technical Details:**
- SSH-like tunnel through kubectl
- Traffic encrypted through K8s API server
- Multiple port-forwards can run simultaneously
- Example: `localhost:3000` (backend), `localhost:27017` (MongoDB)

---

## 4. Problem #2: Need to Debug Other Services

**Scenario:**
- Bug appears in the payment service
- Need to step through payment processing logic
- Can't set breakpoints in a K8s pod

**Solution - Extend Port Forwarding:**

**Step 1:** Run payment service locally with debugger
```bash
# Start local payment service with debugger
npx tsx --inspect apps/payment-service/src/main.ts
```

**Step 2:** Port-forward dependencies
```bash
kubectl port-forward svc/backend 3000:3000
kubectl port-forward svc/mongodb 27017:27017
```

**Step 3:** Scale down K8s version to avoid conflicts
```bash
kubectl scale deployment payment-api --replicas=0
```

**Why This Works:**
- Local service can connect to K8s services via port-forward
- Full debugging capabilities (breakpoints, variable inspection)
- Other services (backend, MongoDB) still use production config
- Isolate just the component you're debugging

---

## 5. Problem #3: Webhooks Don't Work

**The Webhook Problem:**

**Scenario:**
- Payment service processes payment
- After 2 seconds, needs to call backend webhook: `http://backend:3000/api/webhook/payment`
- Payment service running locally
- Webhook call **fails** ❌

**Why it Fails:**
- Payment service tries to call `http://backend:3000`
- But "backend" resolves to K8s internal DNS
- K8s tries to route traffic to... nothing (scaled down to 0 replicas)
- Even if we keep backend in K8s, backend can't call back to our local machine

**The Core Issue:**
- Port-forward is **one-way**: Local → K8s works
- Reverse direction (K8s → Local) **doesn't work**
- Your laptop isn't accessible from the internet
- No public IP, no incoming route

---

## 6. Solution #2: Ngrok - Public Tunnel

**What is Ngrok:**
- Creates a secure tunnel from internet to your local machine
- Gives you a public URL: `https://abc123.ngrok.io`
- Forwards all traffic from that URL to `localhost:3000`

**How to Use Ngrok:**

**Step 1:** Start ngrok tunnel
```bash
ngrok http 3000
# Output: https://abc123.ngrok.io → localhost:3000
```

**Step 2:** Update service configuration
```bash
# Tell payment service to use ngrok URL for webhooks
export BACKEND_PUBLIC_URL=https://abc123.ngrok.io
export WEBHOOK_URL=https://abc123.ngrok.io/api/webhook/payment
```

**Step 3:** Payment service sends webhook to public URL
```javascript
// Payment service code
axios.post('https://abc123.ngrok.io/api/webhook/payment', {
  orderId: '123',
  status: 'approved'
})
```

**The Flow:**
1. Payment service (local) processes payment
2. Sends webhook to `https://abc123.ngrok.io/api/webhook/payment`
3. Ngrok tunnel receives request
4. Forwards to `localhost:3000/api/webhook/payment`
5. Local backend receives webhook! ✅

**Benefits:**
- Webhooks work from anywhere (K8s, external services)
- Can test with real external webhooks (Stripe, PayPal)
- HTTPS included (important for many webhooks)
- Can share URL with teammates for testing

**Limitations:**
- URL changes each time (free tier)
- Adds latency
- Requires manual configuration of webhook URLs
- Only works for services YOU'RE running locally

---

## 7. Problem #4: Production-Only Bugs

**The Nightmare Scenario:**

**What Happened:**
- Demoing new feature to stakeholders
- Everything works locally
- Deploy to production...
- **Bug appears** ❌ Order fails with mysterious error

**Investigation Attempts:**
1. Check logs - not enough detail
2. Try to reproduce locally - can't reproduce!
3. Add more logging, redeploy - still unclear
4. Bug only happens with specific data in production

**Why Local Development Failed:**
- Different environment variables
- Different timing (network latency)
- Different data (production has edge cases)
- Different service interactions
- Issue only appears in K8s environment

**What We Need:**
- Debug the ACTUAL service running in K8s
- But with a debugger (breakpoints, step-through)
- Without redeploying or modifying the cluster
- Ideally without affecting other developers

---

## 8. Solution #3: Telepresence - The Ultimate Tool

**What is Telepresence:**
- Runs on your local machine AND in the K8s cluster
- Intercepts traffic going to a K8s service
- Redirects that traffic to your local machine
- Makes your laptop "part of the cluster"

**How Telepresence Works:**

**Architecture:**
```
[K8s Cluster]
  ├── Frontend Pod
  ├── Backend Pod
  ├── Payment Pod ← Traffic Manager intercepts here
  └── Traffic Manager (Telepresence agent)
           ↓
      [Internet]
           ↓
  [Your Laptop]
     └── Telepresence client
         └── Local payment service (with debugger)
```

**The Setup:**

**Step 1:** Install Telepresence locally
```bash
brew install telepresence
```

**Step 2:** Install Traffic Manager in cluster (one-time, by DevOps)
```bash
telepresence helm install --namespace ambassador
```

**Step 3:** Connect to cluster
```bash
telepresence connect --namespace your-namespace
```

**Step 4:** Start intercept
```bash
telepresence intercept payment-api --port 8080:8080
```

**Step 5:** Run local service with debugger
```bash
npx tsx --inspect apps/payment-service/src/main.ts
# Debugger listening on ws://127.0.0.1:9229
```

**What Happens:**

1. **Backend sends request** to `http://payment-api:8080/api/payment`
   - Backend doesn't know anything changed
   - Uses normal K8s service DNS

2. **Traffic Manager intercepts** the request
   - Sees it's going to `payment-api`
   - Checks: "Is this service being intercepted?"
   - Yes! Intercept is active

3. **Request forwarded to your laptop**
   - Traffic Manager routes to your local machine
   - Your local service receives the request
   - **Breakpoint hits!** 🎯

4. **Full K8s environment available**
   - Your local service can call other K8s services
   - DNS works: `http://backend:3000` resolves to K8s backend
   - MongoDB: `mongodb://mongodb:27017` works
   - It's like your laptop is inside the cluster

5. **Response flows back**
   - Your local service returns response
   - Goes back through Traffic Manager
   - Backend receives response
   - Backend thinks it talked to K8s pod (no idea it was your laptop!)

**The Power:**
- Debug production issues IN production environment
- No deployment needed
- No code changes needed
- Other developers unaffected (optional: can target specific requests)
- Works with webhooks (your local service has full network access)

---

## 9. Telepresence Advanced Features

**Selective Interception (Preview/Personal Intercepts):**

**The Problem:**
- Multiple developers working on same service
- Don't want to intercept everyone's traffic
- Only want YOUR test requests

**The Solution (Enterprise/Paid Feature):**
```bash
telepresence intercept payment-api \
  --port 8080:8080 \
  --http-header=x-developer=username
```

**How It Works:**
- Only requests with header `x-developer: username` get intercepted
- Everyone else's requests go to K8s pod normally
- You can test in production without affecting team

**Other Advanced Features:**
1. **Multiple simultaneous intercepts**
   - Debug frontend AND backend at same time

2. **Preview URLs**
   - Get unique URL that routes only to your laptop
   - Share with QA for testing your changes

3. **Environment variable sync**
   - Automatically copies K8s pod's env vars to local
   - Ensures exact same configuration

**Note for Demo:**
- We'll demonstrate basic intercept (shown previously)
- Advanced selective interception requires paid version
- We won't demo this, but it's powerful for team collaboration

---

## 10. Summary: Evolution of Debugging

| Stage | Approach | Pros | Cons | When to Use |
|-------|----------|------|------|-------------|
| **All Local** | Everything on laptop | Full control, easy debugging | Resource intensive, doesn't scale | Early development, 1-5 services |
| **Port Forward** | Frontend local, rest in K8s | Lightweight, real environment | One-way only, can't debug K8s services | Active UI development |
| **Port Forward + Local Service** | Run service locally, forward dependencies | Can debug specific service | Manual setup, no webhooks | Debugging specific service |
| **Ngrok** | Public tunnel for webhooks | Webhooks work | Manual config, only for YOUR services | Webhook testing |
| **Telepresence** | Intercept K8s traffic | Debug in production, no deployment | Requires cluster setup | Production bugs, complex scenarios |

---

## 11. Demo Flow (What We'll Show)

**The Story:** Follow a developer's journey from simple to complex debugging scenarios.

---

### Demo 1: The Beginning - All Local (Too Heavy!)

**Scenario:** "Let me show you how we used to develop..."

**Commands:**
```bash
# Try to start everything locally
pnpm start:frontend &    # Frontend on port 4200
pnpm start:backend &     # Backend on port 3000
pnpm start:payment &     # Payment on port 8080
# MongoDB, Redis, etc...
```

**Show:**
- Multiple terminals running
- Activity Monitor showing high CPU/memory usage
- "This worked when we had 3 services... but now we have 10+"
- Laptop fan spinning up 🌪️

**Transition:** "We need a better way. Let's move services to Kubernetes."

---

### Demo 2: Port Forward Solution - Lightweight Development

**Scenario:** "Now let's be smart about it. Only run what we need locally."

**Command:**
```bash
pnpm dev:frontend
```

**What Happens Behind the Scenes:**
```bash
# Script automatically:
# 1. Configures frontend to use K8s backend
# 2. Port-forwards backend: kubectl port-forward svc/backend 3000:3000
# 3. Starts frontend on localhost:4200
```

**Show:**
- Open browser to `http://localhost:4200`
- Browse products (frontend local, backend K8s) ✅
- Add to cart ✅
- Create order ✅
- Order goes to "processing" ✅

**Point Out:**
- "See? Much lighter! Only frontend running locally"
- "Backend, payment service, MongoDB all in K8s"
- "Port-forward makes K8s services feel local"

**Transition:** "But what if we need to debug the backend?"

---

### Demo 3: Debug Backend Locally - Extending the Solution

**Scenario:** "Bug in backend API. Let's debug it with breakpoints."

**Setup (quickly show):**
```bash
# In separate terminal
pnpm dev:backend
```

**What Happens Behind the Scenes:**
```bash
# Script automatically:
# 1. Scales down K8s backend (replicas=0)
# 2. Port-forwards MongoDB and Payment service
# 3. Detects ngrok if running
# 4. Starts backend with auto-reload (tsx --watch)
```

**Show:**
- Backend starts locally
- Open `apps/backend/src/main.ts` in VS Code
- Set breakpoint on order creation endpoint (around line 425)
- Create order from frontend
- **Breakpoint hits!** 🎯
- Step through code
- Inspect variables
- See order being saved to MongoDB

**Point Out:**
- "Backend local, everything else in K8s"
- "Can debug with full context"
- "Port-forward gives us access to K8s services"

**Transition:** "But wait... the payment webhook isn't working..."

---

### Demo 4: The Webhook Problem

**Show:**
- Order stuck in "processing" ❌
- Check backend logs: "Payment completed but webhook not received"
- Explain: "Payment service sends webhook to `http://backend:3000/api/webhook/payment`"
- "But K8s can't reach our laptop!"

**Visual:**
```
[Payment in K8s] --webhook--> [backend:3000] ❌
                                  (doesn't exist in K8s)
[Payment in K8s] --webhook--> [My Laptop] ❌
                                  (not accessible from internet)
```

**Transition:** "This is where ngrok comes in..."

---

### Demo 5: Ngrok - Making Local Publicly Accessible

**Scenario:** "Let's give our local backend a public URL."

**Command:**
```bash
# In another terminal
pnpm dev:ngrok
```

**What Happens:**
```bash
# Starts ngrok tunnel to localhost:3000
# Outputs: https://abc123.ngrok.io → localhost:3000
```

**Show:**
- Ngrok terminal showing public URL
- **Now restart backend** to detect ngrok:
```bash
pnpm dev:backend
# Detects ngrok automatically
# Sets BACKEND_PUBLIC_URL=https://abc123.ngrok.io
```

**Show:**
- Backend logs: "✅ Ngrok detected: https://abc123.ngrok.io"
- Create new order
- Payment service sends webhook to ngrok URL
- Webhook arrives at local backend! ✅
- Order status updates to "approved" ✅

**Show in Browser:**
- Order list refreshes
- Status changes from "processing" → "approved"
- Real-time update via Socket.IO

**Point Out:**
- "Ngrok creates public tunnel"
- "Payment service (in K8s) can now reach our laptop"
- "Works for any external webhooks too (Stripe, PayPal, etc.)"

**Transition:** "Great! But what about production bugs we can't reproduce locally?"

---

### Demo 6: The Production Bug - Telepresence to the Rescue

**Scenario:** "Stakeholder reports: Order #123 failed in production. Can't reproduce locally."

**The Problem:**
- Bug only happens in production environment
- Specific data combination
- Need to debug LIVE in K8s

**Command:**
```bash
pnpm debug:payment
```

**What Happens Behind the Scenes:**
```bash
# Script automatically:
# 1. Connects to Telepresence: telepresence connect
# 2. Cleans up existing intercepts
# 3. Starts intercept: telepresence intercept payment-api --port 8080:8080
# 4. Runs local payment service with debugger
```

**Show Terminal Output:**
```
✔ Intercepted
   Using Deployment payment-api
      State             : ACTIVE
      Intercepting      : <pod-ip> -> 127.0.0.1
          8080 -> 8080 TCP

🐛 Starting local payment service with debugger...
   Debugger: ws://127.0.0.1:9229

🌐 Frontend: http://<frontend-ip>
   (Create an order to trigger payment flow)

Debugger attached.
```

**Show VS Code:**
- Open `apps/payment-service/src/main.ts`
- Set breakpoint in payment processing logic
- Show VS Code debugger attached (green dot)

**Show Browser:**
- Open K8s frontend: `http://<frontend-ip>`
- (Everything is in K8s - NOT localhost!)
- Create order with specific product

**The Magic Moment:**
- Order creation sends payment request
- K8s backend calls payment service
- Telepresence intercepts the call
- **VS Code breakpoint hits!** 🎯🎉

**Show in VS Code:**
- Execution paused at breakpoint
- Inspect `paymentRequest` variable
- See actual production data
- Step through code line by line
- Watch webhook being sent
- See response returned

**Show Backend Logs:**
```
Payment webhook received: {
  orderId: '<order-id>',
  paymentId: '<payment-id>',
  status: 'approved'
}
```

**Show Browser:**
- Order status updates to "approved" in real-time
- Everything works! ✅

**The Reveal:**
```
"This is the production environment.
Frontend: K8s ✅
Backend: K8s ✅
Payment Service: My laptop with debugger! 🎯
MongoDB: K8s ✅

But from the system's perspective, payment service is just another K8s pod.
The magic is Telepresence routing traffic to my laptop!"
```

**Point Out:**
- No code changes
- No redeployment
- No downtime
- Other developers unaffected
- Full K8s environment access
- Production data
- Real network latency
- Actual service interactions

**Cleanup:**
```bash
# Ctrl+C in debug:payment terminal
# Automatically cleans up intercept and quits Telepresence
```

---

### Demo 7: Comparison Summary

**Show Side-by-Side:**

| Approach | What's Local | What's K8s | Webhooks Work? | Can Debug Production? |
|----------|--------------|------------|----------------|----------------------|
| All Local | Everything | Nothing | ✅ (all local) | ❌ |
| Port-Forward | Frontend | Backend, Payment, DB | ❌ | ❌ |
| Port-Forward + Local Backend | Frontend, Backend | Payment, DB | ❌ | ❌ |
| Port-Forward + Ngrok | Frontend, Backend | Payment, DB | ✅ | ❌ |
| **Telepresence** | Payment (with debugger) | Frontend, Backend, DB | ✅ | ✅ 🎯 |

**Final Point:**
"Each tool solves a specific problem. Start simple, escalate when needed."

---

### Post-Demo: Quick Setup Reference

**For attendees to try later:**

```bash
# Port-forward development
pnpm dev:frontend          # Frontend local, rest K8s

# Debug backend locally
pnpm dev:backend           # Backend local with port-forwards

# Enable webhooks
pnpm dev:ngrok            # Start ngrok tunnel
pnpm dev:backend          # Restart to detect ngrok

# Debug in production
pnpm debug:payment        # Telepresence intercept with debugger
```

**All commands handle:**
- ✅ Setup and teardown
- ✅ Port conflicts
- ✅ Service scaling
- ✅ Clean Ctrl+C exit

---

## 12. Key Takeaways

1. **Start Simple:** Local development works until it doesn't
2. **Hybrid is Smart:** Mix local and cloud strategically
3. **Tools for Every Problem:** Port-forward → Ngrok → Telepresence
4. **Telepresence is Game-Changing:** Debug production without deployment
5. **Choose the Right Tool:** Not every problem needs Telepresence

**Final Thought:**
The goal isn't to use the most advanced tool - it's to use the simplest tool that solves your current problem. Start with port-forward, escalate to Telepresence only when needed.

---

## Appendix: Quick Reference Commands

### Port Forwarding
```bash
kubectl port-forward svc/backend 3000:3000 -n your-namespace
kubectl port-forward svc/mongodb 27017:27017 -n your-namespace
kubectl scale deployment backend --replicas=0 -n your-namespace
```

### Ngrok
```bash
ngrok http 3000
# Use the https URL provided
export BACKEND_PUBLIC_URL=<ngrok-url>
```

### Telepresence
```bash
# Connect
telepresence connect --namespace your-namespace

# Start intercept
telepresence intercept payment-api --port 8080:8080

# Run local service
npx tsx --inspect apps/payment-service/src/main.ts

# Stop intercept
telepresence leave payment-api

# Disconnect
telepresence quit
```

### VS Code Debug
```json
{
  "type": "node",
  "request": "attach",
  "name": "Attach to Node",
  "port": 9229,
  "restart": true
}
```
