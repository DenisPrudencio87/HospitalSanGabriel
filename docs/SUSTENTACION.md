# Guion de sustentación

## Recorrido de demostración

1. Login con usuario creado localmente; explicar que SQL almacena un hash Argon2 y el backend entrega un JWT con vencimiento.
2. Registrar categoría y producto. El stock inicial es cero: no se escribe desde el formulario de productos.
3. Registrar entrada de 10 unidades con lote y vencimiento. Mostrar el saldo y el historial.
4. Intentar salida de 11: se rechaza. Registrar salida de 3: quedan 7.
5. Mostrar historial filtrado por producto: entrada y salida, saldos y lote.
6. Abrir dashboard: indicadores actualizados desde SQL, stock disponible bajo y lotes vencidos.
7. Desactivar el producto y consultar su historial: no se elimina información.

## Explicar las cuatro capas

- APIs: rutas HTTP, autenticación por dependencia y códigos de respuesta.
- Schemas: tipos, longitudes, enteros estrictos, precios y fechas válidas.
- Services: casos de uso, validaciones de entrada/salida y autenticación.
- Repositories: lista cerrada de procedimientos y parámetros; no hay consultas directas a tablas.

Ejemplo: `POST /api/v1/exits` pasa por `apis/routes.py`, `services/inventory.py`, `repositories/inventory.py` y `usp_Movement_Register`.

## Explicar stock y concurrencia

Un producto tiene varios lotes. Stock físico incluye lotes vencidos; disponible incluye solo lotes vigentes. Stock bajo compara disponible con mínimo.

El procedimiento bloquea el producto con `UPDLOCK,HOLDLOCK`, valida saldo contra la suma de lotes y conserva los bloqueos hasta finalizar. Dos movimientos del mismo producto se serializan. La salida FEFO toma primero los lotes que vencen antes, omitiendo vencidos. Actualiza lotes, recalcula stock del producto e inserta movimiento y detalles dentro de la misma transacción. `XACT_ABORT`, `TRY/CATCH` y rollback evitan registros parciales.

Las pruebas reales muestran que dos salidas de 7 sobre 10 permiten solo una y dejan 3. Un fallo inyectado al registrar detalle revierte todos los cambios y conserva 10.

## Explicar portabilidad y Git

Configuración fuera del código en `.env`, dependencias fijadas y scripts SQL ordenados. `setup-db.ps1` rechaza una base existente y verifica los objetos creados. `start.ps1` comprueba puertos y conexión. La instalación limpia se probó desde GitHub; consultar tiempos y límites en `VALIDACION.md`.

Mostrar los Pull Requests reales de SQL/FastAPI, Angular y validación. Consultar `git log --oneline --graph --all` para explicar cómo se integraron las ramas.

## Límites que deben declararse

Aplicación académica local con un perfil operador, sin gestión de pacientes, usuarios/roles en la interfaz ni edición de movimientos ya registrados. La sesión se mantiene en memoria; recargar obliga a iniciar sesión. SQL Server anterior a 2025 requiere comprobación real aunque los scripts evitan sintaxis exclusiva de esa versión.
