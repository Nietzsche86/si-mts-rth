import sqlite3
from contextlib import contextmanager
from typing import Generator
from sqlalchemy import event, text
from sqlalchemy.engine import Engine
from sqlmodel import create_engine, Session, SQLModel

from app.core.config import settings

# Engine SQLite WAL (1 worker recommended for operator laptop server)
engine = create_engine(
    settings.DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)

@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if isinstance(dbapi_connection, sqlite3.Connection):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode = WAL;")
        cursor.execute("PRAGMA synchronous = NORMAL;")
        cursor.execute("PRAGMA foreign_keys = ON;")
        cursor.execute("PRAGMA busy_timeout = 5000;")
        cursor.close()

def create_partial_indexes(session: Session) -> None:
    """Membuat 5 Partial Unique Index wajib sesuai CLAUDE.md & PRD Bagian 9.3."""
    partial_indexes = [
        # 1. Satu keanggotaan rombel terbuka per siswa
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_keanggotaan_terbuka_unik
        ON keanggotaan_rombel(siswa_id)
        WHERE tanggal_keluar IS NULL AND deleted = 0;
        """,
        # 2. Satu pengampu UTAMA aktif per (mapel, rombel, semester)
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_utama_aktif
        ON pengampu(mapel_id, rombel_id, semester_id)
        WHERE peran = 'utama' AND tanggal_selesai IS NULL AND deleted = 0;
        """,
        # 3. Satu penugasan aktif per guru pada (mapel, rombel, semester)
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_guru_aktif
        ON pengampu(guru_id, mapel_id, rombel_id, semester_id)
        WHERE tanggal_selesai IS NULL AND deleted = 0;
        """,
        # 4. Business Key Nilai (1 nilai aktif per siswa, mapel, semester, jenis, urutan_ke)
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_bisnis_unik
        ON nilai(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)
        WHERE deleted = 0;
        """,
        # 5. Business Key Absensi (1 absensi aktif per siswa per tanggal)
        """
        CREATE UNIQUE INDEX IF NOT EXISTS idx_absensi_bisnis_unik
        ON absensi(keanggotaan_id, tanggal)
        WHERE deleted = 0;
        """,
        # Indeks Performa Tambahan
        "CREATE INDEX IF NOT EXISTS idx_siswa_nis ON siswa(nis);",
        "CREATE INDEX IF NOT EXISTS idx_keanggotaan_siswa_rombel ON keanggotaan_rombel(siswa_id, rombel_id);",
        "CREATE INDEX IF NOT EXISTS idx_nilai_keanggotaan_sem ON nilai(keanggotaan_id, semester_id);",
        "CREATE INDEX IF NOT EXISTS idx_nilai_mapel_sem ON nilai(mapel_id, semester_id);",
        "CREATE INDEX IF NOT EXISTS idx_pengampu_guru_sem ON pengampu(guru_id, semester_id);",
        "CREATE INDEX IF NOT EXISTS idx_pengampu_siswa_keanggotaan ON pengampu_siswa(keanggotaan_id);",
        "CREATE INDEX IF NOT EXISTS idx_rombel_wali ON rombel(wali_guru_id);",
        "CREATE INDEX IF NOT EXISTS idx_alamat_siswa_id ON alamat(siswa_id);",
    ]
    for ddl in partial_indexes:
        session.exec(text(ddl))
    session.commit()

def init_db() -> None:
    """Menginisialisasi semua tabel dan index parsial."""
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        create_partial_indexes(session)

def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session

@contextmanager
def get_session_context() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
