from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.core.database import connect
from app.repositories.inventory import rows

TODAY = datetime.now(timezone(timedelta(hours=-5))).date()


def product(client, **changes):
    data = dict(code='T-' + uuid4().hex[:12], name='Producto prueba', description='',
                category_id=1, unit_id=1, price=2.5, min_stock=5, tracks_expiry=True)
    data.update(changes)
    response = client.post('/api/v1/products', json=data)
    assert response.status_code == 201, response.text
    return response.json()


def movement(pid, qty, entry=True, **changes):
    data = dict(request_id=str(uuid4()), product_id=pid, quantity=qty, movement_date=str(TODAY),
                reason='Prueba', entry_reason_id=1 if entry else None, area_id=None if entry else 1,
                lot_code='LOTE' if entry else None, expiry=str(TODAY+timedelta(days=30)) if entry else None)
    data.update(changes)
    return data


def assert_stock(pid, expected):
    p = rows('usp_Product_List', id=pid)[0]
    lots = rows('usp_Lot_List', product_id=pid)
    assert p['stock'] == sum(l['stock'] for l in lots) == expected


def test_authentication(client):
    from fastapi.testclient import TestClient
    from app.main import app
    with TestClient(app) as anonymous:
        assert anonymous.get('/api/v1/products').status_code == 401
        assert anonymous.post('/api/v1/auth/login', json={'username':'missing','password':'wrong'}).status_code == 401
        assert anonymous.post('/api/v1/auth/login', json={'username':'demo-auditoria','password':'wrong'}).status_code == 401
    assert client.get('/api/v1/auth/me').json()['username'] == 'test-operator'
    assert client.get('/openapi.json').status_code == 200


def test_catalogs_crud_and_validation(client):
    r = client.post('/api/v1/categories', json={'name':'Categoría '+uuid4().hex[:8], 'description':'Nueva'})
    assert r.status_code == 201
    category_id=r.json()['id']
    assert any(c['id']==category_id for c in client.get('/api/v1/catalogs/categories').json())
    p=product(client, category_id=category_id)
    same=dict(code=p['code'],name='Duplicado',description='',category_id=1,unit_id=1,price=1,min_stock=0,tracks_expiry=True)
    assert client.post('/api/v1/products',json=same).status_code==409
    assert client.post('/api/v1/products',json={**same,'price':0}).status_code==422
    assert client.post('/api/v1/products',json={**same,'min_stock':1.5}).status_code==422
    same['name']='Actualizado'
    assert client.put(f"/api/v1/products/{p['id']}",json=same).status_code==200
    assert client.get('/api/v1/products',params={'search':p['code'],'category_id':1}).json()[0]['name']=='Actualizado'


def test_entry_exit_idempotency_and_history(client):
    p=product(client);pid=p['id']
    data=movement(pid,10)
    first=client.post('/api/v1/entries',json=data)
    assert first.status_code==201,first.text
    assert client.post('/api/v1/entries',json=data).json()['id']==first.json()['id']
    assert_stock(pid,10)
    out=client.post('/api/v1/exits',json=movement(pid,3,False))
    assert out.status_code==201,out.text
    assert out.json()['lots'][0]['quantity']==3
    assert_stock(pid,7)
    assert client.post('/api/v1/exits',json=movement(pid,8,False)).status_code==409
    assert_stock(pid,7)
    for qty in [0,-1,1.5,True]:
        assert client.post('/api/v1/entries',json=movement(pid,qty)).status_code==422
    assert client.patch(f'/api/v1/products/{pid}/deactivate').status_code==200
    history=client.get('/api/v1/movements',params={'product_id':pid}).json()
    assert len(history)==2
    assert history[0]['stock_before']==10 and history[0]['stock_after']==7
    assert client.post('/api/v1/entries',json=movement(pid,1)).status_code==409


