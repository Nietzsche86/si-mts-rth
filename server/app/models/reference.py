from typing import Optional
from sqlmodel import Field, UniqueConstraint
from app.models.base import SyncBaseModel

class RefItem(SyncBaseModel, table=True):
    """Tabel referensi standar EMIS (agama, pekerjaan, pendidikan, dsb)."""
    __tablename__ = "ref_item"
    __table_args__ = (UniqueConstraint("kategori", "kode", name="uq_ref_item_kategori_kode"),)
    
    kategori: str = Field(index=True)
    kode: str = Field(index=True)
    nama: str
    urutan: int = Field(default=0)
    aktif: int = Field(default=1)

class RefWilayah(SyncBaseModel, table=True):
    """Tabel referensi wilayah administrasi (provinsi hingga desa)."""
    __tablename__ = "ref_wilayah"
    
    kode: str = Field(index=True)
    nama: str
    tingkat: str = Field(index=True)  # 'prov' | 'kab' | 'kec' | 'desa'
    induk_kode: Optional[str] = Field(default=None, index=True)
