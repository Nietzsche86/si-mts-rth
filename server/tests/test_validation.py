import pytest
from sqlmodel import Session, select
from app.models import (
    User, UserRole, Guru, Rombel, KeanggotaanRombel, Siswa, SiswaDetail,
    Semester, Nilai, current_time_epoch_ms
)
from app.schemas.sync import SyncChangeItem
from app.services.sync_service import process_push_changes
from app.db.seeder import seed_initial_data

def test_seeder_idempotency(session: Session):
    # Menjalankan seeder pertama kali
    res1 = seed_initial_data(session)
    assert res1["created"] > 0
    
    # Menjalankan seeder kedua kali tidak boleh error atau menduplikasi data
    res2 = seed_initial_data(session)
    assert res2["created"] == 0
    assert res2["skipped"] > 0

def test_push_admin_only_table_by_non_admin_is_rejected(session: Session):
    seed_initial_data(session)
    
    # User ahmad adalah guru/wali kelas (bukan admin)
    guru_user = session.exec(select(User).where(User.username == "ahmad")).first()
    assert guru_user is not None
    
    now = current_time_epoch_ms()
    changes = [
        SyncChangeItem(
            local_seq=1,
            table="siswa",
            operation="UPSERT",
            row={
                "id": "siswa-test-reject-01",
                "nis": "99999",
                "nama_lengkap": "Siswa Ilegal",
                "jk": "L",
                "status_aktif": "aktif",
                "created_at": now,
                "updated_at": now,
                "deleted": 0,
                "device_id": "test-device"
            }
        )
    ]
    
    results = process_push_changes(session, guru_user, "test-device", changes)
    assert len(results) == 1
    assert results[0].status == "REJECTED"
    assert "Hanya Admin yang berhak" in (results[0].message or "")

def test_push_locked_semester_is_rejected(session: Session):
    seed_initial_data(session)
    
    # Ambil semester dan kunci
    sem = session.exec(select(Semester).where(Semester.id == "sem-2026-ganjil")).first()
    assert sem is not None
    sem.dikunci = 1
    session.add(sem)
    session.commit()
    
    admin_user = session.exec(select(User).where(User.username == "admin")).first()
    now = current_time_epoch_ms()
    
    changes = [
        SyncChangeItem(
            local_seq=1,
            table="nilai",
            operation="UPSERT",
            row={
                "id": "nilai-locked-test-01",
                "keanggotaan_id": "k-locked-test-01",
                "mapel_id": "mapel-bahasa_arab",
                "semester_id": "sem-2026-ganjil",
                "jenis_nilai_id": "jn-uh",
                "urutan_ke": 1,
                "nilai": 80.0,
                "created_at": now,
                "updated_at": now,
                "deleted": 0,
                "device_id": "test-device"
            }
        )
    ]
    
    results = process_push_changes(session, admin_user, "test-device", changes)
    assert len(results) == 1
    assert results[0].status == "REJECTED"
    assert "sudah dikunci" in (results[0].message or "")

def test_push_wali_kelas_forces_flag_diubah_wali_kelas(session: Session):
    seed_initial_data(session)
    
    # Guru ahmad adalah wali kelas 7A
    guru_user = session.exec(select(User).where(User.username == "ahmad")).first()
    now = current_time_epoch_ms()
    
    # Buat siswa dan keanggotaan aktif di 7A
    siswa = Siswa(
        id="siswa-7a-test-01",
        nis="88881",
        nama_lengkap="Siswa Binaan 7A",
        jk="L",
        status_aktif="aktif",
        created_at=now,
        updated_at=now,
        device_id="test",
        server_seq=1
    )
    session.add(siswa)
    
    keanggotaan = KeanggotaanRombel(
        id="k-7a-test-01",
        siswa_id=siswa.id,
        rombel_id="rombel-7a",
        tanggal_masuk="2026-07-15",
        tanggal_keluar=None,
        deleted=0,
        device_id="test",
        server_seq=1
    )
    session.add(keanggotaan)
    session.commit()
    
    # Wali kelas mengubah data detail siswa binaannya
    changes = [
        SyncChangeItem(
            local_seq=1,
            table="siswa_detail",
            operation="UPSERT",
            row={
                "id": "sd-7a-test-01",
                "siswa_id": siswa.id,
                "tempat_lahir": "Semarang",
                "tanggal_lahir": "2012-05-10",
                "agama_kode": "islam",
                "diubah_wali_kelas": 0, # HP mengirim 0
                "kolom_ts": '{"tempat_lahir": 1761447600000}',
                "created_at": now,
                "updated_at": now,
                "deleted": 0,
                "device_id": "test-device"
            }
        )
    ]
    
    results = process_push_changes(session, guru_user, "test-device", changes)
    assert len(results) == 1
    assert results[0].status == "APPLIED"
    
    # Server harus memaksa diubah_wali_kelas = 1
    sd_saved = session.get(SiswaDetail, "sd-7a-test-01")
    assert sd_saved is not None
    assert sd_saved.diubah_wali_kelas == 1

def test_push_wali_kelas_rejected_for_student_outside_perwalian(session: Session):
    seed_initial_data(session)
    
    # Guru ahmad (wali 7A) mencoba mengubah siswa di rombel 7B (bukan binaannya)
    guru_user = session.exec(select(User).where(User.username == "ahmad")).first()
    now = current_time_epoch_ms()
    
    siswa_7b = Siswa(
        id="siswa-7b-test-01",
        nis="88882",
        nama_lengkap="Siswa 7B",
        jk="P",
        status_aktif="aktif",
        created_at=now,
        updated_at=now,
        device_id="test",
        server_seq=1
    )
    session.add(siswa_7b)
    
    keanggotaan_7b = KeanggotaanRombel(
        id="k-7b-test-01",
        siswa_id=siswa_7b.id,
        rombel_id="rombel-7b",
        tanggal_masuk="2026-07-15",
        tanggal_keluar=None,
        deleted=0,
        device_id="test",
        server_seq=1
    )
    session.add(keanggotaan_7b)
    session.commit()
    
    changes = [
        SyncChangeItem(
            local_seq=1,
            table="siswa_detail",
            operation="UPSERT",
            row={
                "id": "sd-7b-illegal-01",
                "siswa_id": siswa_7b.id,
                "tempat_lahir": "Kudus",
                "kolom_ts": '{"tempat_lahir": 1761447600000}',
                "created_at": now,
                "updated_at": now,
                "deleted": 0,
                "device_id": "test-device"
            }
        )
    ]
    
    results = process_push_changes(session, guru_user, "test-device", changes)
    assert len(results) == 1
    assert results[0].status == "REJECTED"
    assert "Hanya Wali Kelas" in (results[0].message or "")
