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
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZFRTBEIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5Ib25leTwvdGV4dD4KPC9zdmc+',
      inStock: true,
    },
    {
      id: '2',
      name: 'Manuka Honey MGO 400+',
      description: 'Premium New Zealand Manuka honey with MGO 400+ certification. Known for antibacterial properties.',
      price: 49.99,
      category: 'honey',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5NYW51a2E8L3RleHQ+Cjwvc3ZnPg==',
      inStock: true,
    },
    {
      id: '3',
      name: 'Lavender Honey',
      description: 'Delicate floral honey harvested from lavender fields. Perfect for tea and desserts.',
      price: 28.99,
      category: 'honey',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iODAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5MYXZlbmRlcjwvdGV4dD4KPC9zdmc+',
      inStock: true,
    },
    {
      id: '4',
      name: 'Beekeeping Starter Kit',
      description: 'Complete starter kit with hive, frames, smoker, and protective gear. Everything you need to start beekeeping.',
      price: 299.99,
      category: 'equipment',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiBmaWxsPSIjOEI0NTEzIi8+CjxzdmcgeD0iMTYwIiB5PSIxMDAiIHdpZHRoPSI4MCIgaGVpZ2h0PSIxMDAiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0iI0ZGRkZGRiI+CjxwYXRoIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyem0tMSAxN2gtMnYtMmgydjJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjIwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjOEI0NTEzIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5LaXQ8L3RleHQ+Cjwvc3ZnPg==',
      inStock: true,
    },
    {
      id: '5',
      name: 'Professional Bee Suit',
      description: 'Full-body protection suit with ventilated hood. Made from durable, breathable cotton.',
      price: 89.99,
      category: 'equipment',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiBmaWxsPSIjRkZGRkZGIiBzdHJva2U9IiM4QjQ1MTMiIHN0cm9rZS13aWR0aD0iNCIvPgo8c3ZnIHg9IjE2MCIgeT0iMTAwIiB3aWR0aD0iODAiIGhlaWdodD0iMTAwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiM4QjQ1MTMiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjIwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjOEI0NTEzIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5TdWl0PC90ZXh0Pgo8L3N2Zz4=',
      inStock: true,
    },
    {
      id: '6',
      name: 'Stainless Steel Smoker',
      description: 'High-quality bee smoker with heat shield. Essential tool for safe hive inspection.',
      price: 34.99,
      category: 'equipment',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxyZWN0IHg9IjE2MCIgeT0iMTIwIiB3aWR0aD0iODAiIGhlaWdodD0iNjAiIGZpbGw9IiNDQ0NDQ0MiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjQ0NDQ0NDIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5TbW9rZXI8L3RleHQ+Cjwvc3ZnPg==',
      inStock: true,
    },
    {
      id: '7',
      name: 'Honey Dipper Set',
      description: 'Handcrafted wooden honey dippers in various sizes. Perfect for serving honey.',
      price: 12.99,
      category: 'accessories',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNENzcxMDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRDc3MTAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5EaXBwZXI8L3RleHQ+Cjwvc3ZnPg==',
      inStock: true,
    },
    {
      id: '8',
      name: 'Glass Honey Jar Set (6 pack)',
      description: 'Premium glass jars with cork lids. Ideal for storing and gifting honey.',
      price: 24.99,
      category: 'accessories',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNGRkZGRkYiIHN0cm9rZT0iI0ZGRDcwMCIgc3Ryb2tlLXdpZHRoPSI0Ii8+CjxzdmcgeD0iMTYwIiB5PSIxMjAiIHdpZHRoPSI4MCIgaGVpZ2h0PSI2MCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSIjRkZENzAwIj4KPHBhdGggZD0iTTEyIDJDNi40OCAyIDIgNi40OCAyIDEyczQuNDggMTAgMTAgMTAgMTAtNC40OCAxMC0xMFMxNy41MiAyIDEyIDJ6bS0xIDE3aC0ydi0yaDJ2MnptMC00aDJWOWgtMnY2em0wLTRoMnYyaC0ydi0yeiIvPgo8L3N2Zz4KPHRleHQgeD0iMjAwIiB5PSIyMDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGZpbGw9IiNGRkQ3MDAiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxOCIgZm9udC13ZWlnaHQ9ImJvbGQiPkphcnM8L3RleHQ+Cjwvc3ZnPg==',
      inStock: true,
    },
    {
      id: '9',
      name: 'Beeswax Candle Making Kit',
      description: 'Create your own natural beeswax candles. Includes molds, wicks, and pure beeswax.',
      price: 39.99,
      category: 'accessories',
      imageUrl: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAwIiBoZWlnaHQ9IjMwMCIgdmlld0JveD0iMCAwIDQwMCAzMDAiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSI0MDAiIGhlaWdodD0iMzAwIiBmaWxsPSIjRkZGRkZGIi8+CjxjaXJjbGUgY3g9IjIwMCIgY3k9IjE1MCIgcj0iNDAiIGZpbGw9IiNGRkQ3MDAiLz4KPHN2ZyB4PSIxNjAiIHk9IjEyMCIgd2lkdGg9IjgwIiBoZWlnaHQ9IjYwIiB2aWV3Qm94PSIwIDAgMjQgMjQiIGZpbGw9IiNGRkZGRkYiPgo8cGF0aCBkPSJNMTIgMkM2LjQ4IDIgMiA2LjQ4IDIgMTJzNC40OCAxMCAxMCAxMCAxMC00LjQ4IDEwLTEwUzE3LjUyIDIgMTIgMnptLTEgMTdoLTJ2LTJoMnYyem0wLTQtMmgydjJoLTJ2LTJ6bTAtNGgyVjloLTJ2NnoiLz4KPC9zdmc+Cjx0ZXh0IHg9IjIwMCIgeT0iMjAwIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjRkZENzAwIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTgiIGZvbnQtd2VpZ2h0PSJib2xkIj5DYW5kbGU8L3RleHQ+Cjwvc3ZnPg==',
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
