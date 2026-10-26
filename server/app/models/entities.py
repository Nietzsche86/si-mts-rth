from typing import Optional
from sqlmodel import Field, UniqueConstraint
from app.models.base import SyncBaseModel

class Siswa(SyncBaseModel, table=True):
    __tablename__ = "siswa"
    nis: str = Field(unique=True, index=True)
    nisn: Optional[str] = Field(default=None, index=True)
    nama_lengkap: str = Field(index=True)
    jk: str  # 'L' | 'P'
    status_aktif: str = Field(default="aktif", index=True)  # 'aktif' | 'lulus' | 'mutasi_keluar' | 'nonaktif'
    diubah_wali_kelas: int = Field(default=0)

class SiswaDetail(SyncBaseModel, table=True):
    """Tabel profil gabung-per-kolom (kolom_ts)."""
    __tablename__ = "siswa_detail"
    siswa_id: str = Field(unique=True, index=True)
    tempat_lahir: Optional[str] = None
    tanggal_lahir: Optional[str] = None  # YYYY-MM-DD
    agama_kode: Optional[str] = None
    anak_ke: Optional[int] = None
    jumlah_saudara: Optional[int] = None
    foto_berkas_id: Optional[str] = None
    nomor_hp: Optional[str] = None
    email: Optional[str] = None
    kebutuhan_khusus_kode: Optional[str] = None
    tinggi_cm: Optional[float] = None
    berat_kg: Optional[float] = None
    tinggal_bersama_kode: Optional[str] = None
    transportasi_kode: Optional[str] = None
    jarak_km: Optional[float] = None
    waktu_tempuh_menit: Optional[int] = None
    penerima_kip: int = Field(default=0)
    penerima_kps: int = Field(default=0)
    penerima_pkh: int = Field(default=0)
    sekolah_asal: Optional[str] = None
    tanggal_masuk: Optional[str] = None
    jenis_pendaftaran_kode: Optional[str] = None
    diubah_wali_kelas: int = Field(default=0)
    kolom_ts: str = Field(default="{}")  # JSON string mapping: {"col_name": epoch_ms}

class SiswaOrtu(SyncBaseModel, table=True):
    """Tabel orang tua/wali gabung-per-kolom (kolom_ts)."""
    __tablename__ = "siswa_ortu"
    __table_args__ = (UniqueConstraint("siswa_id", "hubungan", name="uq_siswa_ortu_hubungan"),)
    
    siswa_id: str = Field(index=True)
    hubungan: str = Field(index=True)  # 'ayah' | 'ibu' | 'wali'
    nama_lengkap: str
    tempat_lahir: Optional[str] = None
    tanggal_lahir: Optional[str] = None
    status_hidup_kode: Optional[str] = None  # 'hidup' | 'cerai' | 'wafat'
    tahun_wafat: Optional[int] = None
    pekerjaan_kode: Optional[str] = None
    pendidikan_kode: Optional[str] = None
    penghasilan_kode: Optional[str] = None
    nomor_hp: Optional[str] = None
    kebutuhan_khusus_kode: Optional[str] = None
    diubah_wali_kelas: int = Field(default=0)
    kolom_ts: str = Field(default="{}")

class Alamat(SyncBaseModel, table=True):
    """Tabel alamat entitas gabung-per-kolom (kolom_ts)."""
    __tablename__ = "alamat"
    __table_args__ = (UniqueConstraint("pemilik_tipe", "pemilik_id", name="uq_alamat_pemilik"),)
    
    pemilik_tipe: str = Field(index=True)  # 'siswa' | 'siswa_ortu' | 'guru'
    pemilik_id: str = Field(index=True)
    siswa_id: Optional[str] = Field(default=None, index=True)
    jalan: Optional[str] = None
    rt: Optional[str] = None
    rw: Optional[str] = None
    dusun: Optional[str] = None
    desa_kode: Optional[str] = None
    desa_nama: Optional[str] = None
    kecamatan_kode: Optional[str] = None
    kecamatan_nama: Optional[str] = None
    kabupaten_kode: Optional[str] = None
    kabupaten_nama: Optional[str] = None
    provinsi_kode: Optional[str] = None
    provinsi_nama: Optional[str] = None
    kode_pos: Optional[str] = None
    diubah_wali_kelas: int = Field(default=0)
    kolom_ts: str = Field(default="{}")

class SiswaSensitif(SyncBaseModel, table=True):
    """Data sensitif terenkripsi AES-256-GCM."""
    __tablename__ = "siswa_sensitif"
    siswa_id: str = Field(unique=True, index=True)
    no_kk_enc: Optional[str] = None
    nik_siswa_enc: Optional[str] = None
    nik_ayah_enc: Optional[str] = None
    nik_ibu_enc: Optional[str] = None
    nik_wali_enc: Optional[str] = None
    no_kip_enc: Optional[str] = None
    no_kps_enc: Optional[str] = None
    no_pkh_enc: Optional[str] = None
    
    # Khusus di server (tidak dikirim ke HP):
    nik_siswa_hash: Optional[str] = Field(default=None, index=True)
    no_kk_hash: Optional[str] = Field(default=None, index=True)

class SiswaBerkas(SyncBaseModel, table=True):
    __tablename__ = "siswa_berkas"
    siswa_id: str = Field(index=True)
    jenis_berkas_kode: str = Field(index=True)  # 'KK', 'AKTA', 'IJAZAH', 'FOTO', dll
    nama_tampil: str
    mime_type: str
    ukuran_byte: int
    sha256_plain: str
    server_path_enc: Optional[str] = None
    status_unggah: str = Field(default="SELESAI")
    diunggah_oleh_user_id: Optional[str] = None

class Guru(SyncBaseModel, table=True):
    __tablename__ = "guru"
    nip: Optional[str] = Field(default=None, index=True)
    nama_lengkap: str = Field(index=True)
    jk: str  # 'L' | 'P'
    status_kepegawaian_kode: Optional[str] = None  # 'PNS', 'PPPK', 'GTY', 'GTT'
    aktif: int = Field(default=1, index=True)

class GuruDetail(SyncBaseModel, table=True):
    """Tabel profil guru gabung-per-kolom (kolom_ts)."""
    __tablename__ = "guru_detail"
    guru_id: str = Field(unique=True, index=True)
    nuptk: Optional[str] = None
    tempat_lahir: Optional[str] = None
    tanggal_lahir: Optional[str] = None
    agama_kode: Optional[str] = None
    nomor_hp: Optional[str] = None
    email: Optional[str] = None
    foto_berkas_id: Optional[str] = None
    pendidikan_kode: Optional[str] = None
    jurusan: Optional[str] = None
    perguruan_tinggi: Optional[str] = None
    tahun_lulus: Optional[int] = None
    tmt_guru: Optional[str] = None
    golongan_kode: Optional[str] = None
    sertifikasi: int = Field(default=0)
    kolom_ts: str = Field(default="{}")

class GuruSensitif(SyncBaseModel, table=True):
    __tablename__ = "guru_sensitif"
    guru_id: str = Field(unique=True, index=True)
    nik_enc: Optional[str] = None
    
    # Khusus di server:
    nik_hash: Optional[str] = Field(default=None, index=True)

class GuruBerkas(SyncBaseModel, table=True):
    __tablename__ = "guru_berkas"
    guru_id: str = Field(index=True)
    jenis_berkas_kode: str
    nama_tampil: str
    mime_type: str
    ukuran_byte: int
    sha256_plain: str
    server_path_enc: Optional[str] = None
    status_unggah: str = Field(default="SELESAI")
