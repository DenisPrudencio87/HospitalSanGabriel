# Hospital San Gabriel

Sistema académico de inventario hospitalario para Desarrollo de Aplicaciones Web, Universidad Continental. Angular 22 con **Signal Forms reales**, FastAPI con cuatro capas y **Microsoft SQL Server local**. No usa bases de datos en la nube ni datos simulados en el frontend.

## Instalación rápida en Windows desde GitHub

Prerrequisitos instalados: Git, Node.js compatible con Angular 22, Python y ODBC Driver 18; una instancia SQL Server local accesible. Entorno comprobado: Node 24.21.0, npm 11.19.0, Python 3.14.8 y SQL Server 2025 Express. El SQL utiliza sintaxis disponible desde SQL Server 2016; otras versiones aún requieren prueba real.

Node compatible: 22.22.3 o superior de la rama 22; 24.15.0 o superior de la rama 24; o rama 26. Python recomendado: **3.14 de 64 bits**. Versiones distintas deben verificarse antes de la evaluación. No hay instaladores automáticos ni cambios de servicios, firewall o políticas del sistema.

Ejecutar en PowerShell:

```powershell
git clone https://github.com/DenisPrudencio87/HospitalSanGabriel.git
cd HospitalSanGabriel
py -3.14 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r backend/requirements.txt
npm.cmd ci --prefix frontend
```

No es necesario activar el entorno virtual ni instalar Angular globalmente. Si la universidad ofrece otra versión compatible de Python, sustituir `py -3.14` por su intérprete comprobado.

### Configurar SQL y crear la base

Ejecutar el diagnóstico:

```powershell
.\scripts\check-env.ps1
```

Inicialización rápida con autenticación Windows:

```powershell
.\scripts\setup-db.ps1 -Server 'localhost\SQLEXPRESS' -Database 'HospitalSanGabriel' -Demo
```

El script crea `.env` privado si no existe, genera un secreto JWT aleatorio, guarda los parámetros de servidor/base y ejecuta los scripts SQL en orden. **Se detiene si la base ya existe**; no la borra ni la sobrescribe. Elegir otro nombre para una nueva instalación, por ejemplo `HospitalSanGabrielEvaluacion`.

También puede copiarse `.env.example` a `.env` y configurarse antes de inicializar. En ese caso debe generarse un `JWT_SECRET` aleatorio de al menos 32 caracteres, por ejemplo:

```powershell
.\.venv\Scripts\python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
```

Variables SQL: `SQL_SERVER`, `SQL_DATABASE`, `SQL_DRIVER`, `SQL_AUTH`, `SQL_USER`, `SQL_PASSWORD`, `SQL_ENCRYPT`, `SQL_TRUST_CERTIFICATE`. Para autenticación SQL usar `SQL_AUTH=sql` y credenciales autorizadas en `.env`; el script no habilita el modo mixto. Los valores del entorno del proceso tienen precedencia sobre `.env`.

`SQL_TRUST_CERTIFICATE=yes` está previsto para SQL Express local con certificado autofirmado. Si hay certificado confiable, usar `no`. No se cambia la configuración del servidor ni se publican secretos.

La inicialización verifica tablas, relaciones, restricciones, índices, todos los procedimientos y coherencia de saldos. Si falla a mitad, conserva la base parcial y se detiene: no vuelve a ejecutar ciegamente ni elimina objetos. Usar una base nueva o solicitar revisión al administrador.

### Crear usuario y arrancar

```powershell
.\scripts\create-user.ps1 -Username operador
.\scripts\start.ps1
```

La contraseña se solicita de forma oculta dos veces, con mínimo 10 caracteres, y se almacena como hash Argon2. **No existe contraseña predeterminada.** El usuario de auditoría de los datos de demostración está deshabilitado y no puede iniciar sesión. No introducir contraseñas en comandos, Git ni README.

- Interfaz: **http://localhost:4200**.
- API/OpenAPI: **http://127.0.0.1:8000/docs**.
- Salud: **http://127.0.0.1:8000/api/v1/health** debe devolver `{"status":"ok"}`.
- Ctrl+C detiene el frontend y el backend iniciado por el script.

`API_PORT` permite cambiar el puerto del backend. El frontend usa `/api` y un proxy relativo; no hay direcciones personales en el código.

El arranque rechaza puertos ocupados. Para otra instancia usar `API_PORT` distinto y `start.ps1 -FrontendPort 4201`.

Si PowerShell bloquea scripts, no es necesario cambiar políticas permanentemente. Puede ejecutar los comandos manuales siguientes, o solicitar permiso para usar `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start.ps1`, que aplica solo a ese proceso.

### Alternativa manual de arranque

En una terminal, desde la raíz:

```powershell
.\.venv\Scripts\python.exe backend/tools/manage.py setup --demo
.\.venv\Scripts\python.exe backend/tools/manage.py create-user --username operador
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
```

Ejecutar `setup` solo para una base nueva. En otra terminal:

```powershell
npm.cmd start --prefix frontend
```

Si se cambia el puerto manualmente, establecer también `$env:API_PORT` en la terminal del frontend.

## Permisos SQL y seguridad de instalación

No se necesita ejecutar toda la aplicación como administrador de Windows.

| Tarea | Permisos SQL necesarios |
|---|---|
| Crear una base | `CREATE DATABASE` o permiso equivalente |
| Crear estructura en base dedicada | `CONNECT`, `CREATE TABLE`, `CREATE PROCEDURE`, `ALTER` sobre `dbo` y permisos de referencias necesarios |
| Crear usuario inicial | `CONNECT` y ejecución de `usp_User_Get` y `usp_User_Create` |
| Operación habitual | `CONNECT` y ejecución de procedimientos de aplicación |
| Crear identidades o conceder permisos | Administrador SQL autorizado |

