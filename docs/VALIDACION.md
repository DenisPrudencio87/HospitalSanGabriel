# Evidencias de validación

Entorno comprobado: Windows, Node 24.21.0, npm 11.19.0, Python 3.14.8, ODBC 18 y SQL Server 2025 Express con autenticación Windows.

## Resultados observados durante el desarrollo

- Creación desde cero de `HospitalSanGabriel`, con catálogos y demostración: 0,52 s de ejecución SQL; verificación correcta.
- FastAPI: salud 200, OpenAPI 200 y acceso a productos sin sesión 401.
- Nueve pruebas de integración aprobadas en 3,69 s, en una base nueva separada.
- Pruebas: login, catálogos, edición/búsqueda, duplicados, validaciones, entradas/salidas, reenvío idempotente, FEFO, bloqueo de vencidos, concurrencia, rollback forzado, historial tras desactivar, stock disponible bajo y rechazo de inicialización sobre base existente.
- Angular: compilación de producción correcta sin advertencias y una prueba de Signal Forms aprobada.
- Chrome con Playwright: dos pruebas aprobadas en 3,4 s. Recorrido real login, producto, entrada, rechazo de salida excesiva, salida válida, filtro de historial y dashboard; vista móvil de 360 px sin desbordamiento horizontal del documento.
- La comprobación en navegador detectó y permitió corregir textos dañados por codificación y el envío de filtros mediante `submit` de Signal Forms.
- La prueba adicional del rol `hsg_app` confirmó ejecución de procedimientos y rechazo de lectura directa de tablas y creación de usuarios.

## Portabilidad

Los scripts reconstruyen SQL sin `.bak`, usan configuración externa y resuelven rutas desde el repositorio. Dependencias fijadas en `requirements.txt` y `package-lock.json`.

## Instalación limpia ejecutada

Se clonó desde GitHub la rama de validación, commit `3914e93186ff2d4501757d8607c39b0d0a2dfc40`, en una ruta nueva con espacios. Se crearon `.venv`, `node_modules`, configuración JWT y base SQL nuevos. No se copiaron `.env` ni dependencias de desarrollo. El usuario inicial se creó con la utilidad real, con contraseña aleatoria suministrada únicamente al proceso de prueba. El navegador inició sesión con ese usuario y completó los movimientos.

| Etapa | Segundos medidos |
|---|---:|
| Clonar GitHub | 1,28 |
| Crear entorno virtual | 6,97 |
| Instalar dependencias Python fijadas | 14,18 |
| `npm ci` | 10,66 |
| Inicializar y verificar SQL con demostración | 1,72 |
| Crear usuario inicial | 1,02 |
| Compilar producción Angular | 5,50 |
| Arrancar con `start.ps1` y esperar disponibilidad | 9,06 |
| Pruebas Chrome de escritorio y móvil | 7,79 |
| **Total, incluido control de versión** | **58,24** |

Resultado: compilación correcta, salud HTTP correcta y las dos pruebas de navegador aprobadas. El recorrido incluye rechazo de stock insuficiente y filtrado efectivo del historial. Los procesos de esta prueba se detuvieron al finalizar; las bases nuevas se conservaron y no se eliminó ninguna base existente.

Límites: misma computadora Windows, dependencias independientes y perfiles Chrome nuevos; pudieron utilizarse cachés de descarga. No es una prueba en máquina virtual ni en la PC universitaria. El tiempo excluye instalar prerrequisitos, esperar permisos del administrador y escribir manualmente configuración/contraseñas. El objetivo de 20 minutos es viable en este entorno medido; no se garantiza con otras versiones, red o permisos.

El primer ensayo limpio detectó una selección de filtro que podía revertirse al enviar inmediatamente. Se añadió sincronización explícita del evento nativo sobre el modelo Signal Forms y se repitió el proceso completo desde otro clon nuevo; la tabla corresponde al segundo ensayo exitoso. La versión final integra el mismo código ejecutable y actualiza esta documentación.
