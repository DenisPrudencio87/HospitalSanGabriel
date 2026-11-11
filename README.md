# Hospital San Gabriel

Sistema académico de gestión de inventario: Angular 22 con Signal Forms, FastAPI organizado en APIs, Services, Repositories y Schemas, y Microsoft SQL Server local.

## Estado

Implementación en desarrollo. Las funciones y verificaciones disponibles se documentarán conforme se ejecuten. No se necesitan copias de seguridad `.bak`: la base se reconstruirá con scripts versionados.

## Requisitos

- Windows, Node.js compatible con Angular 22 y npm.
- Python y Microsoft ODBC Driver 18 for SQL Server.
- Instancia SQL Server local accesible; autenticación Windows preferida.

No publicar credenciales. La configuración local se guardará en `.env`, excluido de Git.

## Arquitectura

`frontend/` contiene Angular; `backend/` contiene las cuatro capas; `database/` contiene estructura y procedimientos; `scripts/` contiene diagnóstico, inicialización y arranque.

Toda consulta y escritura de negocio utilizará procedimientos almacenados. Los movimientos actualizarán stock y trazabilidad en una sola transacción.
