// Product Types
export interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  category: 'honey' | 'equipment' | 'accessories';
  imageUrl: string;
  inStock: boolean;
}

// Cart Types
export interface CartItem {
  product: Product;
  quantity: number;
}

export interface Cart {
  items: CartItem[];
  total: number;
}

// Order Types
export interface Order {
  _id: string;
  items: CartItem[];
  total: number;
  customerName: string;
  customerEmail: string;
  shippingAddress: string;
  paymentStatus: 'pending' | 'approved' | 'rejected' | 'error';
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateOrderRequest {
  items: CartItem[];
  total: number;
  customerName: string;
  customerEmail: string;
  shippingAddress: string;
}

export interface CreateOrderResponse {
  orderId: string;
  message: string;
}

// Payment Types
export interface PaymentRequest {
  webhook_url: string;
  sleep?: number;
  data?: {
    orderId: string;
    amount: number;
    currency: string;
    customerEmail: string;
  };
  // Legacy fields (kept for backwards compatibility)
  orderId?: string;
  amount?: number;
  customerEmail?: string;
}

export interface PaymentResponse {
  paymentId: string;
  status: 'processing' | 'approved' | 'rejected' | 'error';
  message: string;
}

export interface PaymentWebhook {
  orderId: string;
  paymentId: string;
  status: 'approved' | 'rejected' | 'error';
  message: string;
}

// Admin Monitoring Types
export interface ServiceStatus {
  name: string;
  healthy: boolean;
  location: 'local' | 'cloud';
  connectionMethod: 'port-forward' | 'ngrok' | 'telepresence' | 'direct' | 'none';
  enabled: boolean;
  url?: string;
}

export interface RequestLog {
  id: string;
  timestamp: Date;
  source: string;
  destination: string;
  method: string;
  path: string;
  status?: number;
  duration?: number;
}

export interface AdminConfig {
  simulatePaymentError: boolean;
  paymentDelayMs: number;
}
