import pyodbc

from .config import get_settings


def quoted(value: str) -> str:
    return '{' + value.replace('}', '}}') + '}'


def connect(database: str | None = None):
    s = get_settings()
    values = {'DRIVER': s.sql_driver, 'SERVER': s.sql_server,
              'DATABASE': database or s.sql_database, 'Encrypt': s.sql_encrypt,
              'TrustServerCertificate': s.sql_trust_certificate}
    if s.sql_auth.lower() == 'windows':
        values['Trusted_Connection'] = 'yes'
    elif s.sql_auth.lower() == 'sql':
        if not s.sql_user or not s.sql_password:
            raise ValueError('SQL_USER y SQL_PASSWORD son obligatorios para SQL_AUTH=sql')
        values.update(UID=s.sql_user, PWD=s.sql_password)
    else:
        raise ValueError('SQL_AUTH debe ser windows o sql')
    return pyodbc.connect(';'.join(k + '=' + quoted(v) for k, v in values.items()),
                          autocommit=True, timeout=10)
