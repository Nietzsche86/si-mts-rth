import os
import hashlib
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Response, status
from sqlmodel import Session, select

from app.api.deps import get_current_user, get_current_admin_user
from app.db.engine import get_session
from app.core.config import settings
from app.core.security import encrypt_bytes_aes_gcm, decrypt_bytes_aes_gcm
from app.models import (
    User, UserRole, Siswa, SiswaBerkas, Rombel, KeanggotaanRombel, AuditLog,
    generate_uuid, current_time_epoch_ms
)
from app.services.sync_service import get_next_server_seq

router = APIRouter(prefix="/berkas", tags=["Pengelolaan Berkas Siswa Sandboxed"])

# Magic bytes signature validation
JPEG_MAGIC = b"\xFF\xD8\xFF"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
PDF_MAGIC = b"%PDF"

def detect_mime_type_from_magic_bytes(content: bytes) -> str:
    """Memeriksa isi berkas (*magic bytes*) untuk mencegah pemalsuan ekstensi."""
    if content.startswith(JPEG_MAGIC):
        return "image/jpeg"
    elif content.startswith(PNG_MAGIC):
        return "image/png"
    elif content.startswith(PDF_MAGIC):
        return "application/pdf"
    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Format berkas tidak valid atau tidak didukung. Hanya menerima JPG, PNG, dan PDF asli."
    )

def ensure_berkas_access(user: User, siswa_id: str, db: Session):
    """
    Memvalidasi hak akses berkas siswa:
    - Admin & Kepala: Berhak untuk seluruh siswa.
    - Wali Kelas: Hanya untuk siswa yang aktif di rombel perwaliannya.
    - Guru Mapel: Ditolak (PRD Bagian 2: Berkas siswa Guru Mapel: 'Tidak ada').
    """
    user_roles = db.exec(select(UserRole).where(UserRole.user_id == user.id)).all()
    roles = {r.role for r in user_roles}
    if "admin" in roles or "kepala" in roles:
        return

    # Cek apakah user adalah wali kelas siswa tersebut
    if user.guru_id:
        stmt = (
            select(KeanggotaanRombel)
            .join(Rombel, Rombel.id == KeanggotaanRombel.rombel_id)
            .where(
                KeanggotaanRombel.siswa_id == siswa_id,
                KeanggotaanRombel.tanggal_keluar == None,
                KeanggotaanRombel.deleted == 0,
                Rombel.wali_guru_id == user.guru_id,
                Rombel.deleted == 0
            )
        )
        is_wali = db.exec(stmt).first()
        if is_wali:
            return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Akses ditolak: Anda tidak memiliki wewenang untuk berkas siswa ini"
    )

