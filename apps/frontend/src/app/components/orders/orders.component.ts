import { Component, OnDestroy, OnInit } from '@angular/core';
import { Order } from '@honey-store/shared/types';
import { io, Socket } from 'socket.io-client';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-orders',
  templateUrl: './orders.component.html',
  styleUrls: ['./orders.component.css']
})
export class OrdersComponent implements OnInit, OnDestroy {
  orders: Order[] = [];
  loading = false;
  error: string | null = null;
  retryingPayment: { [orderId: string]: boolean } = {};
  connectionInfo: any = null;
  realTimeUpdates = false;
  private socket: Socket | null = null;

  constructor(private apiService: ApiService) {}

  ngOnInit(): void {
    this.loadOrders();
  }

  ngOnDestroy(): void {
    if (this.socket) {
      this.socket.disconnect();
    }
  }

  loadOrders(): void {
    this.loading = true;
    this.error = null;

    this.apiService.getAllOrders().subscribe({
      next: (response) => {
        this.orders = response.orders;
        this.connectionInfo = response.connectionInfo;
        this.realTimeUpdates = response.connectionInfo.canReceiveWebhooks;
        this.loading = false;

        // Set up real-time updates if webhooks are enabled
        this.setupRealTimeUpdates();
        if (this.realTimeUpdates) {
        }
      },
      error: (error) => {
        this.error = 'Failed to load orders. Please try again.';
        this.loading = false;
        console.error('Error loading orders:', error);
      }
    });
  }

  retryPayment(orderId: string): void {
    this.retryingPayment[orderId] = true;

    this.apiService.retryPayment(orderId).subscribe({
      next: (response) => {
        this.retryingPayment[orderId] = false;
        // Reload orders to get updated status
        this.loadOrders();
        console.log('Payment retry initiated:', response);
      },
      error: (error) => {
        this.retryingPayment[orderId] = false;
        this.error = 'Failed to retry payment. Please try again.';
        console.error('Error retrying payment:', error);
      }
    });
  }

  clearAllOrders(): void {
    if (confirm('Are you sure you want to clear all orders? This action cannot be undone.')) {
      this.loading = true;
      this.apiService.clearAllOrders().subscribe({
        next: (response) => {
          console.log('Clear all orders response:', response);
          this.orders = [];
          this.loading = false;
        },
        error: (error) => {
          console.error('Error clearing orders:', error);
          this.loading = false;
          this.error = 'Failed to clear orders. Please try again.';
        }
      });
    }
  }

  getStatusClass(status: string): string {
    switch (status) {
      case 'approved':
        return 'status-approved';
      case 'pending':
        return 'status-pending';
      case 'rejected':
        return 'status-rejected';
      case 'error':
        return 'status-error';
      default:
        return 'status-unknown';
    }
  }

  getStatusText(status: string): string {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  canRetryPayment(status: string): boolean {
    return status === 'error' || status === 'rejected';
  }

  formatDate(date: Date | string): string {
    return new Date(date).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

  getConnectionMethodDisplay(): string {
    if (!this.connectionInfo) return 'Unknown';
    return this.connectionInfo.method.replace('-', ' ').toUpperCase();
  }

  getConnectionMethodClass(): string {
    if (!this.connectionInfo) return 'connection-unknown';
    return `connection-${this.connectionInfo.method}`;
  }

  getWebhookStatusText(): string {
    if (!this.connectionInfo) return 'Unknown';
    return this.connectionInfo.canReceiveWebhooks ? 'Webhooks Enabled' : 'Webhooks Disabled';
  }

  getWebhookStatusClass(): string {
    if (!this.connectionInfo) return 'webhook-unknown';
    return this.connectionInfo.canReceiveWebhooks ? 'webhook-enabled' : 'webhook-disabled';
  }

  private setupRealTimeUpdates(): void {
    if (this.socket) {
      this.socket.disconnect();
    }

    // Connect to backend Socket.IO
    this.socket = io('http://localhost:3000');

    this.socket.on('connect', () => {
      console.log('Connected to real-time updates');
    });

    this.socket.on('disconnect', () => {
      console.log('Disconnected from real-time updates');
    });

    // Listen for order updates
    this.socket.on('order-updated', (updatedOrder: Order) => {
      console.log('Order updated:', updatedOrder);
      this.updateOrderInList(updatedOrder);
    });

    this.socket.on('payment-webhook', (webhookData: any) => {
      console.log('Payment webhook received:', webhookData);
      // Reload orders to get the latest status
      this.loadOrders();
    });
  }

  private updateOrderInList(updatedOrder: Order): void {
    const index = this.orders.findIndex(order => order._id === updatedOrder._id);
    if (index !== -1) {
      this.orders[index] = updatedOrder;
    }
  }
}
