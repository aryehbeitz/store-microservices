import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  AdminConfig,
  RequestLog,
  ServiceStatus,
} from '@honey-store/shared/types';
import { io, Socket } from 'socket.io-client';

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

  ngOnInit() {
    this.detectFrontendLocation();
    this.connectToServices();
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
    // Disconnect all sockets
    Object.values(this.services).forEach((service) => {
      if (service.socket) {
        service.socket.disconnect();
      }
    });
  }

  connectToServices() {
    // Connect to backend
    // Connect to backend Socket.IO (nginx proxies /socket.io to backend)
    const backendSocket = io('/', {
      path: '/socket.io',
      transports: ['websocket', 'polling'],
    });

    this.services['backend'].socket = backendSocket;

    backendSocket.on('connect', () => {
      console.log('Connected to backend socket');
      this.services['backend'].enabled = true;
    });

    backendSocket.on('service-status', (status: ServiceStatus) => {
      const previousMethod = this.services['backend'].connectionMethod;
      const newMethod = status.connectionMethod;

      // Detect connection method change
      if (previousMethod !== newMethod && previousMethod !== 'none') {
        this.handleConnectionMethodChange('backend', previousMethod, newMethod);
      }

      this.services['backend'] = {
        ...status,
        socket: backendSocket,
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
      console.log('Disconnected from backend socket');
      this.services['backend'].enabled = false;
      this.services['backend'].healthy = false;
    });

    // Payment service is now external - always on K8s
    // The payment dashboard is available at http://REDACTED_IP/
    this.services['payment-service'].enabled = true;
    this.services['payment-service'].healthy = true;
    this.services['payment-service'].location = 'cloud'; // Always on K8s
    this.services['payment-service'].connectionMethod = 'direct';
    console.log('Payment service is external - using payment dashboard at http://REDACTED_IP/');
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