@router.post("/upload")
async def upload_berkas_siswa(
    siswa_id: str = Form(...),
    jenis_berkas_kode: str = Form(...),  # 'KK', 'AKTA', 'IJAZAH', 'FOTO', dll
    nama_tampil: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Mengunggah berkas siswa dengan validasi magic bytes, enkripsi AES-256-GCM fisik,
    dan pencatatan audit log.
    """
    ensure_berkas_access(current_user, siswa_id, db)

    siswa = db.get(Siswa, siswa_id)
    if not siswa or siswa.deleted == 1:
        raise HTTPException(status_code=404, detail="Siswa tidak ditemukan atau non-aktif")

    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Berkas kosong")

    # 1. Validasi Magic Bytes
    mime = detect_mime_type_from_magic_bytes(content)

    # 2. Validasi Ukuran (PRD F5: Gambar ±1MB, PDF maks ±5MB)
    if mime.startswith("image/") and len(content) > 1 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Ukuran berkas foto melebihi batas 1 MB")
    elif mime == "application/pdf" and len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Ukuran berkas PDF melebihi batas 5 MB")

    # 3. Hitung SHA-256 Plaintext
    sha256_plain = hashlib.sha256(content).hexdigest()

    # 4. Enkripsi AES-256-GCM & Simpan ke Storage
    encrypted_bytes = encrypt_bytes_aes_gcm(content)

    os.makedirs(settings.STORAGE_DIR, exist_ok=True)
    berkas_id = generate_uuid()
    storage_filename = f"{berkas_id}.enc"
    storage_path = os.path.join(settings.STORAGE_DIR, storage_filename)

    with open(storage_path, "wb") as f:
        f.write(encrypted_bytes)

    now_epoch = current_time_epoch_ms()
    berkas = SiswaBerkas(
        id=berkas_id,
        siswa_id=siswa_id,
        jenis_berkas_kode=jenis_berkas_kode,
        nama_tampil=nama_tampil or file.filename or f"Berkas_{jenis_berkas_kode}",
        mime_type=mime,
        ukuran_byte=len(content),
        sha256_plain=sha256_plain,
        server_path_enc=storage_filename,
        status_unggah="SELESAI",
        diunggah_oleh_user_id=current_user.id,
        device_id="server",
        created_at=now_epoch,
        updated_at=now_epoch,
        server_seq=get_next_server_seq(db),
    )
    db.add(berkas)

    # 5. Catat Audit Log
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=current_user.id,
        device_id="server",
        aksi="UNGGAH_BERKAS",
        tabel="siswa_berkas",
        baris_id=berkas_id,
        keterangan=f"Mengunggah berkas {berkas.nama_tampil} ({mime}, {len(content)} bytes) untuk siswa {siswa.nama_lengkap}"
    )
    db.add(audit)
    db.commit()
    db.refresh(berkas)

    return berkas

@router.get("/{berkas_id}/download")
def download_berkas(
    berkas_id: str,
    db: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """
    Mendekripsi berkas AES-256-GCM secara on-the-fly dan mengirimkannya ke klien sandboxed.
    Mencatat pembukaan berkas ke audit log (PRD F5: 'pembukaan tercatat').
    """
    berkas = db.get(SiswaBerkas, berkas_id)
    if not berkas or berkas.deleted == 1:
        raise HTTPException(status_code=404, detail="Berkas tidak ditemukan")

    ensure_berkas_access(current_user, berkas.siswa_id, db)

    storage_filename = berkas.server_path_enc or f"{berkas_id}.enc"
    storage_path = os.path.join(settings.STORAGE_DIR, storage_filename)
    if not os.path.exists(storage_path):
        raise HTTPException(status_code=404, detail="Berkas fisik di server tidak ditemukan")

    with open(storage_path, "rb") as f:
        encrypted_data = f.read()

    try:
        decrypted_bytes = decrypt_bytes_aes_gcm(encrypted_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gagal mendekripsi berkas: {str(e)}")

    # Verifikasi integritas SHA-256
    calc_hash = hashlib.sha256(decrypted_bytes).hexdigest()
    if calc_hash != berkas.sha256_plain:
        raise HTTPException(status_code=500, detail="Integritas berkas rusak (SHA-256 tidak cocok)")

    # Catat audit log pembukaan berkas
    now_epoch = current_time_epoch_ms()
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=current_user.id,
        device_id="server",
        aksi="BUKA_BERKAS",
        tabel="siswa_berkas",
        baris_id=berkas_id,
        keterangan=f"Membuka/mengunduh berkas sandboxed {berkas.nama_tampil}"
    )
    db.add(audit)
    db.commit()

    headers = {
        "Content-Disposition": f'inline; filename="{berkas.nama_tampil}"',
        "X-SHA256-Checksum": berkas.sha256_plain,
    }
    return Response(content=decrypted_bytes, media_type=berkas.mime_type, headers=headers)

@router.get("/siswa/{siswa_id}", response_model=List[SiswaBerkas])
def get_berkas_siswa(
    siswa_id: str,
    db: Session = Depends(get_session),
    current_user: User = Depends(get_current_user),
):
    """Mendapatkan daftar metadata berkas yang dimiliki siswa."""
    ensure_berkas_access(current_user, siswa_id, db)

    stmt = select(SiswaBerkas).where(
        SiswaBerkas.siswa_id == siswa_id,
        SiswaBerkas.deleted == 0
    ).order_by(SiswaBerkas.created_at.desc())
    return db.exec(stmt).all()

@router.delete("/{berkas_id}")
def delete_berkas(
    berkas_id: str,
    db: Session = Depends(get_session),
    admin: User = Depends(get_current_admin_user),
):
    """Menghapus berkas siswa (soft delete, Admin only)."""
    berkas = db.get(SiswaBerkas, berkas_id)
    if not berkas or berkas.deleted == 1:
        raise HTTPException(status_code=404, detail="Berkas tidak ditemukan")

    now_epoch = current_time_epoch_ms()
    berkas.deleted = 1
    berkas.updated_at = now_epoch
    berkas.server_seq = get_next_server_seq(db)
    db.add(berkas)

    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=admin.id,
        device_id="server",
        aksi="HAPUS_BERKAS",
        tabel="siswa_berkas",
        baris_id=berkas_id,
        keterangan=f"Admin {admin.username} menghapus berkas {berkas.nama_tampil}"
    )
    db.add(audit)
    db.commit()

    return {"success": True, "message": f"Berkas {berkas.nama_tampil} berhasil dihapus"}
