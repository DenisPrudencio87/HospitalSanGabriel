import { Component, computed, inject, signal } from '@angular/core';
import { CurrencyPipe, DatePipe } from '@angular/common';
import {
  FormField,
  form,
  required,
  min,
  maxLength,
  validate,
  submit,
} from '@angular/forms/signals';
import { Api, Catalog, Dashboard, Lot, Movement, Product } from './core/api';
import { Errors } from './shared/errors';
type Section = 'dashboard' | 'products' | 'categories' | 'entries' | 'exits' | 'history';
const today = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'America/Lima' });
const blankProduct = () => ({
  code: '',
  name: '',
  description: '',
  category_id: '',
  unit_id: '',
  price: 1,
  min_stock: 0,
  tracks_expiry: true,
});
const blankMovement = () => ({
  product_id: '',
  quantity: 1,
  movement_date: today(),
  reason: '',
  entry_reason_id: '',
  area_id: '',
  lot_code: '',
  expiry: '',
});
@Component({
  selector: 'app-root',
  imports: [FormField, Errors, CurrencyPipe, DatePipe],
  templateUrl: './app.html',
  styleUrl: './app.css',
})
export class App {
  api = inject(Api);
  section = signal<Section>('dashboard');
  busy = signal(false);
  error = signal('');
  success = signal('');
  categories = signal<Catalog[]>([]);
  units = signal<Catalog[]>([]);
  areas = signal<Catalog[]>([]);
  reasons = signal<Catalog[]>([]);
  products = signal<Product[]>([]);
  choices = signal<Product[]>([]);
  historyChoices = signal<Product[]>([]);
  movements = signal<Movement[]>([]);
  dashboard = signal<Dashboard | null>(null);
  selectedLots = signal<Lot[]>([]);
  lotTitle = signal('');
  editing = signal<number | null>(null);
  productPage = signal(1);
  historyPage = signal(1);
  pageSize = 20;
  today = today();
  totalProducts = computed(() => this.products()[0]?.total_count || 0);
  totalMovements = computed(() => this.movements()[0]?.total_count || 0);
  nav: { id: Section; label: string; icon: string }[] = [
    { id: 'dashboard', label: 'Resumen', icon: '▦' },
    { id: 'products', label: 'Productos', icon: '▤' },
    { id: 'categories', label: 'Categorías', icon: '◈' },
    { id: 'entries', label: 'Entradas', icon: '↙' },
    { id: 'exits', label: 'Salidas', icon: '↗' },
    { id: 'history', label: 'Historial', icon: '◷' },
  ];
  title = computed(() => this.nav.find((n) => n.id === this.section())?.label || 'Inventario');
  loginModel = signal({ username: '', password: '' });
  loginForm = form(this.loginModel, (p) => {
    required(p.username, { message: 'Ingrese su usuario' });
    required(p.password, { message: 'Ingrese su contraseña' });
  });
  productModel = signal(blankProduct());
  productForm = form(this.productModel, (p) => {
    required(p.code, { message: 'Código obligatorio' });
    maxLength(p.code, 40);
    required(p.name, { message: 'Nombre obligatorio' });
    maxLength(p.name, 150);
    maxLength(p.description, 500);
    required(p.category_id, { message: 'Seleccione categoría' });
    required(p.unit_id, { message: 'Seleccione unidad' });
    min(p.price, 0.01, { message: 'Precio mayor que cero' });
    min(p.min_stock, 0, { message: 'Mínimo no negativo' });
    validate(p.min_stock, ({ value }) =>
      Number.isInteger(value()) ? null : { kind: 'integer', message: 'Ingrese un entero' },
    );
    validate(p.price, ({ value }) =>
      Number.isFinite(value()) && Math.abs(value() * 100 - Math.round(value() * 100)) < 0.0001
        ? null
        : { kind: 'decimal', message: 'Use hasta dos decimales' },
    );
  });
  categoryModel = signal({ name: '', description: '' });
  categoryForm = form(this.categoryModel, (p) => {
    required(p.name, { message: 'Nombre obligatorio' });
    maxLength(p.name, 100);
    maxLength(p.description, 500);
  });
  movementModel = signal(blankMovement());
  selectedProduct = computed(() =>
    this.choices().find((p) => p.id === Number(this.movementModel().product_id)),
  );
  movementForm = form(this.movementModel, (p) => {
    required(p.product_id, { message: 'Seleccione producto' });
    min(p.quantity, 1, { message: 'Cantidad positiva' });
    validate(p.quantity, ({ value }) =>
      Number.isInteger(value())
        ? null
        : { kind: 'integer', message: 'La cantidad debe ser entera' },
    );
    required(p.movement_date, { message: 'Ingrese fecha' });
    validate(p.movement_date, ({ value }) =>
      value() <= today() ? null : { kind: 'date', message: 'No se permiten fechas futuras' },
    );
    required(p.reason, { message: 'Describa el motivo' });
    maxLength(p.reason, 250);
    required(p.entry_reason_id, {
      message: 'Seleccione motivo',
      when: () => this.section() === 'entries',
    });
    required(p.lot_code, { message: 'Ingrese lote', when: () => this.section() === 'entries' });
    maxLength(p.lot_code, 80);
    required(p.expiry, {
      message: 'Vencimiento obligatorio',
      when: () => this.section() === 'entries' && !!this.selectedProduct()?.tracks_expiry,
    });
    required(p.area_id, { message: 'Seleccione destino', when: () => this.section() === 'exits' });
  });
  filterModel = signal({ search: '', category_id: '', active: 'true' });
  filterForm = form(this.filterModel);
  historyModel = signal({ product_id: '', kind: '', area_id: '', date_from: '', date_to: '' });
  historyForm = form(this.historyModel);
  dateModel = signal({ date_from: '', date_to: '' });
  dateForm = form(this.dateModel);
  requestId = crypto.randomUUID();
  async run(action: () => Promise<unknown>) {
    if (this.busy()) return;
    this.busy.set(true);
    this.error.set('');
    this.success.set('');
    try {
      await action();
    } catch (e) {
      this.error.set(e instanceof Error ? e.message : 'Error inesperado');
    } finally {
      this.busy.set(false);
    }
  }
  async refresh() {
    await this.run(() => this.reload());
  }
  async login(event: Event) {
    event.preventDefault();
    await this.run(() =>
      submit(this.loginForm, async () => {
        const m = this.loginModel();
        await this.api.login(m.username, m.password);
        this.loginModel.set({ username: m.username, password: '' });
        await this.reload();
      }),
    );
  }
  async allProducts(activeOnly: boolean): Promise<Product[]> {
    let result: Product[] = [];
    for (let page = 1; ; page++) {
      const batch = await this.api.request<Product[]>(
        'GET',
        `/products?${activeOnly ? 'active=true&' : ''}page_size=200&page=${page}`,
      );
      result = result.concat(batch);
      if (batch.length < 200 || result.length >= (batch[0]?.total_count || 0)) return result;
    }
  }
  async reload() {
    const [c, u, a, r, products] = await Promise.all([
      this.api.request<Catalog[]>('GET', '/catalogs/categories'),
      this.api.request<Catalog[]>('GET', '/catalogs/units'),
      this.api.request<Catalog[]>('GET', '/catalogs/areas'),
      this.api.request<Catalog[]>('GET', '/catalogs/reasons'),
      this.allProducts(false),
    ]);
    this.categories.set(c);
    this.units.set(u);
    this.areas.set(a);
    this.reasons.set(r);
    this.choices.set(products.filter((p) => p.active));
    this.historyChoices.set(products);
    await Promise.all([this.loadProducts(), this.loadHistory(), this.loadDashboard()]);
  }
  async go(section: Section) {
    if (this.busy()) return;
    this.section.set(section);
    this.lotTitle.set('');
    this.movementModel.set(blankMovement());
    this.requestId = crypto.randomUUID();
    await this.run(() => this.reload());
  }
  async loadProducts() {
    const q = new URLSearchParams();
    Object.entries(this.filterModel()).forEach(([k, v]) => {
      if (v) q.set(k, v);
    });
    q.set('page', String(this.productPage()));
    q.set('page_size', String(this.pageSize));
    this.products.set(await this.api.request<Product[]>('GET', '/products?' + q));
  }
  async searchProducts(e?: Event) {
    e?.preventDefault();
    await this.run(() =>
      submit(this.filterForm, async () => {
        this.productPage.set(1);
        await this.loadProducts();
      }),
    );
  }
  async pageProducts(d: number) {
    this.productPage.update((p) => p + d);
    await this.run(() => this.loadProducts());
  }
  edit(p: Product) {
    this.editing.set(p.id);
    this.productModel.set({
      code: p.code,
      name: p.name,
      description: p.description,
      category_id: String(p.category_id),
      unit_id: String(p.unit_id),
      price: Number(p.price),
      min_stock: p.min_stock,
      tracks_expiry: p.tracks_expiry,
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
  cancelEdit() {
    this.editing.set(null);
    this.productModel.set(blankProduct());
    this.productForm().reset();
  }
  async saveProduct(e: Event) {
    e.preventDefault();
    await this.run(() =>
      submit(this.productForm, async () => {
        const m = this.productModel();
        await this.api.request(
          this.editing() ? 'PUT' : 'POST',
          '/products' + (this.editing() ? '/' + this.editing() : ''),
          { ...m, category_id: Number(m.category_id), unit_id: Number(m.unit_id) },
        );
        this.cancelEdit();
        await this.reload();
        this.success.set('Producto guardado.');
      }),
    );
  }
  async deactivate(p: Product) {
    if (!confirm(`¿Desactivar ${p.name}? Su historial se conserva.`)) return;
    await this.run(async () => {
      await this.api.request('PATCH', `/products/${p.id}/deactivate`);
      await this.reload();
      this.success.set('Producto desactivado; historial conservado.');
    });
  }
  async showLots(p: Product) {
    await this.run(async () => {
      this.selectedLots.set(await this.api.request<Lot[]>('GET', `/products/${p.id}/lots`));
      this.lotTitle.set(p.name);
    });
  }
  async saveCategory(e: Event) {
    e.preventDefault();
    await this.run(() =>
      submit(this.categoryForm, async () => {
        await this.api.request('POST', '/categories', this.categoryModel());
        this.categoryModel.set({ name: '', description: '' });
        this.categoryForm().reset();
        await this.reload();
        this.success.set('Categoría registrada.');
      }),
    );
  }
  async saveMovement(e: Event) {
    e.preventDefault();
    await this.run(() =>
      submit(this.movementForm, async () => {
        const m = this.movementModel(),
          entry = this.section() === 'entries';
        const body = {
          request_id: this.requestId,
          product_id: Number(m.product_id),
          quantity: m.quantity,
          movement_date: m.movement_date,
          reason: m.reason,
          entry_reason_id: entry ? Number(m.entry_reason_id) : null,
          area_id: entry ? null : Number(m.area_id),
          lot_code: entry ? m.lot_code : null,
          expiry: entry && m.expiry ? m.expiry : null,
        };
        const r = await this.api.request<Movement>('POST', entry ? '/entries' : '/exits', body);
        this.requestId = crypto.randomUUID();
        this.movementModel.set(blankMovement());
        this.movementForm().reset();
        await this.reload();
        this.success.set(
          `Movimiento #${r.id}. Stock ${r.stock_before} → ${r.stock_after}. Lotes: ${r.lots.map((l) => l.lot_code + ' (' + l.quantity + ')').join(', ')}`,
        );
      }),
    );
  }
  async loadHistory() {
    const q = new URLSearchParams();
    Object.entries(this.historyModel()).forEach(([k, v]) => {
      if (v) q.set(k, v);
    });
    q.set('page', String(this.historyPage()));
    q.set('page_size', String(this.pageSize));
    this.movements.set(await this.api.request<Movement[]>('GET', '/movements?' + q));
  }
  async filterHistory(e: Event) {
    e.preventDefault();
    await this.run(() =>
      submit(this.historyForm, async () => {
        this.historyPage.set(1);
        await this.loadHistory();
      }),
    );
  }
  async pageHistory(d: number) {
    this.historyPage.update((p) => p + d);
    await this.run(() => this.loadHistory());
  }
  async loadDashboard() {
    const q = new URLSearchParams();
    Object.entries(this.dateModel()).forEach(([k, v]) => {
      if (v) q.set(k, v);
    });
    this.dashboard.set(await this.api.request<Dashboard>('GET', '/dashboard?' + q));
  }
  async filterDashboard(e: Event) {
    e.preventDefault();
    await this.run(() =>
      submit(this.dateForm, async () => {
        await this.loadDashboard();
      }),
    );
  }
  logout() {
    this.api.logout();
    this.dashboard.set(null);
    this.products.set([]);
    this.movements.set([]);
    this.error.set('');
    this.success.set('');
  }
}
