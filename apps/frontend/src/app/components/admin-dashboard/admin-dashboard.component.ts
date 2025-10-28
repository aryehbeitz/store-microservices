import { Component, OnInit, OnDestroy } from '@angular/core';
import { io, Socket } from 'socket.io-client';
import {
  ServiceStatus,
  RequestLog,
  AdminConfig,
} from '@honey-store/shared/types';
import { environment } from '../../../environments/environment';

interface ServiceInfo extends ServiceStatus {
  socket?: Socket;
}

@Component({
  selector: 'app-admin-dashboard',
  templateUrl: './admin-dashboard.component.html',
  styleUrls: ['./admin-dashboard.component.css'],
})
export class AdminDashboardComponent implements OnInit, OnDestroy {
  services: { [key: string]: ServiceInfo } = {
    backend: {
      name: 'backend',
      healthy: false,
      location: 'local',
      connectionMethod: 'none',
      enabled: false,
    },
    'payment-service': {
      name: 'payment-service',
      healthy: false,
      location: 'local',
      connectionMethod: 'none',
      enabled: false,
    },
  };

  requestLogs: RequestLog[] = [];
  adminConfig: AdminConfig = {
    simulatePaymentError: false,
    paymentDelayMs: 2000,
  };

  activeRequests: Map<string, RequestLog> = new Map();

  ngOnInit() {
    this.connectToServices();
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
    const backendSocket = io(`${environment.backendUrl}`, {
      transports: ['websocket', 'polling'],
    });

    this.services['backend'].socket = backendSocket;

    backendSocket.on('connect', () => {
      console.log('Connected to backend socket');
      this.services['backend'].enabled = true;
    });

    backendSocket.on('service-status', (status: ServiceStatus) => {
      this.services['backend'] = {
        ...status,
        socket: backendSocket,
      };
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

    // Connect to payment service
    const paymentSocket = io('http://localhost:3002', {
      transports: ['websocket', 'polling'],
    });

    this.services['payment-service'].socket = paymentSocket;

    paymentSocket.on('connect', () => {
      console.log('Connected to payment service socket');
      this.services['payment-service'].enabled = true;
    });

    paymentSocket.on('service-status', (status: ServiceStatus) => {
      this.services['payment-service'] = {
        ...status,
        socket: paymentSocket,
      };
    });

    paymentSocket.on('request-log', (log: RequestLog) => {
      this.addRequestLog(log);
    });

    paymentSocket.on('disconnect', () => {
      console.log('Disconnected from payment service socket');
      this.services['payment-service'].enabled = false;
      this.services['payment-service'].healthy = false;
    });
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
    return method
      .split('-')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
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
}
