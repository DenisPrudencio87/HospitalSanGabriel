from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / '.env', env_file_encoding='utf-8', extra='ignore')
    sql_server: str = r'localhost\SQLEXPRESS'
    sql_database: str = 'HospitalSanGabriel'
    sql_driver: str = 'ODBC Driver 18 for SQL Server'
    sql_auth: str = 'windows'
    sql_user: str = ''
    sql_password: str = ''
    sql_encrypt: str = 'yes'
    sql_trust_certificate: str = 'yes'
    jwt_secret: str = ''
    jwt_minutes: int = 60
    expiry_days: int = 30
    api_port: int = 8000


@lru_cache
def get_settings() -> Settings:
    return Settings()
