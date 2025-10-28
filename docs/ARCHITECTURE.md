# 🏗️ Honey Store - Architecture Documentation

## System Overview

The Honey Store is a microservices-based e-commerce application demonstrating modern cloud-native architecture patterns.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         Browser                              │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │           Angular Frontend (SPA)                    │    │
│  │  - Product Catalog                                  │    │
│  │  - Shopping Cart (localStorage)                     │    │
│  │  - Checkout Form                                    │    │
│  │  - Admin Dashboard (Socket.io client)              │    │
│  └──────────────┬──────────────────┬───────────────────┘    │
└─────────────────┼──────────────────┼────────────────────────┘
                  │                  │
         HTTP/REST│           WebSocket (Socket.io)
                  │                  │
      ┌───────────▼──────────────────▼───────────┐
      │      Backend Service (Node.js/Express)   │
      │                                           │
      │  ┌─────────────────────────────────┐    │
      │  │  REST API Endpoints              │    │
      │  │  - GET  /api/orders              │    │
      │  │  - POST /api/orders              │    │
      │  │  - GET  /health                  │    │
      │  └─────────────────────────────────┘    │
      │                                           │
      │  ┌─────────────────────────────────┐    │
      │  │  Socket.io Server                │    │
      │  │  - Service status broadcasts     │    │
      │  │  - Request log streaming         │    │
      │  │  - Admin config sync             │    │
      │  └─────────────────────────────────┘    │
      │                                           │
      │  ┌─────────────────────────────────┐    │
      │  │  Webhook Endpoint                │    │
      │  │  - POST /api/webhook/payment     │    │
      │  └─────────────────────────────────┘    │
      └────┬──────────────────┬──────────────────┘
           │                  │
           │                  │ HTTP POST (async)
           │                  │
           │                  ▼
           │         ┌────────────────────────────┐
           │         │  Payment Service           │
           │         │  (Node.js/Express)         │
           │         │                            │
           │         │  - Process payments        │
           │         │  - Simulate delays         │
           │         │  - Send webhooks           │
           │         │  - Admin controls          │
           │         └────────────────────────────┘
           │
           ▼
    ┌──────────────┐
    │   MongoDB    │
    │              │
    │  - Orders    │
    │  - Metadata  │
    └──────────────┘
```

## Service Descriptions

### Frontend (Angular)

**Technology Stack:**
- Angular 17
- TypeScript
- RxJS
- Socket.io-client
- HTML/CSS

**Responsibilities:**
- Product catalog display with filtering
- Shopping cart management (localStorage)
- Order checkout flow
- Real-time admin monitoring dashboard
- WebSocket communication for live updates

**Key Features:**
- Responsive design
- LocalStorage persistence
- Real-time service visualization
- Animated request flow indicators
- Connection method detection

**Routes:**
- `/` - Product list
- `/cart` - Shopping cart
- `/checkout` - Checkout form
- `/secret-admin-dashboard-xyz` - Admin dashboard

---

### Backend Service (Express)

**Technology Stack:**
- Node.js
- Express
- Mongoose (MongoDB ODM)
- Socket.io
- Axios

**Responsibilities:**
- Order management
- MongoDB integration
- Payment service orchestration
- Webhook handling
- Real-time monitoring via Socket.io

**API Endpoints:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/api/orders` | List all orders |
| GET | `/api/orders/:id` | Get specific order |
| POST | `/api/orders` | Create new order |
| POST | `/api/webhook/payment` | Payment webhook handler |

**Socket.io Events:**

| Event | Direction | Description |
|-------|-----------|-------------|
| `connection` | Client → Server | Admin client connected |
| `service-status` | Server → Client | Service health update |
| `request-log` | Server → Client | HTTP request logged |
| `admin-config` | Server → Client | Configuration broadcast |
| `update-admin-config` | Client → Server | Update configuration |

**Data Flow:**

1. **Order Creation:**
   ```
   Frontend → POST /api/orders → Backend
       ↓
   Save to MongoDB
       ↓
   Trigger async payment
       ↓
   Return order ID
   ```

2. **Payment Processing:**
   ```
   Backend → POST /api/payment → Payment Service
       ↓
   (async delay)
       ↓
   Payment Service → POST /api/webhook/payment → Backend
       ↓
   Update order status in MongoDB
   ```

---

### Payment Service (Express)

**Technology Stack:**
- Node.js
- Express
- Socket.io
- Axios

**Responsibilities:**
- Async payment processing
- Configurable delay simulation
- Webhook callbacks
- Error simulation (for testing)