def test_fefo_and_expired_stock(client):
    pid=product(client)['id']
    for code,qty,days in [('FAR',8,100),('NEAR',4,2),('EXPIRED',20,-2)]:
        r=client.post('/api/v1/entries',json=movement(pid,qty,lot_code=code,expiry=str(TODAY+timedelta(days=days))))
        assert r.status_code==201,r.text
    r=client.post('/api/v1/exits',json=movement(pid,6,False))
    assert r.status_code==201,r.text
    quantities={x['lot_code']:x['quantity'] for x in r.json()['lots']}
    assert quantities=={'NEAR':4,'FAR':2}
    assert_stock(pid,26)
    assert client.post('/api/v1/exits',json=movement(pid,7,False)).status_code==409
    p=client.get(f'/api/v1/products/{pid}').json()
    assert p['available_stock']==6 and p['expired_stock']==20


def test_concurrent_exits(client):
    pid=product(client)['id']
    assert client.post('/api/v1/entries',json=movement(pid,10)).status_code==201
    headers=dict(client.headers)
    from fastapi.testclient import TestClient
    from app.main import app
    def withdraw(_):
        with TestClient(app) as c:
            return c.post('/api/v1/exits',headers=headers,json=movement(pid,7,False)).status_code
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert sorted(pool.map(withdraw,range(2)))==[201,409]
    assert_stock(pid,3)
    assert len(rows('usp_Movement_List',product_id=pid))==2


def test_rollback_after_history_failure(client,database):
    assert database.startswith('HSG_Test_')
    pid=product(client)['id']
    assert client.post('/api/v1/entries',json=movement(pid,10)).status_code==201
    # Fault injection is confined to the newly created test database.
    with closing(connect()) as c:
        c.execute("CREATE TRIGGER dbo.TestFailDetail ON dbo.MovementDetail AFTER INSERT AS BEGIN THROW 50009,'Injected test failure',1; END")
    try:
        response=client.post('/api/v1/exits',json=movement(pid,3,False))
        assert response.status_code==409,response.text
        assert_stock(pid,10)
        assert len(rows('usp_Movement_List',product_id=pid))==1
    finally:
        with closing(connect()) as c:
            c.execute('DROP TRIGGER dbo.TestFailDetail')


def test_dashboard_available_stock_and_filters(client):
    pid=product(client,min_stock=5)['id']
    assert client.post('/api/v1/entries',json=movement(pid,20,expiry=str(TODAY-timedelta(days=1)))).status_code==201
    data=client.get('/api/v1/dashboard',params={'date_from':str(TODAY),'date_to':str(TODAY)}).json()
    p=next(p for p in data['low_stock'] if p['id']==pid)
    assert p['stock']==20 and p['available_stock']==0 and p['expired_stock']==20
    assert any(p['id']==pid for p in data['expiry'])
    assert data['movements'] and data['top_exits']
    assert client.get('/api/v1/movements',params={'kind':'EXIT','area_id':1,'date_from':str(TODAY),'date_to':str(TODAY)}).status_code==200


def test_setup_rejects_existing_database(database):
    import subprocess,sys
    from pathlib import Path
    manage=Path(__file__).resolve().parents[1]/'tools/manage.py'
    result=subprocess.run([sys.executable,str(manage),'setup'],capture_output=True,text=True)
    assert result.returncode==1 and 'ya existe' in result.stderr
    assert rows('usp_Health')[0]['inconsistencies']==0


def test_limited_database_role(database):
    from pathlib import Path
    assert database.startswith('HSG_Test_')
    script=Path(__file__).resolve().parents[2]/'database/06-permissions.sql'
    with closing(connect()) as c:
        c.execute(script.read_text(encoding='utf-8'))
        c.execute('CREATE USER hsg_test_limited WITHOUT LOGIN; ALTER ROLE hsg_app ADD MEMBER hsg_test_limited;')
        c.execute("EXECUTE AS USER='hsg_test_limited'")
        try:
            assert c.execute('EXEC dbo.usp_Product_List').fetchone() is not None
            import pyodbc
            with pytest.raises(pyodbc.Error):
                c.execute('SELECT * FROM dbo.Product')
            with pytest.raises(pyodbc.Error):
                c.execute("EXEC dbo.usp_User_Create @username=N'forbidden',@password_hash=N'x'")
        finally:
            c.execute('REVERT')
