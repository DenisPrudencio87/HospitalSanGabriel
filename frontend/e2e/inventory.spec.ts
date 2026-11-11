import { test, expect, Page } from '@playwright/test';

async function login(page: Page) {
  if (!process.env.E2E_USERNAME || !process.env.E2E_PASSWORD)
    throw new Error(
      'Configure credenciales de una base exclusiva de pruebas en E2E_USERNAME y E2E_PASSWORD',
    );
  await page.goto('/');
  await page.getByLabel('Usuario', { exact: true }).fill(process.env.E2E_USERNAME);
  await page.getByLabel('Contraseña', { exact: true }).fill(process.env.E2E_PASSWORD);
  await page.getByRole('button', { name: 'Iniciar sesión' }).click();
  await expect(page.getByRole('heading', { name: 'Resumen', exact: true })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
}

test('login → producto → entrada → salida → historial → dashboard', async ({ page }) => {
  await login(page);
  await page.getByRole('button', { name: 'Productos', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
  await page.getByRole('button', { name: 'Guardar producto' }).click();
  await expect(page.getByText('Código obligatorio', { exact: true })).toBeVisible();
  const code = 'UI-' + Date.now();
  await page.getByLabel(/^Código único/).fill(code);
  await page.getByLabel(/^Nombre/).fill('Producto navegador ' + code);
  await page
    .getByRole('combobox', { name: /^Categoría(?:\s|$)/ })
    .first()
    .selectOption('1');
  await page.getByLabel(/^Unidad/).selectOption('1');
  await page.getByLabel('Precio unitario (S/)', { exact: true }).fill('3.50');
  await page.getByLabel('Stock mínimo', { exact: true }).fill('10');
  await page.getByRole('button', { name: 'Guardar producto' }).click();
  await expect(page.locator('.notice.success')).toContainText('Producto guardado');
  await page.getByRole('button', { name: 'Entradas', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
  const productSelect = page.getByRole('combobox', { name: 'Producto', exact: true });
  const value = await productSelect
    .locator('option')
    .filter({ hasText: code })
    .getAttribute('value');
  await productSelect.selectOption(value!);
  await page.getByLabel('Cantidad', { exact: true }).fill('10');
  await page.getByRole('combobox', { name: 'Tipo de ingreso', exact: true }).selectOption('1');
  await page.getByLabel('Número de lote', { exact: true }).fill('UI-LOTE');
  await page.getByLabel('Vencimiento', { exact: true }).fill('2028-12-31');
  await page.getByLabel('Motivo / observación', { exact: true }).fill('Compra prueba navegador');
  await page.getByRole('button', { name: 'Registrar entrada', exact: true }).click();
  await expect(page.locator('.notice.success')).toContainText('Stock 0 → 10');
  await page.getByRole('button', { name: 'Salidas', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
  await page.getByRole('combobox', { name: 'Producto', exact: true }).selectOption(value!);
  await page.getByLabel('Cantidad', { exact: true }).fill('11');
  await page
    .getByRole('combobox', { name: 'Área hospitalaria de destino', exact: true })
    .selectOption('1');
  await page.getByLabel('Motivo / observación', { exact: true }).fill('Atención navegador');
  await page.getByRole('button', { name: 'Registrar salida', exact: true }).click();
  await expect(page.locator('.notice.error')).toContainText('stock insuficiente');
  await page.getByLabel('Cantidad', { exact: true }).fill('3');
  await page.getByRole('button', { name: 'Registrar salida', exact: true }).click();
  await expect(page.locator('.notice.success')).toContainText('Stock 10 → 7');
  await page.getByRole('button', { name: 'Historial', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
  await page.getByRole('combobox', { name: 'Producto', exact: true }).selectOption(value!);
  await page.getByRole('button', { name: 'Filtrar', exact: true }).click();
  await expect(page.locator('tbody tr')).toHaveCount(2);
  await expect(page.locator('tbody')).toContainText('UI-LOTE');
  await expect(page.locator('tbody')).toContainText('10 → 7');
  await page.getByRole('button', { name: 'Resumen', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Actualizar' })).toBeEnabled();
  await expect(page.locator('table').first()).toContainText(code);
  await page.screenshot({ path: 'test-results/dashboard-desktop.png', fullPage: true });
});

test('mobile navigation and viewport', async ({ page }) => {
  await page.setViewportSize({ width: 360, height: 800 });
  await login(page);
  await expect(page.getByRole('heading', { name: 'Resumen', exact: true })).toBeVisible();
  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth > window.innerWidth,
  );
  expect(overflow).toBe(false);
  await page.getByRole('button', { name: 'Entradas', exact: true }).click();
  await expect(page.getByRole('heading', { name: 'Nueva entrada', exact: true })).toBeVisible();
  await page.screenshot({ path: 'test-results/entry-mobile.png', fullPage: true });
});
