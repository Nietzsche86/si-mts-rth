from typing import Optional
from sqlmodel import SQLModel, Field, UniqueConstraint
from app.models.base import SyncBaseModel, generate_uuid, current_time_epoch_ms

class Madrasah(SyncBaseModel, table=True):
    __tablename__ = "madrasah"
    nama: str
    npsn: Optional[str] = None
    nsm: Optional[str] = None
    alamat: Optional[str] = None
    kepala_guru_id: Optional[str] = None
    logo_berkas_id: Optional[str] = None
    semester_aktif_id: Optional[str] = None

class User(SyncBaseModel, table=True):
    __tablename__ = "user"
    guru_id: Optional[str] = None
    username: str = Field(unique=True, index=True)
    aktif: int = Field(default=1)
    
    # Khusus di server (tidak dikirim saat pull ke device biasa jika sensitif):
    pin_hash: str
    gagal_login: int = Field(default=0)
    terkunci_sampai: Optional[int] = None

class UserRole(SyncBaseModel, table=True):
    __tablename__ = "user_role"
    __table_args__ = (UniqueConstraint("user_id", "role", name="uq_user_role"),)
    
    user_id: str = Field(index=True)
    role: str = Field(index=True)  # 'admin' | 'kepala'

class Perangkat(SQLModel, table=True):
    """Khusus di server: pelacakan status perangkat klien."""
    __tablename__ = "perangkat"
    id: str = Field(primary_key=True)  # device_id
    user_id: str = Field(index=True)
    nama_perangkat: str
    versi_app: str
    last_sync_at: Optional[int] = None
    last_pull_seq: Optional[int] = None
    jumlah_outbox_terakhir: int = Field(default=0)
    aktif: int = Field(default=1)

class AuditLog(SQLModel, table=True):
    __tablename__ = "audit_log"
    id: str = Field(default_factory=generate_uuid, primary_key=True)
    waktu: int = Field(default_factory=current_time_epoch_ms, index=True)
    user_id: Optional[str] = Field(default=None, index=True)
    device_id: str
    aksi: str
    tabel: str
    baris_id: str
    data_lama: Optional[str] = None  # JSON string
    data_baru: Optional[str] = None  # JSON string
    keterangan: Optional[str] = None

class ServerSeqCounter(SQLModel, table=True):
    """Monotonic sequence counter untuk server_seq."""
    __tablename__ = "server_seq_counter"
    id: int = Field(default=1, primary_key=True)
    current_seq: int = Field(default=1000)
