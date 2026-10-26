from typing import Optional
from sqlmodel import Field, UniqueConstraint
from app.models.base import SyncBaseModel

class TahunAjaran(SyncBaseModel, table=True):
    __tablename__ = "tahun_ajaran"
    nama: str  # contoh: "2026/2027"
    tanggal_mulai: str  # YYYY-MM-DD
    tanggal_selesai: str  # YYYY-MM-DD
    aktif: int = Field(default=0, index=True)

class Semester(SyncBaseModel, table=True):
    __tablename__ = "semester"
    __table_args__ = (UniqueConstraint("tahun_ajaran_id", "jenis", name="uq_semester_tahun_jenis"),)
    
    tahun_ajaran_id: str = Field(index=True)
    jenis: str = Field(index=True)  # 'ganjil' | 'genap'
    tanggal_mulai: str  # YYYY-MM-DD
    tanggal_selesai: str  # YYYY-MM-DD
    dikunci: int = Field(default=0, index=True)  # 0 | 1

class Mapel(SyncBaseModel, table=True):
    __tablename__ = "mapel"
    kode: str = Field(unique=True, index=True)  # contoh: "QURHAN", "AKIDAH"
    nama: str
    kelompok: str  # 'PAI', 'Umum', dsb
    urutan: int = Field(default=0)
    aktif: int = Field(default=1)

class Rombel(SyncBaseModel, table=True):
    __tablename__ = "rombel"
    tahun_ajaran_id: str = Field(index=True)
    nama: str  # contoh: "7A", "8B"
    tingkat: str = Field(index=True)  # '7' | '8' | '9'
    wali_guru_id: Optional[str] = Field(default=None, index=True)

class Pengampu(SyncBaseModel, table=True):
    """
    Penugasan guru mengajar.
    Constraint unik parsial ditangani via idx_pengampu_utama_aktif & idx_pengampu_guru_aktif.
    """
    __tablename__ = "pengampu"
    guru_id: str = Field(index=True)
    mapel_id: str = Field(index=True)
    rombel_id: str = Field(index=True)
    semester_id: str = Field(index=True)
    cakupan: str = Field(default="seluruh")  # 'seluruh' | 'sebagian'
    peran: str = Field(default="utama")  # 'utama' | 'pendamping'
    tanggal_mulai: str  # YYYY-MM-DD
    tanggal_selesai: Optional[str] = Field(default=None, index=True)  # YYYY-MM-DD

class PengampuSiswa(SyncBaseModel, table=True):
    """Mapping kelompok siswa khusus jika pengampu.cakupan = 'sebagian'."""
    __tablename__ = "pengampu_siswa"
    __table_args__ = (UniqueConstraint("pengampu_id", "keanggotaan_id", name="uq_pengampu_siswa"),)
    
    pengampu_id: str = Field(index=True)
    keanggotaan_id: str = Field(index=True)

class KeanggotaanRombel(SyncBaseModel, table=True):
    """
    Status keanggotaan siswa di rombel.
    Constraint terbuka unik ditangani via idx_keanggotaan_terbuka_unik.
    """
    __tablename__ = "keanggotaan_rombel"
    siswa_id: str = Field(index=True)
    rombel_id: str = Field(index=True)
    tanggal_masuk: str  # YYYY-MM-DD
    tanggal_keluar: Optional[str] = Field(default=None, index=True)  # YYYY-MM-DD
    alasan_keluar: Optional[str] = None  # 'naik_kelas' | 'tinggal_kelas' | 'pindah_rombel' | 'mutasi_keluar' | 'lulus' | 'keluar'
    sumber_keanggotaan_id: Optional[str] = None

class RiwayatStatusSiswa(SyncBaseModel, table=True):
    """Tabel append-only untuk pencatatan rekam jejak status siswa."""
    __tablename__ = "riwayat_status_siswa"
    siswa_id: str = Field(index=True)
    tanggal: str  # YYYY-MM-DD
    jenis_status: str  # 'masuk_baru' | 'mutasi_masuk' | 'pindah_rombel' | 'naik_kelas' | 'tinggal_kelas' | 'mutasi_keluar' | 'lulus' | 'nonaktif' | 'aktif_kembali'
    rombel_asal_id: Optional[str] = None
    rombel_tujuan_id: Optional[str] = None
    sekolah_tujuan: Optional[str] = None
    nomor_surat: Optional[str] = None
    catatan: Optional[str] = None
    membatalkan_id: Optional[str] = None

class JenisNilai(SyncBaseModel, table=True):
    __tablename__ = "jenis_nilai"
    kategori: str = Field(index=True)  # 'pengetahuan' | 'keterampilan'
    kode: str = Field(unique=True, index=True)  # 'TGS', 'UH', 'PAS', 'PAT', 'PRY', 'PRT', 'UK'
    nama: str
    urutan: int = Field(default=0)
    aktif: int = Field(default=1)

class BobotNilai(SyncBaseModel, table=True):
    __tablename__ = "bobot_nilai"
    semester_id: str = Field(index=True)
    mapel_id: Optional[str] = Field(default=None, index=True)  # NULL = default global
    jenis_nilai_id: str = Field(index=True)
    bobot: float = Field(default=1.0)

class PengaturanKkm(SyncBaseModel, table=True):
    __tablename__ = "pengaturan_kkm"
    semester_id: str = Field(index=True)
    mapel_id: Optional[str] = Field(default=None, index=True)
    tingkat: Optional[str] = Field(default=None, index=True)
    kkm: float = Field(default=75.0)

class Nilai(SyncBaseModel, table=True):
    """
    Tabel transaksi nilai siswa.
    Business Key unik ditangani via idx_nilai_bisnis_unik.
    """
    __tablename__ = "nilai"
    keanggotaan_id: str = Field(index=True)
    mapel_id: str = Field(index=True)
    semester_id: str = Field(index=True)
    jenis_nilai_id: str = Field(index=True)
    urutan_ke: int = Field(default=1, index=True)  # >= 1
    nilai: float  # 0.0 - 100.0
    tanggal: str  # YYYY-MM-DD
    keterangan: Optional[str] = None
    sumber_nilai_id: Optional[str] = Field(default=None, index=True)  # penanda jika bawaan rombel asal
    diinput_oleh_guru_id: str = Field(index=True)

class Absensi(SyncBaseModel, table=True):
    """
    Tabel absensi siswa.
    Business Key unik ditangani via idx_absensi_bisnis_unik.
    """
    __tablename__ = "absensi"
    keanggotaan_id: str = Field(index=True)
    semester_id: str = Field(index=True)
    tanggal: str = Field(index=True)  # YYYY-MM-DD
    status: str = Field(index=True)  # 'H' | 'S' | 'I' | 'A'
    keterangan: Optional[str] = None
    diinput_oleh_user_id: str = Field(index=True)
