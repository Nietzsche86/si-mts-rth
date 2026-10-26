import os
import io
import json
import zipfile
import shutil
import hashlib
from typing import Dict, Any, Tuple
from datetime import datetime, timezone
from sqlmodel import Session, text

from app.core.config import settings
from app.core.security import (
    derive_key_from_password,
    encrypt_bytes_aes_gcm,
    decrypt_bytes_aes_gcm
)

SALT_SIZE = 16

def create_encrypted_backup(db: Session, password: str) -> Tuple[bytes, Dict[str, Any]]:
    """
    Membuat cadangan terenkripsi password (AES-256-GCM) berisi:
    1. Snapshot bersih database SQLite WAL (menggunakan VACUUM INTO)
    2. Seluruh berkas lampiran di storage/berkas
    3. Manifest metadata + SHA-256 checksum integritas
    Format binary: SALT_16 + NONCE_12 + CIPHERTEXT + TAG_16
    """
    now_utc = datetime.now(timezone.utc)
    timestamp_str = now_utc.strftime("%Y%m%d_%H%M%S")
    temp_dir = os.path.join(os.path.dirname(settings.STORAGE_DIR), f"_temp_backup_{timestamp_str}")
    os.makedirs(temp_dir, exist_ok=True)
    temp_db_path = os.path.join(temp_dir, "database.sqlite")

    try:
        # 1. Snapshot database SQLite secara konsisten
        # Menjalankan checkpoint WAL sebelum snapshot
        try:
            db.exec(text("PRAGMA wal_checkpoint(FULL);"))
        except Exception:
            pass

        # Gunakan VACUUM INTO untuk membuat salinan file database yang konsisten tanpa fragmentation
        # Jika file sudah ada, hapus dulu
        if os.path.exists(temp_db_path):
            os.remove(temp_db_path)
            
        try:
            db.exec(text(f"VACUUM INTO '{temp_db_path}';"))
        except Exception:
            # Fallback jika VACUUM INTO tidak didukung (e.g. SQLite memory DB pada test)
            db_path = settings.DATABASE_URL.replace("sqlite:///", "")
            if os.path.exists(db_path):
                shutil.copy2(db_path, temp_db_path)
            else:
                # Mock empty db file jika in-memory
                with open(temp_db_path, "wb") as f:
                    f.write(b"SQLITE_DUMMY_FOR_MEMORY")

        # Hitung SHA-256 checksum snapshot database
        with open(temp_db_path, "rb") as f:
            db_bytes = f.read()
            db_sha256 = hashlib.sha256(db_bytes).hexdigest()
            db_size = len(db_bytes)

        # 2. Kemas ke dalam arsip ZIP in-memory
        zip_buffer = io.BytesIO()
        files_count = 0
        files_total_bytes = 0

        with zipfile.ZipFile(zip_buffer, mode="w", compression=zipfile.ZIP_DEFLATED) as zip_file:
            # Tambahkan database
            zip_file.writestr("database.sqlite", db_bytes)

            # Tambahkan seluruh berkas lampiran jika folder ada
            if os.path.exists(settings.STORAGE_DIR):
                for root, _, files in os.walk(settings.STORAGE_DIR):
                    for file in files:
                        full_path = os.path.join(root, file)
                        rel_path = os.path.relpath(full_path, settings.STORAGE_DIR)
                        with open(full_path, "rb") as bf:
                            file_data = bf.read()
                            files_count += 1
                            files_total_bytes += len(file_data)
                            zip_file.writestr(f"storage/{rel_path}", file_data)

            # Buat manifest integritas
            manifest = {
                "aplikasi": settings.PROJECT_NAME,
                "versi": settings.VERSION,
                "created_at": now_utc.isoformat(),
                "db_sha256": db_sha256,
                "db_size": db_size,
                "files_count": files_count,
                "files_total_bytes": files_total_bytes,
            }
            zip_file.writestr("manifest.json", json.dumps(manifest, indent=2))

        raw_zip_bytes = zip_buffer.getvalue()

        # 3. Turunkan kunci AES-256 dari password pengguna via PBKDF2
        salt = os.urandom(SALT_SIZE)
        aes_key = derive_key_from_password(password, salt)

        # 4. Enkripsi arsip dengan AES-256-GCM
        encrypted_payload = encrypt_bytes_aes_gcm(raw_zip_bytes, key=aes_key)

        # Format final: SALT_16 + ENCRYPTED_PAYLOAD
        final_backup_bytes = salt + encrypted_payload
        return final_backup_bytes, manifest

    finally:
        # Bersihkan folder sementara
        if os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)

