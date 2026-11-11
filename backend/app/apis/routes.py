from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.schemas.models import CategoryInput, Login, MovementInput, ProductInput
from app.services import inventory as service

router = APIRouter(prefix='/api/v1')
bearer = HTTPBearer(auto_error=False)


def current_user(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
    if not credentials:
        raise HTTPException(401, 'Inicie sesión')
    return service.authenticate(credentials.credentials)


User = Annotated[dict, Depends(current_user)]


@router.post('/auth/login')
def login(data: Login):
    return service.login(data)


@router.get('/auth/me')
def me(user: User):
    return user


@router.get('/health')
def health():
    return service.health()


@router.get('/catalogs/{kind}')
def catalogs(kind: Literal['categories', 'units', 'areas', 'reasons'], user: User):
    return service.catalogs(kind)


@router.post('/categories', status_code=201)
def create_category(data: CategoryInput, user: User):
    return service.create_category(data)


@router.get('/products')
def products(user: User, search: str = '', category_id: int | None = None, active: bool | None = None,
             page: int = Query(1, ge=1), page_size: int = Query(50, ge=1, le=200)):
    return service.list_products(search=search, category_id=category_id, active=active,
                     page=page, page_size=page_size)


@router.get('/products/{product_id}')
def product(product_id: int, user: User):
    return service.product(product_id)


@router.post('/products', status_code=201)
def create_product(data: ProductInput, user: User):
    return service.save_product(data)


@router.put('/products/{product_id}')
def update_product(product_id: int, data: ProductInput, user: User):
    return service.save_product(data, product_id)


@router.patch('/products/{product_id}/deactivate')
def deactivate(product_id: int, user: User):
    return service.deactivate(product_id)


@router.get('/products/{product_id}/lots')
def lots(product_id: int, user: User):
    return service.lots(product_id)


@router.post('/entries', status_code=201)
def entry(data: MovementInput, user: User):
    return service.movement(data, 'ENTRY', user['id'])


@router.post('/exits', status_code=201)
def exit_stock(data: MovementInput, user: User):
    return service.movement(data, 'EXIT', user['id'])


@router.get('/movements')
def movements(user: User, product_id: int | None = None, kind: Literal['ENTRY', 'EXIT'] | None = None,
              area_id: int | None = None, date_from: date | None = None, date_to: date | None = None,
              page: int = Query(1, ge=1), page_size: int = Query(50, ge=1, le=200)):
    return service.list_movements(product_id=product_id, kind=kind, area_id=area_id,
                     date_from=date_from, date_to=date_to, page=page, page_size=page_size)


@router.get('/dashboard')
def dashboard(user: User, date_from: date | None = None, date_to: date | None = None):
    return service.dashboard(date_from, date_to)
