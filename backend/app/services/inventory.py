from datetime import datetime, timedelta, timezone

import jwt
from fastapi import HTTPException
from pwdlib import PasswordHash

from app.core.config import get_settings
from app.repositories import inventory as repo
from app.schemas.models import Login, MovementInput, ProductInput

passwords = PasswordHash.recommended()
DUMMY_HASH = passwords.hash('timing-protection-not-a-user-password')


def login(data: Login):
    found = repo.rows('usp_User_Get', username=data.username)
    user = found[0] if found else None
    valid = passwords.verify(data.password, user['password_hash'] if user and user['active'] else DUMMY_HASH)
    if not user or not valid or not user['active']:
        raise HTTPException(401, 'Usuario o contraseña incorrectos')
    s = get_settings()
    if len(s.jwt_secret) < 32:
        raise HTTPException(503, 'Configure JWT_SECRET mediante setup-db.ps1')
    token = jwt.encode({'sub': user['username'], 'uid': user['id'],
                        'exp': datetime.now(timezone.utc) + timedelta(minutes=s.jwt_minutes)},
                       s.jwt_secret, algorithm='HS256')
    return {'access_token': token, 'token_type': 'bearer', 'username': user['username']}


def authenticate(token: str):
    try:
        s = get_settings()
        if len(s.jwt_secret) < 32:
            raise ValueError('Missing secret')
        payload = jwt.decode(token, s.jwt_secret, algorithms=['HS256'], options={'require': ['sub', 'uid', 'exp']})
        found = repo.rows('usp_User_Get', username=payload['sub'])
        if not found or not found[0]['active'] or found[0]['id'] != payload['uid']:
            raise ValueError('Inactive user')
        return {'id': found[0]['id'], 'username': found[0]['username']}
    except (jwt.PyJWTError, ValueError, KeyError):
        raise HTTPException(401, 'Sesión inválida o vencida') from None


def product(product_id: int):
    found = repo.rows('usp_Product_List', id=product_id)
    if not found:
        raise HTTPException(404, 'Producto no encontrado')
    return found[0]


def save_product(data: ProductInput, product_id: int | None = None):
    result = repo.rows('usp_Product_Save', id=product_id, **data.model_dump())
    return product(result[0]['id'])


def movement(data: MovementInput, kind: str, user_id: int):
    if kind == 'ENTRY' and (data.entry_reason_id is None or data.area_id is not None or not data.lot_code):
        raise HTTPException(422, 'Entrada requiere motivo controlado y lote; no admite área')
    if kind == 'EXIT' and (data.area_id is None or data.entry_reason_id is not None or data.lot_code is not None or data.expiry is not None):
        raise HTTPException(422, 'Salida requiere área; los lotes se asignan mediante FEFO')
    result = repo.rows('usp_Movement_Register', **data.model_dump(), kind=kind, user_id=user_id)
    return repo.rows('usp_Movement_List', id=result[0]['id'])[0]


def dashboard(date_from=None, date_to=None):
    if date_from and date_to and date_from > date_to:
        raise HTTPException(422, 'Rango de fechas inválido')
    sets = repo.execute('usp_Dashboard', days=get_settings().expiry_days, date_from=date_from, date_to=date_to)
    return dict(zip(['summary', 'low_stock', 'expiry', 'movements', 'top_exits'],
                    [sets[0][0], *sets[1:]]))


def health():
    result = repo.rows('usp_Health')[0]
    if result['inconsistencies']:
        raise HTTPException(503, 'Inconsistencia en inventario')
    return {'status': 'ok'}


def catalogs(kind):
    return repo.rows('usp_Catalog_List', kind=kind)


def create_category(data):
    return repo.rows('usp_Category_Create', **data.model_dump())[0]


def list_products(**filters):
    return repo.rows('usp_Product_List', **filters)


def deactivate(product_id):
    return repo.rows('usp_Product_Deactivate', id=product_id)[0]


def lots(product_id):
    product(product_id)
    return repo.rows('usp_Lot_List', product_id=product_id)


def list_movements(**filters):
    start, end = filters.get('date_from'), filters.get('date_to')
    if start and end and start > end:
        raise HTTPException(422, 'Rango de fechas inválido')
    return repo.rows('usp_Movement_List', **filters)
