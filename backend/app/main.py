import logging

import pyodbc
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.apis.routes import router

app = FastAPI(title='Hospital San Gabriel', version='1.0.0',
              description='Inventario por lotes. Todas las operaciones de negocio utilizan procedimientos almacenados.')
app.include_router(router)


@app.exception_handler(pyodbc.Error)
def database_error(request: Request, exc: pyodbc.Error):
    message = str(exc)
    if '50004' in message:
        status, detail = 404, 'Recurso no encontrado'
    elif any(code in message for code in ['2601', '2627']):
        status, detail = 409, 'Código, nombre o solicitud duplicados'
    elif '50009' in message:
        status, detail = 409, 'Conflicto: stock insuficiente, lote vencido, producto inactivo o datos incompatibles con el historial'
    elif any(code in message for code in ['50001', '547', '8115']):
        status, detail = 422, 'Datos inválidos: revise referencias, lote, vencimiento y cantidades'
    elif message.startswith("('08") or 'HYT' in message:
        status, detail = 503, 'SQL Server no disponible; revise conexión y configuración'
    else:
        logging.getLogger(__name__).error('Database operation failed: %s', exc.args[0] if exc.args else 'unknown')
        status, detail = 500, 'Error de base de datos; consulte al administrador'
    return JSONResponse(status_code=status, content={'detail': detail})
