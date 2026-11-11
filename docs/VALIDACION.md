# Evidencias de validación

Entorno comprobado: Windows, Node 24.21.0, npm 11.19.0, Python 3.14.8, ODBC 18 y SQL Server 2025 Express con autenticación Windows.

## Resultados observados durante el desarrollo

- Creación desde cero de `HospitalSanGabriel`, con catálogos y demostración: 0,52 s de ejecución SQL; verificación correcta.
- FastAPI: salud 200, OpenAPI 200 y acceso a productos sin sesión 401.
- Ocho pruebas de integración aprobadas en 3,54 s, en una base nueva separada.
- Pruebas: login, catálogos, edición/búsqueda, duplicados, validaciones, entradas/salidas, reenvío idempotente, FEFO, bloqueo de vencidos, concurrencia, rollback forzado, historial tras desactivar, stock disponible bajo y rechazo de inicialización sobre base existente.
- Angular: compilación de producción correcta sin advertencias y una prueba de Signal Forms aprobada.
- Chrome con Playwright: dos pruebas aprobadas en 3,4 s. Recorrido real login, producto, entrada, rechazo de salida excesiva, salida válida, filtro de historial y dashboard; vista móvil de 360 px sin desbordamiento horizontal del documento.
- La comprobación en navegador detectó y permitió corregir textos dañados por codificación y el envío de filtros mediante `submit` de Signal Forms.

## Portabilidad

Los scripts reconstruyen SQL sin `.bak`, usan configuración externa y resuelven rutas desde el repositorio. Dependencias fijadas en `requirements.txt` y `package-lock.json`.

La aceptación completa exige un clon real de GitHub, instalación de dependencias, base nueva, usuario inicial, arranque y recorrido funcional. Se registrarán por separado los tiempos realmente medidos. Un clon en la misma PC no demuestra compatibilidad con otra versión de SQL Server ni con una PC universitaria con permisos distintos.