**API Endpoints:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/api/payment` | Process payment request |

**Processing Flow:**

1. Receive payment request from backend
2. Return immediate 202 (Accepted) response
3. Wait for configured delay (default 2s)
4. Determine success/failure based on admin config
5. Send webhook to backend with result

**Admin Controls:**
- `simulatePaymentError`: Toggle payment failures
- `paymentDelayMs`: Adjust processing time (500ms - 5000ms)

---

### MongoDB

**Technology Stack:**
- MongoDB 7
- Persistent Volume Claims (Kubernetes)

**Collections:**

**orders:**
```javascript
{
  _id: ObjectId,
  items: [{
    product: {
      id: String,
      name: String,
      price: Number,
      // ... other product fields
    },
    quantity: Number
  }],
  total: Number,
  customerName: String,
  customerEmail: String,
  shippingAddress: String,
  paymentStatus: 'pending' | 'approved' | 'rejected' | 'error',
  createdAt: Date,
  updatedAt: Date
}
```

---

## Communication Patterns

### 1. Synchronous REST API

**Pattern:** Request-Response
**Use case:** CRUD operations, immediate responses

```
Client → HTTP Request → Server → Response → Client
```

**Examples:**
- Fetching products
- Creating orders
- Getting order status

---

### 2. Asynchronous Processing

**Pattern:** Fire-and-Forget with Callback
**Use case:** Long-running operations

```
Backend → Payment Request → Payment Service
    ↓                              ↓
Return 201              (processing delay)
                                   ↓
                        Webhook Callback
                                   ↓
                        Backend updates DB
```

**Benefits:**
- Non-blocking operations
- Better user experience
- Scalability

---

### 3. Real-time Updates (WebSocket)

**Pattern:** Publish-Subscribe
**Use case:** Live monitoring, bi-directional communication

```
Admin Dashboard ←→ Socket.io ←→ Backend/Payment Services
                      ↓
               Broadcast events
```

**Events:**
- Service health changes
- Request logs
- Configuration updates

---

## Data Flow Examples

### Example 1: Customer Places Order

```
1. Customer fills checkout form
   └─> Frontend validates input

2. Frontend POST /api/orders
   └─> Backend receives request
       └─> Logs request via Socket.io
       └─> Saves order to MongoDB (status: pending)
       └─> Triggers async payment processing
       └─> Returns order ID to frontend

3. Backend → Payment Service (async)
   └─> POST /api/payment
       └─> Payment service logs request
       └─> Returns 202 Accepted
       └─> Processes in background

4. Payment Service (after delay)
   └─> Sends webhook to backend
       └─> POST /api/webhook/payment
           └─> Backend updates order status
           └─> Logs via Socket.io

5. Admin Dashboard
   └─> Sees all requests in real-time
   └─> Watches animated flow
   └─> Views updated order status
```

---

### Example 2: Admin Simulates Payment Error

```
1. Admin opens dashboard
   └─> Connects via Socket.io

2. Admin toggles "Simulate Payment Error"
   └─> Frontend emits 'update-admin-config'
       └─> Backend receives and broadcasts to all services
           └─> Payment service updates config

3. Customer places order
   └─> Normal flow until payment

4. Payment Service
   └─> Checks admin config
   └─> Sees simulatePaymentError = true
   └─> Sends 'rejected' status via webhook

5. Backend receives webhook
   └─> Updates order status to 'rejected'
   └─> Broadcasts via Socket.io

6. Admin Dashboard
   └─> Shows red flow indicators
   └─> Displays error in logs
   └─> Updates service status
```

---

## Kubernetes Architecture

### Deployment Structure

```
┌─────────────────────────────────────────────┐
│           Kubernetes Cluster                 │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │  Frontend Deployment               │    │
│  │  - Replicas: 1                     │    │
│  │  - Port: 80 (nginx)                │    │
│  │  - Service: LoadBalancer           │    │
│  └────────────────────────────────────┘    │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │  Backend Deployment                │    │
│  │  - Replicas: 1                     │    │
│  │  - Port: 3000                      │    │
│  │  - Service: ClusterIP              │    │
│  │  - Health checks enabled           │    │
│  └────────────────────────────────────┘    │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │  Payment Service Deployment        │    │
│  │  - Replicas: 1                     │    │
│  │  - Port: 3002                      │    │
│  │  - Service: ClusterIP              │    │
│  │  - Health checks enabled           │    │
│  └────────────────────────────────────┘    │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │  MongoDB StatefulSet               │    │
│  │  - Replicas: 1                     │    │
│  │  - Port: 27017                     │    │
│  │  - PVC: 1Gi                        │    │
│  │  - Service: ClusterIP              │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```

### Access Methods

#### 1. Port Forwarding
```
kubectl port-forward → Pod
                        ↓
               localhost:port
