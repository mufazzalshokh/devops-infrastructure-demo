"""
Application configuration using pydantic-settings.
All values can be overridden via environment variables or .env file.
"""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Application
    app_name: str = "DevOps Infrastructure Demo"
    app_version: str = "1.0.0"
    app_env: str = "development"
    debug: bool = False

    # Server
    host: str = "0.0.0.0"
    port: int = 8000

    # Security
    api_key: str = "dev-secret-key-change-in-production"

    # Feature flags
    enable_metrics: bool = True

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """
    Cached settings instance.
    lru_cache means this is only created once per process — efficient.
    """
    return Settings()