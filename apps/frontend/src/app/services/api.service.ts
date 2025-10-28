import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import {
    CreateOrderRequest,
    CreateOrderResponse,
    Order,
} from '@honey-store/shared/types';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class ApiService {
  private backendUrl = environment.backendUrl;

  constructor(private http: HttpClient) {}

  createOrder(orderData: CreateOrderRequest): Observable<CreateOrderResponse> {
    return this.http.post<CreateOrderResponse>(
      `${this.backendUrl}/api/orders`,
      orderData
    );
  }

  getOrder(orderId: string): Observable<Order> {
    return this.http.get<Order>(`${this.backendUrl}/api/orders/${orderId}`);
  }

  getAllOrders(): Observable<{ orders: Order[]; connectionInfo: any }> {
    return this.http.get<{ orders: Order[]; connectionInfo: any }>(`${this.backendUrl}/api/orders`);
  }

  getConnectionInfo(): Observable<any> {
    return this.http.get<any>(`${this.backendUrl}/api/connection-info`);
  }

  retryPayment(orderId: string): Observable<{ message: string; orderId: string; status: string }> {
    return this.http.post<{ message: string; orderId: string; status: string }>(
      `${this.backendUrl}/api/orders/${orderId}/retry-payment`,
      {}
    );
  }

  clearAllOrders(): Observable<{ message: string; deletedCount: number }> {
    return this.http.delete<{ message: string; deletedCount: number }>(
      `${this.backendUrl}/api/orders`
    );
  }
}