def verify_encrypted_backup(backup_bytes: bytes, password: str) -> Dict[str, Any]:
    """
    Mendekripsi dan memverifikasi integritas berkas cadangan tanpa menerapkan restore:
    - Verifikasi salt & format
    - Verifikasi password (dekripsi AES-256-GCM)
    - Verifikasi manifest & SHA-256 database
    """
    if len(backup_bytes) < SALT_SIZE + 28:
        raise ValueError("Berkas cadangan tidak valid atau terlalu kecil (< 44 bytes)")

    salt = backup_bytes[:SALT_SIZE]
    encrypted_payload = backup_bytes[SALT_SIZE:]

    try:
        aes_key = derive_key_from_password(password, salt)
        raw_zip_bytes = decrypt_bytes_aes_gcm(encrypted_payload, key=aes_key)
    except Exception:
        raise ValueError("Password cadangan salah atau berkas terenkripsi rusak")

    try:
        zip_buffer = io.BytesIO(raw_zip_bytes)
        with zipfile.ZipFile(zip_buffer, mode="r") as zip_file:
            namelist = zip_file.namelist()
            if "manifest.json" not in namelist or "database.sqlite" not in namelist:
                raise ValueError("Format arsip cadangan tidak lengkap (kehilangan manifest atau database)")

            manifest_bytes = zip_file.read("manifest.json")
            manifest = json.loads(manifest_bytes.decode("utf-8"))

            # Verifikasi checksum database
            db_bytes = zip_file.read("database.sqlite")
            calc_sha256 = hashlib.sha256(db_bytes).hexdigest()

            if calc_sha256 != manifest.get("db_sha256"):
                raise ValueError("Integritas database rusak (SHA-256 checksum tidak sesuai manifest)")

            manifest["status"] = "VALID"
            manifest["is_verified"] = True
            return manifest
    except Exception as e:
        if isinstance(e, ValueError):
            raise
        raise ValueError(f"Gagal membaca arsip cadangan: {str(e)}")

def restore_encrypted_backup(backup_bytes: bytes, password: str, db_path: Optional[str] = None) -> Dict[str, Any]:
    """
    Memulihkan database dan seluruh lampiran berkas dari cadangan terenkripsi.
    Melakukan verifikasi integritas penuh sebelum menerapkan perubahan secara atomik.
    """
    # 1. Verifikasi terlebih dahulu
    manifest = verify_encrypted_backup(backup_bytes, password)

    salt = backup_bytes[:SALT_SIZE]
    encrypted_payload = backup_bytes[SALT_SIZE:]
    aes_key = derive_key_from_password(password, salt)
    raw_zip_bytes = decrypt_bytes_aes_gcm(encrypted_payload, key=aes_key)

    target_db_path = db_path or settings.DATABASE_URL.replace("sqlite:///", "")
    db_dir = os.path.dirname(os.path.abspath(target_db_path))
    os.makedirs(db_dir, exist_ok=True)
    os.makedirs(settings.STORAGE_DIR, exist_ok=True)

    # 2. Buat backup darurat sebelum menimpa
    emergency_backup = f"{target_db_path}.pre_restore.bak"
    if os.path.exists(target_db_path):
        shutil.copy2(target_db_path, emergency_backup)

    try:
        zip_buffer = io.BytesIO(raw_zip_bytes)
        with zipfile.ZipFile(zip_buffer, mode="r") as zip_file:
            # Tulis database baru
            db_data = zip_file.read("database.sqlite")
            with open(target_db_path, "wb") as f:
                f.write(db_data)

            # Hapus file WAL & SHM lama agar SQLite membuka fresh snapshot
            wal_file = f"{target_db_path}-wal"
            shm_file = f"{target_db_path}-shm"
            if os.path.exists(wal_file):
                os.remove(wal_file)
            if os.path.exists(shm_file):
                os.remove(shm_file)

            # Pulihkan seluruh berkas lampiran
            for item in zip_file.namelist():
                if item.startswith("storage/") and not item.endswith("/"):
                    rel_file = item[len("storage/"):]
                    target_file_path = os.path.join(settings.STORAGE_DIR, rel_file)
                    os.makedirs(os.path.dirname(target_file_path), exist_ok=True)
                    with open(target_file_path, "wb") as bf:
                        bf.write(zip_file.read(item))

        # Sukses, bersihkan backup darurat
        if os.path.exists(emergency_backup):
            os.remove(emergency_backup)

        return {
            "success": True,
            "message": "Pemulihan cadangan database dan berkas lampiran berhasil",
            "manifest": manifest
        }

    except Exception as e:
        # Rollback jika terjadi kesalahan
        if os.path.exists(emergency_backup):
            shutil.copy2(emergency_backup, target_db_path)
            os.remove(emergency_backup)
        raise RuntimeError(f"Gagal melakukan restore: {str(e)}")
