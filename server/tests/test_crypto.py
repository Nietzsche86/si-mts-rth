from app.core.security import (
    encrypt_sensitive_field,
    decrypt_sensitive_field,
    compute_duplicate_hash,
    verify_password,
    get_password_hash
)

def test_aes_256_gcm_encryption_roundtrip():
    original_nik = "3201123456780001"
    encrypted = encrypt_sensitive_field(original_nik)
    assert encrypted is not None
    assert encrypted != original_nik
    
    decrypted = decrypt_sensitive_field(encrypted)
    assert decrypted == original_nik

def test_hmac_sha256_duplicate_hash():
    nik1 = "3201123456780001"
    nik2 = "3201123456780001"
    nik3 = "3201123456780002"
    
    hash1 = compute_duplicate_hash(nik1)
    hash2 = compute_duplicate_hash(nik2)
    hash3 = compute_duplicate_hash(nik3)
    
    assert hash1 is not None
    assert hash1 == hash2
    assert hash1 != hash3

def test_password_hash():
    pin = "123456"
    hashed = get_password_hash(pin)
    assert verify_password(pin, hashed) is True
    assert verify_password("654321", hashed) is False
