from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlmodel import Session, select

from app.core.security import verify_password, get_password_hash, create_access_token
from app.db.engine import get_session
from app.models import User, UserRole, Madrasah, current_time_epoch_ms
from app.api.deps import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

class LoginRequest(BaseModel):
    username: str
    pin: str
    device_id: str
    nama_perangkat: str
    versi_app: str = "1.0.0"

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    username: str
    guru_id: str | None = None
    roles: list[str] = []

class SetupAdminRequest(BaseModel):
    username: str
    pin: str
    nama_madrasah: str

@router.post("/setup-admin", response_model=Dict[str, Any])
def setup_initial_admin(req: SetupAdminRequest, session: Session = Depends(get_session)):
    """Inisialisasi akun Admin pertama madrasah."""
    existing_user = session.exec(select(User)).first()
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Admin sudah terdaftar. Gunakan endpoint login."
        )
        
    # Buat Madrasah
    madrasah = Madrasah(
        nama=req.nama_madrasah,
        created_at=current_time_epoch_ms(),
        updated_at=current_time_epoch_ms(),
        device_id="server"
    )
    session.add(madrasah)
    
    # Buat User Admin
    user = User(
        username=req.username,
        pin_hash=get_password_hash(req.pin),
        aktif=1,
        created_at=current_time_epoch_ms(),
        updated_at=current_time_epoch_ms(),
        device_id="server"
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    
    # Berikan Role Admin
    role = UserRole(
        user_id=user.id,
        role="admin",
        created_at=current_time_epoch_ms(),
        updated_at=current_time_epoch_ms(),
        device_id="server"
    )
    session.add(role)
    session.commit()
    
    return {"message": "Admin berhasil dibuat", "username": user.username}

@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.username == req.username)).first()
    if not user:
        raise HTTPException(status_code=400, detail="Nama pengguna atau PIN salah")
        
    if user.aktif == 0:
        raise HTTPException(status_code=400, detail="Akun dinonaktifkan oleh administrator")
        
    now = current_time_epoch_ms()
    if user.terkunci_sampai and user.terkunci_sampai > now:
        sisa_menit = int((user.terkunci_sampai - now) / 60000) + 1
        raise HTTPException(
            status_code=400,
            detail=f"Akun terkunci karena percobaan gagal. Coba lagi dalam {sisa_menit} menit."
        )
        
    if not verify_password(req.pin, user.pin_hash):
        user.gagal_login += 1
        if user.gagal_login >= 5:
            user.terkunci_sampai = now + (15 * 60 * 1000)  # Kunci 15 menit
            user.gagal_login = 0
        session.add(user)
        session.commit()
        raise HTTPException(status_code=400, detail="Nama pengguna atau PIN salah")
        
    # Reset gagal login saat sukses
    user.gagal_login = 0
    user.terkunci_sampai = None
    session.add(user)
    session.commit()
    
    # Ambil roles
    roles = session.exec(select(UserRole).where(UserRole.user_id == user.id)).all()
    role_names = [r.role for r in roles]
    
    token = create_access_token(user.username)
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        username=user.username,
        guru_id=user.guru_id,
        roles=role_names
    )

@router.get("/me")
def get_me(user: User = Depends(get_current_user), session: Session = Depends(get_session)):
    roles = session.exec(select(UserRole).where(UserRole.user_id == user.id)).all()
    return {
        "id": user.id,
        "username": user.username,
        "guru_id": user.guru_id,
        "roles": [r.role for r in roles]
    }
