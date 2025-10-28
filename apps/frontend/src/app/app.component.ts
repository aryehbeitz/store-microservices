import { Component } from '@angular/core';
import { CartService } from './services/cart.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css'],
})
export class AppComponent {
  title = 'Honey Store';

  constructor(public cartService: CartService) {}

  get cartItemCount(): number {
    return this.cartService.getCartItemCount();
  }
}
