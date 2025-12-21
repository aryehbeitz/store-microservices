import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  AdminConfig,
  RequestLog,
  ServiceStatus,
} from '@honey-store/shared/types';
import { io, Socket } from 'socket.io-client';
import { environment } from '../../../environments/environment';

interface ServiceInfo extends ServiceStatus {
  socket?: Socket;
  previousConnectionMethod?: string;
  connectionMethodChanged?: boolean;
  changeTimestamp?: Date;
}

interface ConnectionChangeNotification {
  serviceName: string;
  from: string;
  to: string;
  timestamp: Date;
  id: string;
}

@Component({
  selector: 'app-admin-dashboard',
  templateUrl: './admin-dashboard.component.html',
  styleUrls: ['./admin-dashboard.component.css'],
})
export class AdminDashboardComponent implements OnInit, OnDestroy {
  frontendLocation: 'local' | 'cloud' = 'cloud'; // Default to cloud (K8s), will detect if local
  services: { [key: string]: ServiceInfo } = {
    backend: {
      name: 'backend',
      healthy: false,
      location: 'local',
      connectionMethod: 'none',
      enabled: false,
      previousConnectionMethod: 'none',
      connectionMethodChanged: false,
    },
    'payment-service': {
      name: 'payment-service',
      healthy: false,
      location: 'cloud', // Payment is always on K8s
      connectionMethod: 'direct',
      enabled: true,
      previousConnectionMethod: 'direct',
      connectionMethodChanged: false,
    },
  };

  requestLogs: RequestLog[] = [];
  adminConfig: AdminConfig = {
    simulatePaymentError: false,
    paymentDelayMs: 2000,
  };

  activeRequests: Map<string, RequestLog> = new Map();
  connectionChangeNotifications: ConnectionChangeNotification[] = [];
  private reconnectTimer?: any;
  private checkInterval?: any;
  private currentBackendUrl: string = '/';

  ngOnInit() {
    this.detectFrontendLocation();
    this.connectToServices();
    // Periodically check if local services are available
    this.startServiceCheck();
  }

  detectFrontendLocation() {
    // Detect if frontend is running locally (localhost:4200) or on K8s
    const hostname = window.location.hostname;
    if (hostname === 'localhost' || hostname === '127.0.0.1') {
      this.frontendLocation = 'local';
    } else {
      this.frontendLocation = 'cloud';
    }
  }

