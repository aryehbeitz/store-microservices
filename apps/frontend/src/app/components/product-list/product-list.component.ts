import { Component, OnInit } from '@angular/core';
import { Product } from '@honey-store/shared/types';
import { ProductService } from '../../services/product.service';
import { CartService } from '../../services/cart.service';

@Component({
  selector: 'app-product-list',
  templateUrl: './product-list.component.html',
  styleUrls: ['./product-list.component.css'],
})
export class ProductListComponent implements OnInit {
  products: Product[] = [];
  selectedCategory: string = 'all';
  addedToCartId: string | null = null;

  constructor(
    private productService: ProductService,
    private cartService: CartService
  ) {}

  ngOnInit() {
    this.loadProducts();
  }

  loadProducts() {
    if (this.selectedCategory === 'all') {
      this.productService.getProducts().subscribe((products) => {
        this.products = products;
      });
    } else {
      this.productService
        .getProductsByCategory(this.selectedCategory)
        .subscribe((products) => {
          this.products = products;
        });
    }
  }

  filterByCategory(category: string) {
    this.selectedCategory = category;
    this.loadProducts();
  }

  addToCart(product: Product) {
    this.cartService.addToCart(product);
    this.addedToCartId = product.id;
    setTimeout(() => {
      this.addedToCartId = null;
    }, 1500);
  }
}
