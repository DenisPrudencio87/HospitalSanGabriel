import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { App } from './app';
describe('Signal Forms', () => {
  it('rejects fractional quantities and nonpositive prices', () => {
    TestBed.configureTestingModule({
      imports: [App],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    const app = TestBed.createComponent(App).componentInstance;
    app.movementModel.update((m) => ({ ...m, quantity: 1.5 }));
    app.productModel.update((m) => ({ ...m, price: 0 }));
    expect(app.movementForm.quantity().invalid()).toBe(true);
    expect(app.productForm.price().invalid()).toBe(true);
  });
});
