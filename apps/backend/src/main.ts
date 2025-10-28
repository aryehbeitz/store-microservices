import {
    AdminConfig,
    CreateOrderRequest,
    CreateOrderResponse,
    PaymentRequest,
    PaymentWebhook,
    RequestLog,
    ServiceStatus
} from '@honey-store/shared/types';
import axios from 'axios';
import cors from 'cors';
import express from 'express';
import { createServer } from 'http';
import mongoose from 'mongoose';
import { Server } from 'socket.io';

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(cors());
app.use(express.json());

// Environment variables
const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://mongodb:27017/honey-store';
const PAYMENT_SERVICE_URL = process.env.PAYMENT_SERVICE_URL || 'http://payment-service:3002';
const SERVICE_LOCATION = process.env.SERVICE_LOCATION || 'local';
const CONNECTION_METHOD = process.env.CONNECTION_METHOD || 'direct';

// Admin configuration
let adminConfig: AdminConfig = {
  simulatePaymentError: false,
  paymentDelayMs: 2000,
};

// Service status tracking
let serviceStatus: ServiceStatus = {
  name: 'backend',
  healthy: true,
  location: SERVICE_LOCATION as 'local' | 'cloud',
  connectionMethod: CONNECTION_METHOD as any,
  enabled: true,
};

// Request logging
const requestLogs: RequestLog[] = [];

function logRequest(log: RequestLog) {
  requestLogs.push(log);
  if (requestLogs.length > 100) {
    requestLogs.shift();
  }
  io.emit('request-log', log);
}

// MongoDB Schema
const orderSchema = new mongoose.Schema({
  items: [{
    product: {
      id: String,
      name: String,
      description: String,
      price: Number,
      category: String,
      imageUrl: String,
      inStock: Boolean,
    },
    quantity: Number,
  }],
  total: Number,
  customerName: String,
  customerEmail: String,
  shippingAddress: String,
  paymentStatus: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'error'],
    default: 'pending',
  },
}, { timestamps: true });

const OrderModel = mongoose.model('Order', orderSchema);

// Connect to MongoDB
mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('Connected to MongoDB');
    serviceStatus.healthy = true;
    io.emit('service-status', serviceStatus);
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err);
    serviceStatus.healthy = false;
    io.emit('service-status', serviceStatus);
  });

// Socket.io connection
io.on('connection', (socket) => {
  console.log('Admin client connected');

  // Send current status
  socket.emit('service-status', serviceStatus);
  socket.emit('admin-config', adminConfig);
  socket.emit('request-logs', requestLogs);

  // Handle admin config updates
  socket.on('update-admin-config', (config: AdminConfig) => {
    adminConfig = { ...adminConfig, ...config };
    io.emit('admin-config', adminConfig);
  });

  socket.on('disconnect', () => {
    console.log('Admin client disconnected');
  });
});

// Health check
app.get('/health', (req, res) => {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'external',
    destination: 'backend',
    method: 'GET',
    path: '/health',
    status: 200,
  };
  logRequest(log);

  res.json({
    status: 'healthy',
    service: 'backend',
    mongodb: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected',
    location: SERVICE_LOCATION,
    connectionMethod: CONNECTION_METHOD,
  });
});

// Get connection method info
app.get('/api/connection-info', (req, res) => {
  res.json({
    connectionMethod: CONNECTION_METHOD,
    serviceLocation: SERVICE_LOCATION,
    canReceiveWebhooks: CONNECTION_METHOD !== 'port-forward',
    webhookUrl: CONNECTION_METHOD === 'port-forward' ? 'Not available' : `${req.protocol}://${req.get('host')}/api/webhook/payment`
  });
});

