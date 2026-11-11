"""Local provisioning only. Runtime repositories never execute direct table SQL."""
import argparse
from contextlib import closing
from getpass import getpass
from pathlib import Path
import re
import secrets
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app.core.config import ROOT, get_settings
from app.core.database import connect
from app.repositories.inventory import PROCEDURES, rows
from app.services.inventory import passwords


def batches(connection, path):
    for batch in re.split(r'^\s*GO\s*$', path.read_text(encoding='utf-8'), flags=re.M | re.I):
        if batch.strip():
            cursor = connection.cursor()
            cursor.execute(batch)
            while cursor.nextset():
                pass
            cursor.close()


def configure():
    path = ROOT / '.env'
    if not path.exists():
        example = (ROOT / '.env.example').read_text(encoding='utf-8')
        path.write_text(example.replace('JWT_SECRET=\n', 'JWT_SECRET=' + secrets.token_urlsafe(48) + '\n'), encoding='utf-8')
    get_settings.cache_clear()
    if len(get_settings().jwt_secret) < 32:
        raise ValueError('Configure JWT_SECRET con al menos 32 caracteres en .env')


def setup(args):
    started = time.perf_counter()
    configure()
    s = get_settings()
    if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,99}', s.sql_database):
        raise ValueError('Nombre de base: letras, numeros y guion bajo; comenzar por letra')
    if s.sql_database.lower() in {'master', 'model', 'msdb', 'tempdb'}:
        raise ValueError('Base de sistema prohibida')
    with closing(connect('master')) as connection:
        version = connection.execute("SELECT CAST(SERVERPROPERTY('ProductMajorVersion') AS int)").fetchone()[0]
        if version < 13:
            raise ValueError('Se requiere SQL Server 2016 o posterior (JSON y paginacion)')
        exists = connection.execute('SELECT DB_ID(?)', s.sql_database).fetchone()[0] is not None
        if exists and not args.existing_empty:
            raise ValueError('La base ya existe. No se sobrescribira. Use otro nombre o --existing-empty solo para una base vacia dedicada')
        if not exists and args.existing_empty:
            raise ValueError('La modalidad existing-empty requiere una base existente vacia')
        if not exists:
            create_sql = (ROOT / 'database/00-create-database.sql').read_text(encoding='utf-8')
            connection.execute(create_sql.replace('__DATABASE_NAME__', s.sql_database))
    with closing(connect()) as connection:
        count = connection.execute("SELECT COUNT(*) FROM sys.objects WHERE is_ms_shipped=0 AND type IN ('U','P','V','FN','IF','TF','TR','SO','SN')").fetchone()[0]
        if count:
            raise ValueError('Destino no vacio. Inicializacion detenida sin borrar objetos')
        files = ['01-schema.sql', '02-procedures.sql', '03-catalogs.sql']
        if args.demo:
            files.append('04-demo.sql')
        files.append('05-verify.sql')
        for name in files:
            print('Ejecutando', name, flush=True)
            batches(connection, ROOT / 'database' / name)
        found = {r[0] for r in connection.execute("SELECT name FROM sys.procedures WHERE schema_id=SCHEMA_ID('dbo')")}
        if not PROCEDURES <= found:
            raise ValueError('Faltan procedimientos: ' + ', '.join(PROCEDURES - found))
    print(f'Base {s.sql_database} verificada. Duracion SQL: {time.perf_counter()-started:.2f} s')


def create_user(args):
    username = args.username or input('Usuario inicial: ').strip()
    if not username or len(username) > 80:
        raise ValueError('Usuario invalido')
    if rows('usp_User_Get', username=username):
        raise ValueError('El usuario ya existe; no se modificara')
    password = getpass('Contrasena (minimo 10 caracteres): ')
    if len(password) < 10 or password != getpass('Repita contrasena: '):
        raise ValueError('Contrasenas distintas o demasiado cortas')
    rows('usp_User_Create', username=username, password_hash=passwords.hash(password))
    print('Usuario creado; no se almaceno la contrasena en archivos')


def check():
    import pyodbc
    print('Python:', sys.version.split()[0])
    print('ODBC:', ', '.join(pyodbc.drivers()))
    with closing(connect('master')) as c:
        row = c.execute("SELECT SERVERPROPERTY('ProductVersion'), SERVERPROPERTY('Edition'), HAS_PERMS_BY_NAME(NULL,NULL,'CREATE ANY DATABASE')").fetchone()
        print('SQL version / edicion / puede crear base:', *row)
    print('Conexion correcta. No se modificaron bases de datos.')


parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest='command', required=True)
sp = sub.add_parser('setup')
sp.add_argument('--demo', action='store_true')
sp.add_argument('--existing-empty', action='store_true')
up = sub.add_parser('create-user')
up.add_argument('--username')
sub.add_parser('check')
args = parser.parse_args()
try:
    if args.command == 'setup':
        setup(args)
    elif args.command == 'create-user':
        create_user(args)
    else:
        check()
except Exception as exc:
    # Connection strings and passwords are never printed.
    if exc.__class__.__module__.startswith('pyodbc'):
        print('ERROR SQL. Revise conexion, permisos o script de la etapa indicada. SQLSTATE:', exc.args[0] if exc.args else '?', file=sys.stderr)
    else:
        print('ERROR:', str(exc), file=sys.stderr)
    sys.exit(1)
