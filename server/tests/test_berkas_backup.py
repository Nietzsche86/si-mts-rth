import io
import os
import shutil
import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app.db.seeder import seed_initial_data
from app.core.config import settings
from app.models import (
    User, Siswa, SiswaDetail, SiswaOrtu, Alamat, SiswaSensitif,
    SiswaBerkas, Rombel, KeanggotaanRombel, AuditLog, current_time_epoch_ms
)

def _get_admin_token(client: TestClient) -> str:
    login_resp = client.post("/api/v1/auth/login", json={
        "username": "admin",
        "pin": "123456",
        "device_id": "test-operator-laptop",
        "nama_perangkat": "Laptop Admin"
    })
    assert login_resp.status_code == 200
    return login_resp.json()["access_token"]

def test_berkas_upload_magic_bytes_and_download_decryption(client: TestClient, session: Session):
    """
    Menguji upload berkas dengan validasi magic bytes (JPEG asli),
    penyimpanan terenkripsi AES-256-GCM fisik di storage,
    dan pengunduhan terdekripsi dengan verifikasi SHA-256.
    """
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    # Setup siswa uji
    now = current_time_epoch_ms()
    siswa = Siswa(
        id="siswa-berkas-01",
        nis="9001",
        nama_lengkap="Ahmad Berkas Test",
        jk="L",
        status_aktif="aktif",
        created_at=now,
        updated_at=now,
        device_id="test",
        server_seq=100
    )
    session.add(siswa)
    session.commit()

    # 1. Berkas JPEG valid (magic bytes \xFF\xD8\xFF)
    valid_jpeg = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00" + b"A" * 200

    response = client.post(
        "/api/v1/berkas/upload",
        headers=headers,
        data={
            "siswa_id": siswa.id,
            "jenis_berkas_kode": "FOTO",
            "nama_tampil": "Pasfoto_Ahmad.jpg"
        },
        files={"file": ("foto.jpg", valid_jpeg, "image/jpeg")}
    )
    assert response.status_code == 200, response.text
    res_data = response.json()
    berkas_id = res_data["id"]
    assert res_data["mime_type"] == "image/jpeg"
    assert res_data["ukuran_byte"] == len(valid_jpeg)

    # 2. Verifikasi penyimpanan fisik terenkripsi di server (bukan plaintext)
    storage_path = os.path.join(settings.STORAGE_DIR, f"{berkas_id}.enc")
    assert os.path.exists(storage_path)
    with open(storage_path, "rb") as f:
        encrypted_on_disk = f.read()
    assert encrypted_on_disk != valid_jpeg
    assert len(encrypted_on_disk) >= len(valid_jpeg) + 28  # 12 nonce + 16 tag

    # 3. Unduh berkas terdekripsi
    dl_response = client.get(f"/api/v1/berkas/{berkas_id}/download", headers=headers)
    assert dl_response.status_code == 200
    assert dl_response.content == valid_jpeg
    assert dl_response.headers["content-type"] == "image/jpeg"

    # 4. Verifikasi pencatatan audit log (PRD F5: 'pembukaan tercatat')
    audit = session.exec(
        select(AuditLog).where(
            AuditLog.baris_id == berkas_id,
            AuditLog.aksi == "BUKA_BERKAS"
        )
    ).first()
    assert audit is not None

def test_berkas_rejects_fake_extension_and_oversized(client: TestClient, session: Session):
    """Menguji penolakan berkas palsu (magic bytes bukan JPG/PNG/PDF) atau berkas terlalu besar."""
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    now = current_time_epoch_ms()
    siswa = Siswa(
        id="siswa-berkas-02",
        nis="9002",
        nama_lengkap="Budi Berkas Test",
        jk="L",
        status_aktif="aktif",
        created_at=now,
        updated_at=now,
        device_id="test",
        server_seq=101
    )
    session.add(siswa)
    session.commit()

    # Berkas palsu bernama .jpg tetapi isinya plain text
    fake_jpg = b"Ini bukan JPEG asli tetapi text biasa"
    res1 = client.post(
        "/api/v1/berkas/upload",
        headers=headers,
        data={"siswa_id": siswa.id, "jenis_berkas_kode": "FOTO"},
        files={"file": ("fake.jpg", fake_jpg, "image/jpeg")}
    )
    assert res1.status_code == 400
    assert "Format berkas tidak valid" in res1.json()["detail"]

    # Berkas gambar melebihi batas 1 MB
    large_jpg = b"\xFF\xD8\xFF\xE0" + b"X" * (1024 * 1024 + 100)
    res2 = client.post(
        "/api/v1/berkas/upload",
        headers=headers,
        data={"siswa_id": siswa.id, "jenis_berkas_kode": "FOTO"},
        files={"file": ("large.jpg", large_jpg, "image/jpeg")}
    )
    assert res2.status_code == 400
    assert "melebihi batas 1 MB" in res2.json()["detail"]

