import io
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.responses import StreamingResponse
from sqlmodel import Session

from app.api.deps import get_current_admin_user
from app.db.engine import get_session
from app.models import User, AuditLog, generate_uuid, current_time_epoch_ms
from app.services.backup_service import (
    create_encrypted_backup,
    verify_encrypted_backup,
    restore_encrypted_backup
)

router = APIRouter(prefix="/backup", tags=["Cadangan & Pemulihan Terenkripsi"])

@router.post("/create")
def create_backup(
    password: str = Form(...),
    db: Session = Depends(get_session),
    admin: User = Depends(get_current_admin_user),
):
    """
    Membuat arsip cadangan database SQLite WAL + seluruh berkas lampiran
    terenkripsi password dengan AES-256-GCM (Admin only).
    """
    if len(password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password cadangan minimal 6 karakter"
        )

    try:
        backup_bytes, manifest = create_encrypted_backup(db, password)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Gagal membuat cadangan database: {str(e)}"
        )

    # Catat ke audit log
    now_epoch = current_time_epoch_ms()
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=admin.id,
        device_id="server",
        aksi="BUAT_BACKUP",
        tabel="madrasah",
        baris_id="backup",
        keterangan=f"Admin {admin.username} membuat cadangan terenkripsi ({manifest['files_count']} berkas lampiran, db sha: {manifest['db_sha256'][:8]}...)"
    )
    db.add(audit)
    db.commit()

    timestamp_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    filename = f"backup_mts_rth_{timestamp_str}.bak"
    headers = {
        "Content-Disposition": f'attachment; filename="{filename}"',
        "X-DB-Checksum": manifest["db_sha256"],
        "X-Files-Count": str(manifest["files_count"]),
    }
    return StreamingResponse(
        io.BytesIO(backup_bytes),
        media_type="application/octet-stream",
        headers=headers
    )

@router.post("/verify")
async def verify_backup(
    password: str = Form(...),
    file: UploadFile = File(...),
    admin: User = Depends(get_current_admin_user),
):
    """
    Memvalidasi berkas cadangan dan password tanpa melakukan pemulihan.
    Mengembalikan metadata manifest dan status integritas checksum.
    """
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Berkas cadangan kosong")

    try:
        manifest = verify_encrypted_backup(content, password)
        return {
            "success": True,
            "filename": file.filename,
            "manifest": manifest
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Terjadi kesalahan saat memvalidasi cadangan: {str(e)}"
        )

@router.post("/restore")
async def restore_backup(
    password: str = Form(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_session),
    admin: User = Depends(get_current_admin_user),
):
    """
    Memulihkan database SQLite WAL dan berkas lampiran dari arsip cadangan terenkripsi.
    Operasi ini memvalidasi integritas sebelum restorasi (Admin only).
    """
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Berkas cadangan kosong")

    try:
        result = restore_encrypted_backup(content, password)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Gagal memulihkan database: {str(e)}"
        )

    # Catat pemulihan ke audit log
    now_epoch = current_time_epoch_ms()
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=admin.id,
        device_id="server",
        aksi="PULIHKAN_BACKUP",
        tabel="madrasah",
        baris_id="restore",
        keterangan=f"Admin {admin.username} berhasil memulihkan database dari {file.filename}"
    )
    db.add(audit)
    db.commit()

    return result
