import { Injectable } from '@angular/core';
import { Observable, of } from 'rxjs';
import { Product } from '@honey-store/shared/types';

@Injectable({
  providedIn: 'root',
})
export class ProductService {
  private products: Product[] = [
    {
      id: '1',
      name: 'Pure Wildflower Honey',
      description: 'Raw, unfiltered wildflower honey from local beekeepers. Rich in antioxidants and natural enzymes.',
      price: 24.99,
      category: 'honey',
      imageUrl: 'https://images.unsplash.com/photo-1587049352846-4a222e784240?w=400',
      inStock: true,
    },
    {
      id: '2',
      name: 'Manuka Honey MGO 400+',
      description: 'Premium New Zealand Manuka honey with MGO 400+ certification. Known for antibacterial properties.',
      price: 49.99,
      category: 'honey',
      imageUrl: 'https://images.unsplash.com/photo-1558642452-9d2a7deb7f62?w=400',
      inStock: true,
    },
    {
      id: '3',
      name: 'Lavender Honey',
      description: 'Delicate floral honey harvested from lavender fields. Perfect for tea and desserts.',
      price: 28.99,
      category: 'honey',
      imageUrl: 'https://images.unsplash.com/photo-1471943311424-646960669fbc?w=400',
      inStock: true,
    },
    {
      id: '4',
      name: 'Beekeeping Starter Kit',
      description: 'Complete starter kit with hive, frames, smoker, and protective gear. Everything you need to start beekeeping.',
      price: 299.99,
      category: 'equipment',
      imageUrl: 'https://images.unsplash.com/photo-1558642084-fd07fae5282e?w=400',
      inStock: true,
    },
    {
      id: '5',
      name: 'Professional Bee Suit',
      description: 'Full-body protection suit with ventilated hood. Made from durable, breathable cotton.',
      price: 89.99,
      category: 'equipment',
      imageUrl: 'https://images.unsplash.com/photo-1560173638-e0c685e7f98b?w=400',
      inStock: true,
    },
    {
      id: '6',
      name: 'Stainless Steel Smoker',
      description: 'High-quality bee smoker with heat shield. Essential tool for safe hive inspection.',
      price: 34.99,
      category: 'equipment',
      imageUrl: 'https://images.unsplash.com/photo-1517849845537-4d257902454a?w=400',
      inStock: true,
    },
    {
      id: '7',
      name: 'Honey Dipper Set',
      description: 'Handcrafted wooden honey dippers in various sizes. Perfect for serving honey.',
      price: 12.99,
      category: 'accessories',
      imageUrl: 'https://images.unsplash.com/photo-1597573122230-c6c75c5f18f4?w=400',
      inStock: true,
    },
    {
      id: '8',
      name: 'Glass Honey Jar Set (6 pack)',
      description: 'Premium glass jars with cork lids. Ideal for storing and gifting honey.',
      price: 24.99,
      category: 'accessories',
      imageUrl: 'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=400',
      inStock: true,
    },
    {
      id: '9',
      name: 'Beeswax Candle Making Kit',
      description: 'Create your own natural beeswax candles. Includes molds, wicks, and pure beeswax.',
      price: 39.99,
      category: 'accessories',
      imageUrl: 'https://images.unsplash.com/photo-1602874801006-e04b6b0ce1c9?w=400',
      inStock: true,
    },
  ];

  constructor() {}

  getProducts(): Observable<Product[]> {
    return of(this.products);
  }

  getProductById(id: string): Observable<Product | undefined> {
    return of(this.products.find((p) => p.id === id));
  }

  getProductsByCategory(category: string): Observable<Product[]> {
    return of(this.products.filter((p) => p.category === category));
  }
}
