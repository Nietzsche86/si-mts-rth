from sqlmodel import Session
from app.models import (
    Madrasah, User, Guru, Rombel, Pengampu, PengampuSiswa, KeanggotaanRombel
)
from app.services.sync_service import compute_active_scope

def test_pengampu_utama_fallback_unassigned_students(session: Session):
    # Setup Madrasah & Semester Aktif
    sem_id = "sem-aktif-01"
    madrasah = Madrasah(
        nama="MTs Roudhotut Thowalib",
        semester_aktif_id=sem_id,
        device_id="server"
    )
    session.add(madrasah)

    # Setup Rombel 7A
    rombel_7a = Rombel(
        tahun_ajaran_id="ta-2026",
        nama="7A",
        tingkat="7",
        device_id="server"
    )
    session.add(rombel_7a)

    # Setup 3 Siswa aktif di Rombel 7A (K1, K2, K3)
    k1 = KeanggotaanRombel(id="k-1", siswa_id="s-1", rombel_id=rombel_7a.id, tanggal_masuk="2026-07-15", deleted=0)
    k2 = KeanggotaanRombel(id="k-2", siswa_id="s-2", rombel_id=rombel_7a.id, tanggal_masuk="2026-07-15", deleted=0)
    k3 = KeanggotaanRombel(id="k-3", siswa_id="s-3", rombel_id=rombel_7a.id, tanggal_masuk="2026-07-15", deleted=0)
    session.add_all([k1, k2, k3])

    # Setup Guru Utama (U) dan Guru Pendamping (P)
    guru_u = Guru(id="guru-u", nama_lengkap="Ustadz Utama", jk="L", aktif=1)
    guru_p = Guru(id="guru-p", nama_lengkap="Ustadz Pendamping", jk="L", aktif=1)
    session.add_all([guru_u, guru_p])

    user_u = User(id="user-u", guru_id=guru_u.id, username="ustadz_utama", pin_hash="h1", aktif=1)
    user_p = User(id="user-p", guru_id=guru_p.id, username="ustadz_pendamping", pin_hash="h2", aktif=1)
    session.add_all([user_u, user_p])

    mapel_id = "mapel-fiqih"

    # Penugasan Pengampu mode Sebagian
    p_utama = Pengampu(
        id="p-u",
        guru_id=guru_u.id,
        mapel_id=mapel_id,
        rombel_id=rombel_7a.id,
        semester_id=sem_id,
        cakupan="sebagian",
        peran="utama",
        tanggal_mulai="2026-07-15",
        deleted=0
    )
    p_pendamping = Pengampu(
        id="p-p",
        guru_id=guru_p.id,
        mapel_id=mapel_id,
        rombel_id=rombel_7a.id,
        semester_id=sem_id,
        cakupan="sebagian",
        peran="pendamping",
        tanggal_mulai="2026-07-15",
        deleted=0
    )
    session.add_all([p_utama, p_pendamping])

    # Hanya K1 yang dimasukkan ke kelompok Guru Pendamping
    ps_p = PengampuSiswa(pengampu_id=p_pendamping.id, keanggotaan_id=k1.id, deleted=0)
    session.add(ps_p)
    session.commit()

    # Hitung Scope untuk Guru Pendamping
    scope_p, _ = compute_active_scope(session, user_p)
    assert "k-1" in scope_p.allowed_keanggotaan_ids
    assert "k-2" not in scope_p.allowed_keanggotaan_ids
    assert "k-3" not in scope_p.allowed_keanggotaan_ids

    # Hitung Scope untuk Guru Utama (Wajib mendapatkan K2 & K3 lewat Fallback)
    scope_u, _ = compute_active_scope(session, user_u)
    assert "k-1" not in scope_u.allowed_keanggotaan_ids
    assert "k-2" in scope_u.allowed_keanggotaan_ids
    assert "k-3" in scope_u.allowed_keanggotaan_ids
