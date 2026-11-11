import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { inject, Injectable, signal } from '@angular/core';
import { firstValueFrom } from 'rxjs';

export interface Catalog {
  id: number;
  name: string;
  description?: string;
}
export interface Product {
  id: number;
  code: string;
  name: string;
  description: string;
  category_id: number;
  unit_id: number;
  category_name: string;
  unit_name: string;
  price: number;
  min_stock: number;
  stock: number;
  available_stock: number;
  expired_stock: number;
  tracks_expiry: boolean;
  active: boolean;
  next_expiry: string | null;
  total_count: number;
}
export interface Lot {
  id: number;
  code: string;
  expiry: string | null;
  stock: number;
  expired: number;
}
export interface Movement {
  id: number;
  product_id: number;
  product_code: string;
  product_name: string;
  kind: string;
  quantity: number;
  movement_date: string;
  reason: string;
  area_name: string | null;
  username: string;
  stock_before: number;
  stock_after: number;
  lots: { lot_code: string; expiry: string | null; quantity: number }[];
  total_count: number;
}
export interface Dashboard {
  summary: {
    active_products: number;
    low_stock_products: number;
    expiring_products: number;
    expired_products: number;
    inventory_value: number;
  };
  low_stock: Product[];
  expiry: (Product & { expiring_stock: number })[];
  movements: { movement_date: string; kind: string; quantity: number; movements: number }[];
  top_exits: { id: number; name: string; quantity: number }[];
}

@Injectable({ providedIn: 'root' })
export class Api {
  private http = inject(HttpClient);
  token = signal('');
  username = signal('');

  async request<T>(method: string, path: string, body?: unknown): Promise<T> {
    try {
      return await firstValueFrom(
        this.http.request<T>(method, '/api/v1' + path, {
          body,
          headers: this.token() ? { Authorization: 'Bearer ' + this.token() } : {},
        }),
      );
    } catch (error) {
      if (error instanceof HttpErrorResponse) {
        if (error.status === 401) this.logout();
        const detail = error.error?.detail;
        const message = Array.isArray(detail)
          ? detail.map((x: { msg: string }) => x.msg).join('; ')
          : detail;
        throw new Error(message || 'No se pudo conectar con el servidor. Revise el backend.');
      }
      throw error;
    }
  }
  async login(username: string, password: string) {
    const result = await this.request<{ access_token: string; username: string }>(
      'POST',
      '/auth/login',
      { username, password },
    );
    this.token.set(result.access_token);
    this.username.set(result.username);
  }
  logout() {
    this.token.set('');
    this.username.set('');
  }
}
