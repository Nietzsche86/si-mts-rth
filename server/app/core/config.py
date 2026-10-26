import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "MTs Roudhotut Thowalib Local Server"
    VERSION: str = "1.5.0"
    API_V1_STR: str = "/api/v1"
    
    # Keamanan & JWT
    SECRET_KEY: str = os.getenv("SECRET_KEY", "mts-roudhotut-thowalib-secret-key-super-secure-2026")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 hari untuk lingkungan lokal operator
    
    # Enkripsi Kolom Sensitif (AES-256-GCM) & Hashing (HMAC-SHA256)
    AES_MASTER_KEY_HEX: str = os.getenv(
        "AES_MASTER_KEY_HEX",
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    )
    HMAC_SECRET_HEX: str = os.getenv(
        "HMAC_SECRET_HEX",
        "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
    )
    
    # Database SQLite WAL
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./madrasah.db")
    
    # Berkas & Penyimpanan Privat
    STORAGE_DIR: str = os.getenv("STORAGE_DIR", "./storage/berkas")
    
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True)

settings = Settings()
