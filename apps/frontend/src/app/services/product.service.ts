import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Product } from '@honey-store/shared/types';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class ProductService {
  private backendUrl = environment.backendUrl;

  constructor(private http: HttpClient) {}

  getProducts(category?: string): Observable<Product[]> {
    const url = category && category !== 'all'
      ? `${this.backendUrl}/api/products?category=${category}`
      : `${this.backendUrl}/api/products`;
    return this.http.get<Product[]>(url);
  }

  getProductById(id: string): Observable<Product> {
    return this.http.get<Product>(`${this.backendUrl}/api/products/${id}`);
  }

  getProductsByCategory(category: string): Observable<Product[]> {
    return this.http.get<Product[]>(`${this.backendUrl}/api/products?category=${category}`);
  }
}
