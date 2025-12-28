import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { Cart, CreateOrderRequest } from '@honey-store/shared/types';
import { ApiService } from '../../services/api.service';
import { CartService } from '../../services/cart.service';

@Component({
  selector: 'app-checkout',
  templateUrl: './checkout.component.html',
  styleUrls: ['./checkout.component.css'],
})
export class CheckoutComponent implements OnInit {
  checkoutForm: FormGroup;
  cart: Cart = { items: [], total: 0 };
  isSubmitting = false;
  orderPlaced = false;
  orderId: string | null = null;

  constructor(
    private fb: FormBuilder,
    private cartService: CartService,
    private apiService: ApiService,
    private router: Router
  ) {
    this.checkoutForm = this.fb.group({
      customerName: ['', [Validators.required, Validators.minLength(2)]],
      customerEmail: ['', [Validators.required, Validators.email]],
      shippingAddress: ['', [Validators.required, Validators.minLength(10)]],
    });
  }

  ngOnInit() {
    this.cartService.cart$.subscribe((cart) => {
      this.cart = cart;
      if (cart.items.length === 0 && !this.orderPlaced) {
        this.router.navigate(['/cart']);
      }
    });

    // Load saved shipping info from localStorage
    this.loadSavedShippingInfo();
  }

  async onSubmit() {
    if (this.checkoutForm.valid && !this.isSubmitting) {
      this.isSubmitting = true;

      // Save shipping info to localStorage
      this.saveShippingInfo();

      const orderData: CreateOrderRequest = {
        items: this.cart.items,
        total: this.cart.total,
        customerName: this.checkoutForm.value.customerName,
        customerEmail: this.checkoutForm.value.customerEmail,
        shippingAddress: this.checkoutForm.value.shippingAddress,
      };

      this.apiService.createOrder(orderData).subscribe({
        next: (response) => {
          console.log('Order created:', response);
          this.orderId = response.orderId;
          this.orderPlaced = true;
          this.cartService.clearCart();
        },
        error: (error) => {
          console.error('Error creating order:', error);
          this.isSubmitting = false;
          alert('Failed to place order. Please try again.');
        },
      });
    }
  }

  private loadSavedShippingInfo(): void {
    try {
      const savedInfo = localStorage.getItem('honey-store-shipping-info');
      if (savedInfo) {
        const shippingInfo = JSON.parse(savedInfo);
        this.checkoutForm.patchValue({
          customerName: shippingInfo.customerName || '',
          customerEmail: shippingInfo.customerEmail || '',
          shippingAddress: shippingInfo.shippingAddress || '',
        });
      }
    } catch (error) {
      console.error('Error loading saved shipping info:', error);
    }
  }

  private saveShippingInfo(): void {
    try {
      const shippingInfo = {
        customerName: this.checkoutForm.value.customerName,
        customerEmail: this.checkoutForm.value.customerEmail,
        shippingAddress: this.checkoutForm.value.shippingAddress,
      };
      localStorage.setItem('honey-store-shipping-info', JSON.stringify(shippingInfo));
    } catch (error) {
      console.error('Error saving shipping info:', error);
    }
  }
}