```

**Pros:**
- Simple setup
- No external dependencies
- Secure (local only)

**Cons:**
- Manual setup required
- One connection per port
- Not accessible externally

---

#### 2. Ngrok Tunnels
```
Kubernetes Pod → Port Forward → Ngrok Client → Ngrok Cloud → Public URL
```

**Pros:**
- Public HTTPS URLs
- Webhook testing
- Request inspection
- Share with others

**Cons:**
- Requires ngrok account
- URLs change (free tier)
- Additional latency

---

#### 3. Telepresence
```
Local Process ←→ Telepresence ←→ Kubernetes Cluster
```

**Pros:**
- Hybrid development
- Hot reload
- Full cluster access
- Debug locally with cluster context

**Cons:**
- Complex setup
- Additional tool required
- Potential conflicts

---

## Monitoring & Observability

### Admin Dashboard Features

**Service Status Monitoring:**
- Health indicators (✓/✗)
- Location (local/cloud)
- Connection method (port-forward/ngrok/telepresence)
- Color-coded visualization

**Request Flow Visualization:**
- Animated SVG diagram
- Real-time request tracking
- Color-coded by status (green=success, red=error)
- Request duration display

**Configuration Management:**
- Toggle payment errors
- Adjust processing delays
- Real-time config synchronization

**Log Viewer:**
- Chronological request logs
- Source/destination tracking
- HTTP method and path
- Status codes and duration

---

## Scalability Considerations

### Current Architecture (Demo)
- Single replica per service
- In-memory session storage
- Local MongoDB

### Production Recommendations

**Horizontal Scaling:**
```yaml
replicas: 3  # Scale frontend/backend/payment
```

**Database:**
- MongoDB replica set
- Separate StatefulSet
- External managed service (Atlas)

**Session Management:**
- Redis for session storage
- Sticky sessions via ingress

**Load Balancing:**
- Kubernetes Ingress
- Cloud load balancer
- Service mesh (Istio)

**Monitoring:**
- Prometheus metrics
- Grafana dashboards
- ELK stack for logs
- Jaeger for tracing

---

## Security Considerations

### Current Implementation (Demo)
- No authentication
- HTTP only
- Open admin dashboard

### Production Recommendations

**Authentication:**
- JWT tokens
- OAuth 2.0
- API keys

**Authorization:**
- Role-based access control (RBAC)
- Admin dashboard protection
- Service-to-service auth

**Network:**
- TLS/HTTPS everywhere
- Network policies
- Service mesh mTLS

**Secrets Management:**
- Kubernetes secrets
- External secret management (Vault)
- Environment-specific configs

**Data Protection:**
- Encrypt at rest
- PII handling
- GDPR compliance

---

## Technology Choices

### Why Angular?
- Component-based architecture
- Strong TypeScript support
- Built-in RxJS for reactive programming
- Excellent tooling

### Why Express?
- Lightweight and flexible
- Large ecosystem
- Easy to understand
- Great for microservices

### Why MongoDB?
- Document-based (matches JSON structure)
- Flexible schema
- Easy to set up
- Good for prototyping

### Why Socket.io?
- Real-time bi-directional communication
- Automatic reconnection
- Room/namespace support
- Fallback to polling

### Why Kubernetes?
- Industry standard
- Cloud-agnostic
- Declarative configuration
- Rich ecosystem

---

## Future Enhancements

**Features:**
- [ ] User authentication & profiles
- [ ] Order history
- [ ] Product reviews
- [ ] Inventory management
- [ ] Email notifications
- [ ] Payment gateway integration
- [ ] Multi-currency support

**Technical:**
- [ ] CI/CD pipeline
- [ ] E2E testing
- [ ] Performance monitoring
- [ ] Caching layer (Redis)
- [ ] Message queue (RabbitMQ/Kafka)
- [ ] API gateway
- [ ] Rate limiting
- [ ] GraphQL API

**DevOps:**
- [ ] Helm charts
- [ ] GitOps (ArgoCD)
- [ ] Auto-scaling (HPA)
- [ ] Disaster recovery
- [ ] Multi-region deployment

---

## Conclusion

This architecture demonstrates modern microservices patterns while remaining simple enough for learning and experimentation. The focus is on practical implementations of:

- Service decomposition
- Async communication
- Real-time monitoring
- Cloud-native deployment
- Multiple access methods

Perfect for understanding microservices concepts before tackling production systems!
