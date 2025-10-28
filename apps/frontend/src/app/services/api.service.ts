import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  Order,
  CreateOrderRequest,
  CreateOrderResponse,
} from '@honey-store/shared/types';
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

  getAllOrders(): Observable<Order[]> {
    return this.http.get<Order[]>(`${this.backendUrl}/api/orders`);
  }
}
