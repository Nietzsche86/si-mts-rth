from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import get_current_user, get_current_admin_user
from app.db.engine import get_session
from app.models import User
from app.schemas.sync import (
    SyncPushRequest, SyncPushResponse, SyncPullResponse,
    SyncPullChangeItem, ActiveScope
)
from app.services.sync_service import (
    MODEL_MAP, process_push_changes, compute_active_scope, TABLE_TIERS
)

router = APIRouter(prefix="/sync", tags=["sync"])

# Global memory lock untuk operasi mutasi massal Admin (PRD F17)
SYNC_LOCKED: bool = False
LOCKED_BY_USER: Optional[str] = None

@router.post("/lock")
def lock_sync(admin: User = Depends(get_current_admin_user)):
    global SYNC_LOCKED, LOCKED_BY_USER
    SYNC_LOCKED = True
    LOCKED_BY_USER = admin.username
    return {"message": "Sinkronisasi berhasil dikunci untuk operasi mutasi massal"}

@router.post("/unlock")
def unlock_sync(admin: User = Depends(get_current_admin_user)):
    global SYNC_LOCKED, LOCKED_BY_USER
    SYNC_LOCKED = False
    LOCKED_BY_USER = None
    return {"message": "Sinkronisasi berhasil dibuka kembali"}

@router.post("/push", response_model=SyncPushResponse)
def sync_push(
    req: SyncPushRequest,
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    if SYNC_LOCKED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Sinkronisasi sedang dikunci oleh admin ({LOCKED_BY_USER}) untuk mutasi data"
        )
        
    results = process_push_changes(
        session=session,
        user=current_user,
        device_id=req.device_id,
        changes=req.changes
    )
    return SyncPushResponse(results=results)

@router.get("/pull", response_model=SyncPullResponse)
def sync_pull(
    since_seq: int = Query(default=0, ge=0),
    limit: int = Query(default=500, le=1000),
    current_user: User = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    scope, roles = compute_active_scope(session, current_user)
    is_admin = "admin" in roles
    is_kepala = "kepala" in roles
    is_guru_mapel_only = (not is_admin) and (not is_kepala) and (not scope.wali_rombel_ids)
    
    # Filter tabel yang dilarang untuk Guru Mapel murni sesuai PRD Bagian 9.6
    restricted_tables_for_guru = {
        "siswa_detail", "siswa_ortu", "alamat", "siswa_sensitif", "siswa_berkas"
    }
    
    # Kumpulkan perubahan dari semua tabel domain yang memiliki server_seq > since_seq
    changes: List[SyncPullChangeItem] = []
    max_seq_found = since_seq
    
    for tbl_name, model_cls in MODEL_MAP.items():
        if is_guru_mapel_only and tbl_name in restricted_tables_for_guru:
            continue
            
        # Ambil baris dengan server_seq > since_seq
        query = select(model_cls).where(model_cls.server_seq > since_seq).order_by(model_cls.server_seq).limit(limit)
        rows = session.exec(query).all()
        
        for r in rows:
            seq = r.server_seq or 0
            if seq > max_seq_found:
                max_seq_found = seq
                
            # Filter baris untuk role guru mapel murni:
            if is_guru_mapel_only:
                # Siswa, Nilai, Absensi, Keanggotaan harus termasuk dalam allowed_keanggotaan_ids
                if tbl_name == "nilai" and r.keanggotaan_id not in scope.allowed_keanggotaan_ids:
                    continue
                if tbl_name == "absensi" and r.keanggotaan_id not in scope.allowed_keanggotaan_ids:
                    continue
                if tbl_name == "keanggotaan_rombel" and r.id not in scope.allowed_keanggotaan_ids:
                    continue
            
            row_dict = r.model_dump()
            
            # Sanitasi kolom rahasia server agar tidak pernah bocor ke klien
            for secret_col in ["nik_siswa_hash", "no_kk_hash", "nik_hash", "pin_hash"]:
                row_dict.pop(secret_col, None)
                
            changes.append(SyncPullChangeItem(
                table=tbl_name,
                server_seq=seq,
                row=row_dict
            ))
            
    # Urutkan changes berdasarkan server_seq
    changes.sort(key=lambda c: c.server_seq)
    paged_changes = changes[:limit]
    has_more = len(changes) > limit
    
    return SyncPullResponse(
        from_seq=since_seq,
        to_seq=max_seq_found,
        has_more=has_more,
        recalculate_scope=True,
        active_scope=scope,
        changes=paged_changes
    )