Si no puede crear bases, pedir al administrador una base **vacía y dedicada** y usar:

```powershell
.\scripts\setup-db.ps1 -Database HospitalSanGabrielEvaluacion -ExistingEmpty -Demo
```

Esta modalidad rechaza bases con objetos de usuario. `database/06-permissions.sql` es un script opcional para el administrador: crea un rol de ejecución limitada sin acceso directo a tablas y sin permiso de crear usuarios iniciales. No se ejecuta automáticamente. La aplicación no necesita `sysadmin` ni `db_owner`.

## Funcionalidades y demostración

1. Iniciar sesión con el usuario creado localmente.
2. Consultar categorías o registrar una nueva; crear un producto con código único, categoría, unidad, precio positivo y mínimo.
3. Registrar una entrada con motivo controlado, cantidad entera, lote y vencimiento cuando corresponda.
4. Registrar una salida hacia un área hospitalaria. FEFO asigna lotes vigentes y rechaza stock disponible insuficiente.
5. Consultar historial por producto, tipo, área y fechas; ver saldos anterior/posterior y detalle de lotes.
6. Revisar dashboard, stock bajo, vencimientos, valor físico, movimientos por fecha y mayores salidas.
7. Desactivar un producto y comprobar que su historial sigue disponible.

`-Demo` carga datos persistidos en SQL: paracetamol con dos lotes vigentes; guantes con 5 unidades disponibles y 20 vencidas; gasas sin stock; bandejas sin vencimiento. Incluye compra, donación y devolución. Las fechas son relativas al día de instalación. Estos datos se cargan mediante procedimientos.

## Reglas de inventario

- Stock físico de producto = suma del stock de sus lotes. No hay edición manual del saldo.
- Stock disponible incluye lotes vigentes; stock vencido permanece trazable y bloqueado.
- Stock bajo compara **disponible ≤ mínimo** y muestra también físico y vencido.
- FEFO consume primero el vencimiento más cercano; lotes sin vencimiento van al final. Un movimiento puede consumir varios lotes.
- Vencimiento válido durante su fecha, según UTC-5 de Perú. Retroceder la fecha de salida no habilita un lote hoy vencido.
- Próximos a vencer: `EXPIRY_DAYS`, inicialmente 30 días.
- Entradas de lotes vencidos reflejan existencias reales, con advertencia, sin habilitar su uso.
- Cada movimiento bloquea el producto y lotes, valida y actualiza saldos e historial en una transacción SQL. Ante error, rollback completo.
- El identificador único de solicitud evita duplicar un movimiento al reintentarlo.
- Desactivar conserva historial y bloquea nuevos movimientos. La unidad y política de vencimiento no cambian tras registrar movimientos.
- Fechas efectivas pueden ser anteriores; los saldos reflejan orden de registro. El valor referencial usa precio actual por stock físico, incluido vencido.
- Token JWT en memoria, sin almacenamiento persistente en el navegador; recargar requiere iniciar sesión nuevamente.

## Arquitectura y endpoints

`backend/app/apis` recibe HTTP y autentica; `services` ejecuta casos de uso; `repositories` llama procedimientos parametrizados; `schemas` valida contratos con Pydantic. SQL directo queda limitado a scripts de aprovisionamiento y pruebas, fuera de las operaciones de negocio de la aplicación.

Prefijo `/api/v1`: `auth/login`, `auth/me`, `catalogs/{kind}`, `categories`, `products`, `products/{id}/lots`, `products/{id}/deactivate`, `entries`, `exits`, `movements`, `dashboard` y `health`. Consultar métodos y contratos completos en `/docs`. Listados de productos y movimientos paginados.

Errores: 401 sin sesión, 404 inexistente, 409 conflicto de inventario/duplicado, 422 datos inválidos y 503 indisponibilidad de conexión. No se exponen contraseñas ni errores SQL internos.

## Pruebas

```powershell
.\.venv\Scripts\python.exe -m pytest backend/tests -v
npm.cmd test --prefix frontend -- --watch=false
npm.cmd run build --prefix frontend
```

Las pruebas backend crean una base nueva `HSG_Test_<aleatorio>` y **la conservan** para inspección; requieren permiso para crear bases. No ejecutan fallos artificiales sobre la base de la aplicación. Incluyen concurrencia, rollback con fallo de historial, FEFO, vencidos, stock bajo, autenticación, duplicados e idempotencia. La prueba Angular comprueba validaciones de Signal Forms.

La guía y evidencias de portabilidad se encuentran en `docs/VALIDACION.md`. No se afirma compatibilidad con versiones o equipos que no se hayan probado.

Pruebas de navegador opcionales: con Chrome instalado y una instancia de la aplicación conectada a una **base exclusiva de pruebas**, configurar `E2E_USERNAME` y `E2E_PASSWORD` en el entorno de la terminal, entrar en `frontend` y ejecutar `npx.cmd playwright test`. No guardar esas credenciales en el repositorio. Playwright usa Chrome instalado y no descarga navegadores durante el arranque habitual.

## Git y entrega

Rama principal `main`; funcionalidades mediante ramas y Pull Requests con validación. Conservar `.env`, `.venv`, `node_modules`, bases, copias de seguridad y credenciales fuera del repositorio. Para evaluación, clonar la versión entregada y reconstruir SQL desde scripts; no se requieren archivos personales de la PC de desarrollo.
