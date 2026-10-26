import pytest
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session
from app.models import KeanggotaanRombel, Pengampu

def test_partial_unique_index_keanggotaan_terbuka(session: Session):
    siswa_id = "siswa-uuid-001"
    rombel_1 = "rombel-7a"
    rombel_2 = "rombel-7b"

    # 1. Baris keanggotaan aktif pertama
    k1 = KeanggotaanRombel(
        siswa_id=siswa_id,
        rombel_id=rombel_1,
        tanggal_masuk="2026-07-15",
        tanggal_keluar=None,
        deleted=0,
        device_id="device-1"
    )
    session.add(k1)
    session.commit()

    # 2. Mencoba menambahkan baris keanggotaan aktif kedua untuk siswa yang sama -> WAJIB GAGAL
    k2 = KeanggotaanRombel(
        siswa_id=siswa_id,
        rombel_id=rombel_2,
        tanggal_masuk="2026-08-01",
        tanggal_keluar=None,
        deleted=0,
        device_id="device-1"
    )
    session.add(k2)
    with pytest.raises(IntegrityError):
        session.commit()
    session.rollback()

    # 3. Tutup keanggotaan pertama (pindah rombel), lalu tambah yang baru -> WAJIB SUKSES
    k1_db = session.get(KeanggotaanRombel, k1.id)
    k1_db.tanggal_keluar = "2026-07-31"
    k1_db.alasan_keluar = "pindah_rombel"
    session.add(k1_db)
    session.commit()

    k3 = KeanggotaanRombel(
        siswa_id=siswa_id,
        rombel_id=rombel_2,
        tanggal_masuk="2026-08-01",
        tanggal_keluar=None,
        sumber_keanggotaan_id=k1.id,
        deleted=0,
        device_id="device-1"
    )
    session.add(k3)
    session.commit()
    assert k3.id is not None

def test_partial_unique_index_pengampu_utama(session: Session):
    mapel_id = "mapel-fiqih"
    rombel_id = "rombel-7a"
    semester_id = "sem-1"
    guru_1 = "guru-ahmad"
    guru_2 = "guru-budi"

    # 1. Guru 1 pengampu utama aktif
    p1 = Pengampu(
        guru_id=guru_1,
        mapel_id=mapel_id,
        rombel_id=rombel_id,
        semester_id=semester_id,
        cakupan="seluruh",
        peran="utama",
        tanggal_mulai="2026-07-15",
        tanggal_selesai=None,
        deleted=0,
        device_id="device-1"
    )
    session.add(p1)
    session.commit()

    # 2. Guru 2 mencoba menjadi pengampu utama aktif di kelas & mapel yang sama -> WAJIB GAGAL
    p2 = Pengampu(
        guru_id=guru_2,
        mapel_id=mapel_id,
        rombel_id=rombel_id,
        semester_id=semester_id,
        cakupan="seluruh",
        peran="utama",
        tanggal_mulai="2026-07-15",
        tanggal_selesai=None,
        deleted=0,
        device_id="device-1"
    )
    session.add(p2)
    with pytest.raises(IntegrityError):
        session.commit()
    session.rollback()

    # 3. Guru 2 sebagai pendamping -> WAJIB SUKSES
    p3 = Pengampu(
        guru_id=guru_2,
        mapel_id=mapel_id,
        rombel_id=rombel_id,
        semester_id=semester_id,
        cakupan="seluruh",
        peran="pendamping",
        tanggal_mulai="2026-07-15",
        tanggal_selesai=None,
        deleted=0,
        device_id="device-1"
    )
    session.add(p3)
    session.commit()
    assert p3.id is not None
