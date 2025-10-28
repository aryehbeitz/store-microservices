import express from 'express';
import cors from 'cors';
import axios from 'axios';
import { Server } from 'socket.io';
import { createServer } from 'http';
import {
  PaymentRequest,
  PaymentResponse,
  PaymentWebhook,
  ServiceStatus,
  RequestLog,
  AdminConfig,
} from '@honey-store/shared/types';

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
const PORT = process.env.PORT || 3002;
const BACKEND_URL = process.env.BACKEND_URL || 'http://backend:3000';
const SERVICE_LOCATION = process.env.SERVICE_LOCATION || 'local';
const CONNECTION_METHOD = process.env.CONNECTION_METHOD || 'direct';

// Admin configuration (received from admin dashboard)
let adminConfig: AdminConfig = {
  simulatePaymentError: false,
  paymentDelayMs: 2000,
};

// Service status tracking
let serviceStatus: ServiceStatus = {
  name: 'payment-service',
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

// Socket.io connection
io.on('connection', (socket) => {
  console.log('Admin client connected to payment service');

  // Send current status
  socket.emit('service-status', serviceStatus);
  socket.emit('admin-config', adminConfig);
  socket.emit('request-logs', requestLogs);

  // Handle admin config updates
  socket.on('update-admin-config', (config: AdminConfig) => {
    adminConfig = { ...adminConfig, ...config };
    io.emit('admin-config', adminConfig);
    console.log('Admin config updated:', adminConfig);
  });

  socket.on('disconnect', () => {
    console.log('Admin client disconnected from payment service');
  });
});

// Health check
app.get('/health', (req, res) => {
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'external',
    destination: 'payment-service',
    method: 'GET',
    path: '/health',
    status: 200,
  };
  logRequest(log);

  res.json({
    status: 'healthy',
    service: 'payment-service',
    location: SERVICE_LOCATION,
    connectionMethod: CONNECTION_METHOD,
  });
});

// Process payment
app.post('/api/payment', async (req, res) => {
  const startTime = Date.now();
  const log: RequestLog = {
    id: Math.random().toString(36),
    timestamp: new Date(),
    source: 'backend',
    destination: 'payment-service',
    method: 'POST',
    path: '/api/payment',
  };

  try {
    const paymentRequest: PaymentRequest = req.body;

    // Simulate payment processing delay
    const delay = adminConfig.paymentDelayMs || 2000;

    const duration = Date.now() - startTime;
    log.status = 202;
    log.duration = duration;
    logRequest(log);

    const response: PaymentResponse = {
      paymentId: Math.random().toString(36).substring(2, 15),
      status: 'processing',
      message: 'Payment is being processed',
    };

    res.status(202).json(response);

    // Process payment asynchronously
    processPaymentAsync(paymentRequest, delay);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    res.status(500).json({ error: 'Failed to process payment' });
  }
});

async function processPaymentAsync(paymentRequest: PaymentRequest, delay: number) {
  // Wait for the configured delay
  await new Promise((resolve) => setTimeout(resolve, delay));

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
    // Determine payment status based on admin config
    const status = adminConfig.simulatePaymentError ? 'rejected' : 'approved';
    const message = adminConfig.simulatePaymentError
      ? 'Payment rejected due to simulated error'
      : 'Payment approved successfully';

    const webhook: PaymentWebhook = {
      orderId: paymentRequest.orderId,
      paymentId: Math.random().toString(36).substring(2, 15),
      status: status as 'approved' | 'rejected',
      message,
    };

    console.log(`Sending webhook to ${BACKEND_URL}/api/webhook/payment`);
    console.log('Webhook payload:', webhook);

    const response = await axios.post(`${BACKEND_URL}/api/webhook/payment`, webhook, {
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const duration = Date.now() - startTime;
    log.status = response.status;
    log.duration = duration;
    logRequest(log);

    console.log('Webhook sent successfully:', response.data);
  } catch (error) {
    const duration = Date.now() - startTime;
    log.status = 500;
    log.duration = duration;
    logRequest(log);

    console.error('Failed to send webhook:', error);

    // Retry logic could be added here
  }
}

// Start server
httpServer.listen(PORT, () => {
  console.log(`Payment service listening on port ${PORT}`);
  console.log(`Backend URL: ${BACKEND_URL}`);
  console.log(`Service Location: ${SERVICE_LOCATION}`);
  console.log(`Connection Method: ${CONNECTION_METHOD}`);
});