// Get all orders
app.get('/api/orders', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'frontend',
    destination: 'backend',
    method: 'GET',
    path: '/api/orders',
  };

  try {
    const orders = await OrderModel.find().sort({ createdAt: -1 });
    const duration = Date.now() - startTime;

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    // Add connection method info to response
    res.json({
      orders,
      connectionInfo: {
        method: CONNECTION_METHOD,
        location: SERVICE_LOCATION,
        canReceiveWebhooks: CONNECTION_METHOD !== 'port-forward'
      }
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Get order by ID
app.get('/api/orders/:id', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'frontend',
    destination: 'backend',
    method: 'GET',
    path: `/api/orders/${req.params.id}`,
  };

  try {
    const order = await OrderModel.findById(req.params.id);
    const duration = Date.now() - startTime;

    if (!order) {
      log.status = 404;
      log.duration = duration;
      logRequest(log);
      return res.status(404).json({ error: 'Order not found' });
    }

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json(order);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// Create order
app.post('/api/orders', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'frontend',
    destination: 'backend',
    method: 'POST',
    path: '/api/orders',
  };

  try {
    const orderData: CreateOrderRequest = req.body;

    // Create order in database
    const order = new OrderModel({
      items: orderData.items,
      total: orderData.total,
      customerName: orderData.customerName,
      customerEmail: orderData.customerEmail,
      shippingAddress: orderData.shippingAddress,
      paymentStatus: 'pending',
    });

    await order.save();

    const duration = Date.now() - startTime;
    log.status = 201;
    log.duration = duration;
    logRequest(log);

    // Send payment request to payment service (async)
    processPayment(order._id.toString(), orderData.total, orderData.customerEmail);

    const response: CreateOrderResponse = {
      orderId: order._id.toString(),
      message: 'Order created successfully. Payment is being processed.',
    };

    res.status(201).json(response);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to create order' });
  }
});

// Process payment (async function)
async function processPayment(orderId: string, amount: number, customerEmail: string) {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'backend',
    destination: 'payment-service',
    method: 'POST',
    path: '/api/payment',
  };

  const startTime = Date.now();

  try {
    const paymentRequest: PaymentRequest = {
      orderId,
      amount,
      customerEmail,
    };

    const response = await axios.post(`${PAYMENT_SERVICE_URL}/api/payment`, paymentRequest, {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const duration = Date.now() - startTime;
    log.status = response.status;
    log.duration = duration;
    logRequest(log);

    console.log('Payment request sent:', response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error('Failed to send payment request:', error);

    // Update order status to error
    await OrderModel.findByIdAndUpdate(orderId, { paymentStatus: 'error' });
  }
}

// Payment webhook
app.post('/api/webhook/payment', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'payment-service',
    destination: 'backend',
    method: 'POST',
    path: '/api/webhook/payment',
  };

  try {
    const webhook: PaymentWebhook = req.body;

    // Update order payment status and get the updated order
    const updatedOrder = await OrderModel.findByIdAndUpdate(
      webhook.orderId,
      { paymentStatus: webhook.status },
      { new: true }
    );

    const duration = Date.now() - startTime;
    log.status = 200;
    log.duration = duration;
    logRequest(log);

    console.log('Payment webhook received:', webhook);

    // Emit real-time updates to connected clients
    if (updatedOrder) {
      io.emit('order-updated', updatedOrder);
      io.emit('payment-webhook', webhook);
    }

    res.json({ message: 'Webhook processed successfully' });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to process webhook' });
  }
});

// Retry payment for an order
app.post('/api/orders/:id/retry-payment', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'frontend',
    destination: 'backend',
    method: 'POST',
    path: `/api/orders/${req.params.id}/retry-payment`,
  };

  try {
    const order = await OrderModel.findById(req.params.id);
    const duration = Date.now() - startTime;

    if (!order) {
      log.status = 404;
      log.duration = duration;
      logRequest(log);
      return res.status(404).json({ error: 'Order not found' });
    }

    // Only allow retry for orders with error or rejected payment status
    if (order.paymentStatus !== 'error' && order.paymentStatus !== 'rejected') {
      log.status = 400;
      log.duration = duration;
      logRequest(log);
      return res.status(400).json({
        error: 'Order payment cannot be retried. Current status: ' + order.paymentStatus
      });
    }

    // Reset payment status to pending
    order.paymentStatus = 'pending';
    await order.save();

    // Retry payment processing
    processPayment(order._id.toString(), order.total, order.customerEmail);

    log.status = 200;
    log.duration = duration;
    logRequest(log);

    res.json({
      message: 'Payment retry initiated successfully',
      orderId: order._id.toString(),
      status: 'pending'
    });
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to retry payment' });
  }
});

// Start server
httpServer.listen(PORT, () => {
  console.log(`Backend service listening on port ${PORT}`);
  console.log(`MongoDB URI: ${MONGODB_URI}`);
  console.log(`Payment Service URL: ${PAYMENT_SERVICE_URL}`);
  console.log(`Service Location: ${SERVICE_LOCATION}`);
  console.log(`Connection Method: ${CONNECTION_METHOD}`);
});