  ngOnDestroy() {
    // Clear intervals
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
    }
    // Disconnect all sockets
    Object.values(this.services).forEach((service) => {
      if (service.socket) {
        service.socket.disconnect();
      }
    });
  }

  connectToServices() {
    // Try to connect to backend
    // If frontend is local, try local backend first, then fall back to K8s
    // If frontend is in K8s, always use K8s backend
    if (this.frontendLocation === 'local') {
      // Try local backend first
      this.tryConnectBackend(environment.backendUrl, true);
    } else {
      // Frontend is in K8s, use K8s backend
      this.tryConnectBackend('/', false);
    }

    // Payment service is now external - always on K8s
    // The payment dashboard is available at http://REDACTED_IP/
    this.services['payment-service'].enabled = true;
    this.services['payment-service'].healthy = true;
    this.services['payment-service'].location = 'cloud'; // Always on K8s
    this.services['payment-service'].connectionMethod = 'direct';
    console.log('Payment service is external - using payment dashboard at http://REDACTED_IP/');
  }

  tryConnectBackend(socketUrl: string, isLocal: boolean) {
    // Disconnect existing socket if any
    if (this.services['backend'].socket) {
      this.services['backend'].socket.disconnect();
    }

    this.currentBackendUrl = socketUrl;
    const backendSocket = io(socketUrl, {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
      timeout: 5000, // 5 second timeout
      reconnection: false, // We'll handle reconnection manually
    });

    this.services['backend'].socket = backendSocket;
    this.services['backend'].location = isLocal ? 'local' : 'cloud';

    // Set connection timeout
    const connectionTimeout = setTimeout(() => {
      if (!backendSocket.connected) {
        console.log(`Failed to connect to ${isLocal ? 'local' : 'K8s'} backend, trying fallback...`);
        backendSocket.disconnect();
        
        // If we tried local and it failed, try K8s
        if (isLocal && this.frontendLocation === 'local') {
          this.tryConnectBackend('/', false);
        }
      }
    }, 5000);

    backendSocket.on('connect', () => {
      clearTimeout(connectionTimeout);
      console.log(`Connected to ${isLocal ? 'local' : 'K8s'} backend socket`);
      this.services['backend'].enabled = true;
      this.services['backend'].location = isLocal ? 'local' : 'cloud';
    });

    backendSocket.on('service-status', (status: ServiceStatus) => {
      const previousMethod = this.services['backend'].connectionMethod;
      const newMethod = status.connectionMethod;
      const previousLocation = this.services['backend'].location;

      // Detect connection method change
      if (previousMethod !== newMethod && previousMethod !== 'none') {
        this.handleConnectionMethodChange('backend', previousMethod, newMethod);
      }

      // Detect location change
      if (previousLocation !== status.location && previousLocation !== 'local') {
        console.log(`Backend location changed: ${previousLocation} -> ${status.location}`);
      }

      this.services['backend'] = {
        ...status,
        socket: backendSocket,
        location: isLocal ? 'local' : status.location,
        previousConnectionMethod: previousMethod,
        connectionMethodChanged: previousMethod !== newMethod && previousMethod !== 'none',
        changeTimestamp: previousMethod !== newMethod ? new Date() : this.services['backend'].changeTimestamp,
      };

      // Reset change flag after animation duration
      if (this.services['backend'].connectionMethodChanged) {
        setTimeout(() => {
          this.services['backend'].connectionMethodChanged = false;
        }, 3000);
      }
    });

    backendSocket.on('request-log', (log: RequestLog) => {
      this.addRequestLog(log);
    });

    backendSocket.on('admin-config', (config: AdminConfig) => {
      this.adminConfig = config;
    });

    backendSocket.on('disconnect', () => {
      console.log(`Disconnected from ${isLocal ? 'local' : 'K8s'} backend socket`);
      this.services['backend'].enabled = false;
      this.services['backend'].healthy = false;
      
      // If local backend disconnected and we're running locally, try K8s fallback
      if (isLocal && this.frontendLocation === 'local') {
        this.reconnectTimer = setTimeout(() => {
          if (!this.services['backend'].socket?.connected) {
            console.log('Local backend disconnected, trying K8s backend...');
            this.tryConnectBackend('/', false);
          }
        }, 2000);
      }
    });

    backendSocket.on('connect_error', (error) => {
      console.log(`Connection error to ${isLocal ? 'local' : 'K8s'} backend:`, error);
      clearTimeout(connectionTimeout);
      
      // If local backend failed and we're running locally, try K8s
      if (isLocal && this.frontendLocation === 'local') {
        this.reconnectTimer = setTimeout(() => {
          console.log('Local backend unavailable, trying K8s backend...');
          this.tryConnectBackend('/', false);
        }, 2000);
      }
    });
  }

  startServiceCheck() {
    // Check every 5 seconds if local services are available
    this.checkInterval = setInterval(() => {
      if (this.frontendLocation === 'local') {
        // Check if local backend is now available
        if (!this.services['backend'].socket?.connected) {
          // Try local backend again with timeout
          const controller = new AbortController();
          const timeoutId = setTimeout(() => controller.abort(), 2000);
          
          fetch(`${environment.backendUrl}/health`, { 
            method: 'GET',
            signal: controller.signal
          })
            .then(() => {
              clearTimeout(timeoutId);
              // Local backend is available, reconnect
              if (this.currentBackendUrl !== environment.backendUrl) {
                console.log('Local backend is now available, reconnecting...');
                this.tryConnectBackend(environment.backendUrl, true);
              }
            })
            .catch(() => {
              clearTimeout(timeoutId);
              // Local backend not available, ensure we're using K8s
              if (this.currentBackendUrl === environment.backendUrl && !this.services['backend'].socket?.connected) {
                console.log('Local backend unavailable, using K8s backend...');
                this.tryConnectBackend('/', false);
              }
            });
        }
      }
    }, 5000);
  }

  addRequestLog(log: RequestLog) {
    // Add to active requests for visualization
    this.activeRequests.set(log.id, log);

    // Remove after animation
    setTimeout(() => {
      this.activeRequests.delete(log.id);
    }, 2000);

    // Add to logs list
    this.requestLogs.unshift(log);
    if (this.requestLogs.length > 50) {
      this.requestLogs.pop();
    }
  }

  togglePaymentError() {
    this.adminConfig.simulatePaymentError = !this.adminConfig.simulatePaymentError;
    this.broadcastConfig();
  }

  updatePaymentDelay(event: any) {
    this.adminConfig.paymentDelayMs = parseInt(event.target.value, 10);
    this.broadcastConfig();
  }

  broadcastConfig() {
    // Send config to all services
    Object.values(this.services).forEach((service) => {
      if (service.socket && service.socket.connected) {
        service.socket.emit('update-admin-config', this.adminConfig);
      }
    });
  }

  getServiceColor(service: ServiceInfo): string {
    if (!service.enabled) return '#999';
    if (!service.healthy) return '#f44336';

    switch (service.connectionMethod) {
      case 'port-forward':
        return '#2196f3';
      case 'ngrok':
        return '#9c27b0';
      case 'telepresence':
        return '#ff9800';
      case 'direct':
        return '#4caf50';
      default:
        return '#999';
    }
  }

  getConnectionMethodLabel(method: string): string {
    if (method === 'none') {
      return 'Waiting for Status';
    }
    return method
      .split('-')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  getServiceStatusLabel(service: ServiceInfo): string {
    if (!service.enabled) {
      return 'Socket Not Connected';
    }
    if (!service.healthy) {
      return 'Unhealthy';
    }
    return 'Healthy';
  }

  getRequestFlowPath(log: RequestLog): string {
    const from = log.source;
    const to = log.destination;

    // Define positions for each service/component
    const positions: { [key: string]: { x: number; y: number } } = {
      frontend: { x: 100, y: 250 },
      backend: { x: 400, y: 250 },
      'payment-service': { x: 700, y: 250 },
      external: { x: 250, y: 100 },
    };

    const fromPos = positions[from] || positions['external'];
    const toPos = positions[to] || positions['backend'];

    return `M ${fromPos.x} ${fromPos.y} L ${toPos.x} ${toPos.y}`;
  }

  handleConnectionMethodChange(serviceName: string, from: string, to: string) {
    const notification: ConnectionChangeNotification = {
      serviceName,
      from,
      to,
      timestamp: new Date(),
      id: Math.random().toString(36).substring(2, 11),
    };

    this.connectionChangeNotifications.unshift(notification);

    // Keep only last 10 notifications
    if (this.connectionChangeNotifications.length > 10) {
      this.connectionChangeNotifications.pop();
    }

    // Auto-remove notification after 5 seconds
    setTimeout(() => {
      const index = this.connectionChangeNotifications.findIndex(n => n.id === notification.id);
      if (index !== -1) {
        this.connectionChangeNotifications.splice(index, 1);
      }
    }, 5000);
  }

  getConnectionMethodIcon(method: string): string {
    switch (method) {
      case 'port-forward':
        return '🔵';
      case 'ngrok':
        return '🟣';
      case 'telepresence':
        return '🟠';
      case 'direct':
        return '🟢';
      default:
        return '⚪';
    }
  }

  dismissNotification(id: string) {
    const index = this.connectionChangeNotifications.findIndex(n => n.id === id);
    if (index !== -1) {
      this.connectionChangeNotifications.splice(index, 1);
    }
  }

  getLocationLabel(location: 'local' | 'cloud'): string {
    return location === 'local' ? 'Local' : 'K8s';
  }

  getLocationDescription(location: 'local' | 'cloud', serviceName: string): string {
    if (location === 'local') {
      return 'Running on your machine - code changes are instant';
    } else {
      return 'Running in Kubernetes - updates via Socket.IO';
    }
  }
}
