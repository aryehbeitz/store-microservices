import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable } from 'rxjs';
import { Cart, CartItem, Product } from '@honey-store/shared/types';

@Injectable({
  providedIn: 'root',
})
export class CartService {
  private cart: Cart = { items: [], total: 0 };
  private cartSubject = new BehaviorSubject<Cart>(this.cart);
  public cart$ = this.cartSubject.asObservable();

  constructor() {
    this.loadCartFromLocalStorage();
  }

  private loadCartFromLocalStorage() {
    const savedCart = localStorage.getItem('honey-store-cart');
    if (savedCart) {
      this.cart = JSON.parse(savedCart);
      this.cartSubject.next(this.cart);
    }
  }

  private saveCartToLocalStorage() {
    localStorage.setItem('honey-store-cart', JSON.stringify(this.cart));
    this.cartSubject.next(this.cart);
  }

  addToCart(product: Product, quantity: number = 1) {
    const existingItem = this.cart.items.find(
      (item) => item.product.id === product.id
    );

    if (existingItem) {
      existingItem.quantity += quantity;
    } else {
      this.cart.items.push({ product, quantity });
    }

    this.calculateTotal();
    this.saveCartToLocalStorage();
  }

  removeFromCart(productId: string) {
    this.cart.items = this.cart.items.filter(
      (item) => item.product.id !== productId
    );
    this.calculateTotal();
    this.saveCartToLocalStorage();
  }

  updateQuantity(productId: string, quantity: number) {
    const item = this.cart.items.find(
      (item) => item.product.id === productId
    );
    if (item) {
      item.quantity = quantity;
      if (item.quantity <= 0) {
        this.removeFromCart(productId);
      } else {
        this.calculateTotal();
        this.saveCartToLocalStorage();
      }
    }
  }

  clearCart() {
    this.cart = { items: [], total: 0 };
    this.saveCartToLocalStorage();
  }

  getCart(): Cart {
    return this.cart;
  }

  getCartItemCount(): number {
    return this.cart.items.reduce((count, item) => count + item.quantity, 0);
  }

  private calculateTotal() {
    this.cart.total = this.cart.items.reduce(
      (total, item) => total + item.product.price * item.quantity,
      0
    );
  }
}
