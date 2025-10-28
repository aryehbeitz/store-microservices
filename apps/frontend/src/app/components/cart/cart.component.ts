import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { Cart, CartItem } from '@honey-store/shared/types';
import { CartService } from '../../services/cart.service';

@Component({
  selector: 'app-cart',
  templateUrl: './cart.component.html',
  styleUrls: ['./cart.component.css'],
})
export class CartComponent implements OnInit {
  cart: Cart = { items: [], total: 0 };

  constructor(private cartService: CartService, private router: Router) {}

  ngOnInit() {
    this.cartService.cart$.subscribe((cart) => {
      this.cart = cart;
    });
  }

  updateQuantity(productId: string, quantity: number) {
    this.cartService.updateQuantity(productId, quantity);
  }

  removeItem(productId: string) {
    this.cartService.removeFromCart(productId);
  }

  proceedToCheckout() {
    if (this.cart.items.length > 0) {
      this.router.navigate(['/checkout']);
    }
  }

  continueShopping() {
    this.router.navigate(['/']);
  }
}
