import base64
import os
import hmac
import hashlib
from typing import Optional, Union, Any
from datetime import datetime, timedelta, timezone
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from passlib.context import CryptContext
from jose import jwt, JWTError

from app.core.config import settings

# Password/PIN Context
pwd_context = CryptContext(schemes=["argon2", "bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

hash_pin = get_password_hash

def create_access_token(subject: Union[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject)}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

# ==============================================================================
# Enkripsi AES-256-GCM & HMAC-SHA256 sesuai CLAUDE.md Bagian 7
# Format enkripsi: base64(nonce_12_bytes + ciphertext + tag_16_bytes)
# ==============================================================================

def get_aes_key() -> bytes:
    key_bytes = bytes.fromhex(settings.AES_MASTER_KEY_HEX)
    if len(key_bytes) != 32:
        raise ValueError("AES Master Key harus tepat 32 bytes (256-bit)")
    return key_bytes

def encrypt_sensitive_field(plaintext: Optional[str]) -> Optional[str]:
    """Mengenkripsi nilai sensitif dengan AES-256-GCM."""
    if plaintext is None or plaintext == "":
        return None
    key = get_aes_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)  # 12 bytes nonce standar NIST SP 800-38D
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    # ciphertext dari AESGCM.encrypt sudah menyertakan auth tag 16-byte di ujung
    combined = nonce + ciphertext
    return base64.b64encode(combined).decode("utf-8")

def decrypt_sensitive_field(encrypted_b64: Optional[str]) -> Optional[str]:
    """Mendekripsi data AES-256-GCM berformat base64(nonce_12 + ciphertext_and_tag)."""
    if not encrypted_b64:
        return None
    try:
        combined = base64.b64decode(encrypted_b64.encode("utf-8"))
        if len(combined) < 28:  # 12 nonce + 16 tag minimal
            return None
        nonce = combined[:12]
        ciphertext = combined[12:]
        key = get_aes_key()
        aesgcm = AESGCM(key)
        decrypted = aesgcm.decrypt(nonce, ciphertext, None)
        return decrypted.decode("utf-8")
    except Exception:
        return None

def compute_duplicate_hash(value: Optional[str]) -> Optional[str]:
    """Menghitung HMAC-SHA256 untuk deteksi duplikat NIK/KK di server."""
    if value is None or value.strip() == "":
        return None
    key = bytes.fromhex(settings.HMAC_SECRET_HEX)
    clean_val = value.strip()
    return hmac.new(key, clean_val.encode("utf-8"), hashlib.sha256).hexdigest()

# ==============================================================================
# Enkripsi & Dekripsi Berkas / Binary (AES-256-GCM) & KDF Password Backup
# Format berkas terenkripsi: nonce_12 + ciphertext + tag_16
# ==============================================================================

def encrypt_bytes_aes_gcm(data: bytes, key: Optional[bytes] = None) -> bytes:
    """Mengenkripsi binary bytes dengan AES-256-GCM."""
    if key is None:
        key = get_aes_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, data, None)
    return nonce + ciphertext

def decrypt_bytes_aes_gcm(encrypted_data: bytes, key: Optional[bytes] = None) -> bytes:
    """Mendekripsi binary bytes berformat nonce_12 + ciphertext + tag_16."""
    if key is None:
        key = get_aes_key()
    if len(encrypted_data) < 28:
        raise ValueError("Data terenkripsi tidak valid atau terlalu pendek (< 28 bytes)")
    nonce = encrypted_data[:12]
    ciphertext = encrypted_data[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None)

def derive_key_from_password(password: str, salt: bytes, iterations: int = 100_000) -> bytes:
    """Menurunkan kunci AES 256-bit (32 bytes) dari password dan salt via PBKDF2-HMAC-SHA256."""
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=salt,
        iterations=iterations,
    )
    return kdf.derive(password.encode("utf-8"))

