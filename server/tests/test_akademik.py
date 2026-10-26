import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session, select
from app.db.seeder import seed_initial_data
from app.models import (
    User, Semester, TahunAjaran, Rombel, KeanggotaanRombel,
    RiwayatStatusSiswa, Pengampu, Siswa, current_time_epoch_ms
)

def _get_admin_token(client: TestClient) -> str:
    login_resp = client.post("/api/v1/auth/login", json={
        "username": "admin",
        "pin": "123456",
        "device_id": "test-operator-laptop",
        "nama_perangkat": "Laptop Admin"
    })
    assert login_resp.status_code == 200
    return login_resp.json()["access_token"]

def _get_guru_token(client: TestClient) -> str:
    login_resp = client.post("/api/v1/auth/login", json={
        "username": "ahmad",
        "pin": "123456",
        "device_id": "hp-ahmad",
        "nama_perangkat": "HP Guru Ahmad"
    })
    assert login_resp.status_code == 200
    return login_resp.json()["access_token"]

def test_naik_kelas_massal_success(client: TestClient, session: Session):
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    # Setup 2 siswa dan keanggotaan aktif di rombel 7A
    now = current_time_epoch_ms()
    s1 = Siswa(id="siswa-001", nis="1001", nama_lengkap="Ahmad Dahlan", jk="L", status_aktif="aktif", created_at=now, updated_at=now, device_id="test", server_seq=1)
    s2 = Siswa(id="siswa-002", nis="1002", nama_lengkap="Budi Santoso", jk="L", status_aktif="aktif", created_at=now, updated_at=now, device_id="test", server_seq=2)
    session.add(s1)
    session.add(s2)

    k1 = KeanggotaanRombel(id="k-001", siswa_id="siswa-001", rombel_id="rombel-7a", tanggal_masuk="2026-07-15", created_at=now, updated_at=now, device_id="test", server_seq=3)
    k2 = KeanggotaanRombel(id="k-002", siswa_id="siswa-002", rombel_id="rombel-7a", tanggal_masuk="2026-07-15", created_at=now, updated_at=now, device_id="test", server_seq=4)
    session.add(k1)
    session.add(k2)
    session.commit()

    # Siswa 1 di kelas 7A naik ke 8A, Siswa 2 tinggal di 7A
    payload = {
        "rombel_asal_id": "rombel-7a",
        "semester_id": "sem-2026-ganjil",
        "tanggal": "2026-07-10",
        "catatan": "Kenaikan kelas tahunan 2025/2026",
        "mutasi_items": [
            {
                "siswa_id": "siswa-001",
                "status": "naik_kelas",
                "rombel_tujuan_id": "rombel-8a"
            },
            {
                "siswa_id": "siswa-002",
                "status": "tinggal_kelas",
                "rombel_tujuan_id": "rombel-7a"
            }
        ]
    }

    resp = client.post("/api/v1/akademik/naik-kelas-massal", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["processed_count"] == 2

    # Verifikasi keanggotaan lama siswa-001 ditutup
    old_keanggotaan_001 = session.exec(
        select(KeanggotaanRombel).where(
            KeanggotaanRombel.siswa_id == "siswa-001",
            KeanggotaanRombel.rombel_id == "rombel-7a"
        )
    ).first()
    assert old_keanggotaan_001 is not None
    assert old_keanggotaan_001.tanggal_keluar == "2026-07-10"
    assert old_keanggotaan_001.alasan_keluar == "naik_kelas"

    # Verifikasi keanggotaan baru siswa-001 di 8A dibuat
    new_keanggotaan_001 = session.exec(
        select(KeanggotaanRombel).where(
            KeanggotaanRombel.siswa_id == "siswa-001",
            KeanggotaanRombel.rombel_id == "rombel-8a",
            KeanggotaanRombel.tanggal_keluar == None
        )
    ).first()
    assert new_keanggotaan_001 is not None
    assert new_keanggotaan_001.sumber_keanggotaan_id == old_keanggotaan_001.id

    # Verifikasi riwayat status siswa
    riwayat_001 = session.exec(
        select(RiwayatStatusSiswa).where(
            RiwayatStatusSiswa.siswa_id == "siswa-001",
            RiwayatStatusSiswa.jenis_status == "naik_kelas"
        )
    ).first()
    assert riwayat_001 is not None
    assert riwayat_001.rombel_asal_id == "rombel-7a"
    assert riwayat_001.rombel_tujuan_id == "rombel-8a"


def test_naik_kelas_massal_locked_semester_rejected(client: TestClient, session: Session):
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    # Kunci semester
    sem = session.get(Semester, "sem-2026-ganjil")
    assert sem is not None
    sem.dikunci = 1
    session.add(sem)
    session.commit()

    payload = {
        "rombel_asal_id": "rombel-7a",
        "semester_id": "sem-2026-ganjil",
        "tanggal": "2026-07-10",
        "mutasi_items": [
            {
                "siswa_id": "siswa-001",
                "status": "naik_kelas",
                "rombel_tujuan_id": "rombel-8a"
            }
        ]
    }

    resp = client.post("/api/v1/akademik/naik-kelas-massal", json=payload, headers=headers)
    assert resp.status_code == 400
    assert "dikunci" in resp.json()["detail"]


def test_naik_kelas_non_admin_forbidden(client: TestClient, session: Session):
    seed_initial_data(session)
    token = _get_guru_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "rombel_asal_id": "rombel-7a",
        "semester_id": "sem-2026-ganjil",
        "tanggal": "2026-07-10",
        "mutasi_items": [
            {
                "siswa_id": "siswa-001",
                "status": "naik_kelas",
                "rombel_tujuan_id": "rombel-8a"
            }
        ]
    }

    resp = client.post("/api/v1/akademik/naik-kelas-massal", json=payload, headers=headers)
    assert resp.status_code == 403
    assert "hanya diizinkan untuk Admin" in resp.json()["detail"]


def test_pergantian_tahun_dan_salin_pengampu(client: TestClient, session: Session):
    seed_initial_data(session)
    token = _get_admin_token(client)
    headers = {"Authorization": f"Bearer {token}"}

    payload = {
        "tahun_ajaran_lama_id": "ta-2026-2027",
        "tahun_ajaran_baru_nama": "2027/2028",
        "semester_baru_jenis": "ganjil",
        "tanggal_mulai": "2027-07-15",
        "tanggal_selesai": "2027-12-20",
        "salin_rombel": True,
        "salin_pengampu": True,
        "kunci_semester_lama": True
    }

    resp = client.post("/api/v1/akademik/pergantian-tahun", json=payload, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["rombel_copied_count"] > 0
    assert data["pengampu_copied_count"] > 0

    # Verifikasi semester lama dikunci
    sem_lama = session.get(Semester, "sem-2026-ganjil")
    assert sem_lama is not None
    assert sem_lama.dikunci == 1

    # Verifikasi tahun ajaran baru aktif
    new_ta = session.get(TahunAjaran, data["tahun_ajaran_id"])
    assert new_ta is not None
    assert new_ta.aktif == 1
    assert new_ta.nama == "2027/2028"

    # Verifikasi rombel baru terbuat di tahun ajaran baru
    new_rombels = session.exec(
        select(Rombel).where(Rombel.tahun_ajaran_id == data["tahun_ajaran_id"])
    ).all()
    assert len(new_rombels) == data["rombel_copied_count"]

    # Verifikasi pengampu tersalin ke semester baru
    new_pengampus = session.exec(
        select(Pengampu).where(Pengampu.semester_id == data["semester_id"])
    ).all()
    assert len(new_pengampus) == data["pengampu_copied_count"]
