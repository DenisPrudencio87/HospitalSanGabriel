"""Integration tests create a NEW SQL database and never delete existing databases."""
import os
from pathlib import Path
import secrets
import subprocess
import sys
from uuid import uuid4

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ['SQL_DATABASE'] = 'HSG_Test_' + uuid4().hex[:12]


@pytest.fixture(scope='session', autouse=True)
def database():
    result = subprocess.run([sys.executable, str(ROOT / 'backend/tools/manage.py'), 'setup', '--demo'],
                            cwd=ROOT, text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    print(result.stdout)
    yield os.environ['SQL_DATABASE']
    print('Base de pruebas conservada:', os.environ['SQL_DATABASE'])


@pytest.fixture(scope='session')
def client(database):
    from fastapi.testclient import TestClient
    from app.main import app
    from app.repositories.inventory import rows
    from app.services.inventory import passwords
    password = secrets.token_urlsafe(24)
    rows('usp_User_Create', username='test-operator', password_hash=passwords.hash(password))
    with TestClient(app) as c:
        response = c.post('/api/v1/auth/login', json={'username': 'test-operator', 'password': password})
        assert response.status_code == 200, response.text
        c.headers['Authorization'] = 'Bearer ' + response.json()['access_token']
        yield c