def test_emis_csv_export_and_import_commit(client: TestClient, session: Session):
    """Menguji ekspor EMIS ke format CSV dan impor massal commit."""
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    rombel = session.exec(select(Rombel).where(Rombel.deleted == 0)).first()
    assert rombel is not None

    # 1. Download template CSV
    t_res = client.get("/api/v1/emis/template?format=csv", headers=headers)
    assert t_res.status_code == 200
    assert "text/csv" in t_res.headers["content-type"]
    assert "NISN" in t_res.text

    # 2. Export rombel CSV
    e_res = client.get(f"/api/v1/emis/export/{rombel.id}?format=csv", headers=headers)
    assert e_res.status_code == 200
    assert "text/csv" in e_res.headers["content-type"]

    # 3. Import Preview via CSV
    sample_csv = (
        "NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK,TEMPAT LAHIR,TANGGAL LAHIR (YYYY-MM-DD),NAMA IBU,NAMA AYAH,ALAMAT JALAN,DESA/KELURAHAN,KECAMATAN,KABUPATEN/KOTA,PROVINSI\n"
        "1,3301019901010005,3301010101100099,9981,0099887766,Santri Baru Uji,L,Kudus,2012-08-17,Umi Kulsum,Nur Huda,Jl. Menara No. 5,Kauman,Kota,Kudus,Jawa Tengah\n"
    )
    prev_res = client.post(
        "/api/v1/emis/import-preview",
        headers=headers,
        files={"file": ("siswa_baru.csv", sample_csv.encode("utf-8"), "text/csv")}
    )
    assert prev_res.status_code == 200
    prev_data = prev_res.json()
    assert prev_data["valid_count"] == 1
    assert prev_data["error_count"] == 0

    # 4. Import Commit
    commit_res = client.post(
        "/api/v1/emis/import-commit",
        headers=headers,
        json={
            "rombel_id": rombel.id,
            "tanggal_masuk": "2026-07-15",
            "rows": [
                {
                    "nik": "3301019901010005",
                    "no_kk": "3301010101100099",
                    "nis": "9981",
                    "nisn": "0099887766",
                    "nama_lengkap": "Santri Baru Uji",
                    "jk": "L",
                    "tempat_lahir": "Kudus",
                    "tanggal_lahir": "2012-08-17",
                    "nama_ibu": "Umi Kulsum",
                    "nama_ayah": "Nur Huda",
                    "jalan": "Jl. Menara No. 5",
                    "desa_nama": "Kauman"
                }
            ]
        }
    )
    assert commit_res.status_code == 200
    commit_data = commit_res.json()
    assert commit_data["imported_count"] == 1

    # Verifikasi data tersimpan di database
    siswa_imported = session.exec(select(Siswa).where(Siswa.nis == "9981")).first()
    assert siswa_imported is not None
    assert siswa_imported.nama_lengkap == "Santri Baru Uji"

def test_backup_and_restore_encrypted(client: TestClient, session: Session):
    """
    Menguji pembuatan cadangan SQLite WAL terenkripsi password (AES-256-GCM),
    verifikasi integritas checksum SHA-256, dan simulasi pemulihan (restore).
    """
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    backup_pwd = "PasswordRahasiaAdmin123!"

    # 1. Buat backup
    b_res = client.post(
        "/api/v1/backup/create",
        headers=headers,
        data={"password": backup_pwd}
    )
    assert b_res.status_code == 200
    backup_bytes = b_res.content
    assert len(backup_bytes) > 100

    # 2. Verifikasi backup dengan password yang benar
    v_res = client.post(
        "/api/v1/backup/verify",
        headers=headers,
        data={"password": backup_pwd},
        files={"file": ("cadangan.bak", backup_bytes, "application/octet-stream")}
    )
    assert v_res.status_code == 200
    manifest = v_res.json()["manifest"]
    assert manifest["status"] == "VALID"
    assert "db_sha256" in manifest

    # 3. Verifikasi backup dengan password salah (harus ditolak 400)
    v_fail = client.post(
        "/api/v1/backup/verify",
        headers=headers,
        data={"password": "PasswordSalahTotal"},
        files={"file": ("cadangan.bak", backup_bytes, "application/octet-stream")}
    )
    assert v_fail.status_code == 400
    assert "salah" in v_fail.json()["detail"].lower()

    # 4. Uji Restore Database
    r_res = client.post(
        "/api/v1/backup/restore",
        headers=headers,
        data={"password": backup_pwd},
        files={"file": ("cadangan.bak", backup_bytes, "application/octet-stream")}
    )
    assert r_res.status_code == 200
    assert r_res.json()["success"] is True
