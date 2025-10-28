import { Component, OnDestroy, OnInit } from '@angular/core';
import { io, Socket } from 'socket.io-client';

@Component({
  selector: 'app-version-notification',
  template: `
    <div *ngIf="showNotification" class="version-notification" (click)="reloadPage()">
      <div class="notification-content">
        <span class="notification-icon">🔄</span>
        <div class="notification-text">
          <strong>{{ serviceName }} Updated!</strong>
          <small>Version {{ newVersion }} is available</small>
        </div>
        <button class="reload-btn">Reload</button>
      </div>
    </div>
  `,
  styles: [`
    .version-notification {
      position: fixed;
      top: 20px;
      right: 20px;
      background: #4CAF50;
      color: white;
      padding: 16px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      cursor: pointer;
      z-index: 1000;
      max-width: 300px;
      animation: slideIn 0.3s ease-out;
    }

    .notification-content {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .notification-icon {
      font-size: 20px;
    }

    .notification-text {
      flex: 1;
    }

    .notification-text strong {
      display: block;
      margin-bottom: 4px;
    }

    .notification-text small {
      opacity: 0.9;
    }

    .reload-btn {
      background: rgba(255,255,255,0.2);
      border: 1px solid rgba(255,255,255,0.3);
      color: white;
      padding: 6px 12px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 500;
    }

    .reload-btn:hover {
      background: rgba(255,255,255,0.3);
    }

    @keyframes slideIn {
      from {
        transform: translateX(100%);
        opacity: 0;
      }
      to {
        transform: translateX(0);
        opacity: 1;
      }
    }
  `]
})
export class VersionNotificationComponent implements OnInit, OnDestroy {
  showNotification = false;
  serviceName = '';
  newVersion = '';
  private socket: Socket;

  constructor() {
    this.socket = io('http://localhost:3000');
  }

  ngOnInit(): void {
    this.socket.on('version-update', (data: { service: string; version: string }) => {
      console.log('Version update received:', data);

      // Only show notification for frontend updates
      if (data.service === 'frontend') {
        this.serviceName = this.getServiceDisplayName(data.service);
        this.newVersion = data.version;
        this.showNotification = true;

        // Auto-hide after 10 seconds
        setTimeout(() => {
          this.showNotification = false;
        }, 10000);
      }
    });
  }

  ngOnDestroy(): void {
    this.socket.disconnect();
  }

  reloadPage(): void {
    window.location.reload();
  }

  private getServiceDisplayName(service: string): string {
    const names: { [key: string]: string } = {
      'frontend': 'Frontend',
      'backend': 'Backend',
      'payment-service': 'Payment Service'
    };
    return names[service] || service;
  }
}
