from sqlmodel import Session, select
from app.models import User, Nilai, AuditLog
from app.schemas.sync import SyncChangeItem
from app.services.sync_service import process_push_changes

def test_sync_business_key_upsert_nilai(session: Session):
    # Setup user
    user = User(
        username="guru_test",
        pin_hash="dummy",
        aktif=1,
        device_id="hp-1"
    )
    session.add(user)
    session.commit()

    keanggotaan_id = "k-001"
    mapel_id = "mapel-arab"
    semester_id = "sem-1"
    jenis_nilai_id = "jenis-uh"
    urutan_ke = 1

    # 1. Guru 1 push nilai UH 1 (UUID A, nilai 80.0, waktu T1)
    change_1 = SyncChangeItem(
        local_seq=1,
        table="nilai",
        operation="UPSERT",
        row={
            "id": "uuid-guru-1",
            "keanggotaan_id": keanggotaan_id,
            "mapel_id": mapel_id,
            "semester_id": semester_id,
            "jenis_nilai_id": jenis_nilai_id,
            "urutan_ke": urutan_ke,
            "nilai": 80.0,
            "tanggal": "2026-10-26",
            "keterangan": "UH 1",
            "sumber_nilai_id": None,
            "diinput_oleh_guru_id": "guru-1",
            "created_at": 1000,
            "updated_at": 1000,
            "deleted": 0,
            "device_id": "hp-1"
        }
    )

    results_1 = process_push_changes(session, user, "hp-1", [change_1])
    assert len(results_1) == 1
    assert results_1[0].status == "APPLIED"
    assert results_1[0].canonical_id == "uuid-guru-1"

    # 2. Guru 2 push nilai UH 1 yang sama secara offline (UUID B, nilai 90.0, waktu T2 > T1)
    change_2 = SyncChangeItem(
        local_seq=10,
        table="nilai",
        operation="UPSERT",
        row={
            "id": "uuid-guru-2",
            "keanggotaan_id": keanggotaan_id,
            "mapel_id": mapel_id,
            "semester_id": semester_id,
            "jenis_nilai_id": jenis_nilai_id,
            "urutan_ke": urutan_ke,
            "nilai": 90.0,
            "tanggal": "2026-10-26",
            "keterangan": "UH 1 Revisi",
            "sumber_nilai_id": None,
            "diinput_oleh_guru_id": "guru-2",
            "created_at": 1100,
            "updated_at": 1100,
            "deleted": 0,
            "device_id": "hp-2"
        }
    )

    results_2 = process_push_changes(session, user, "hp-2", [change_2])
    assert len(results_2) == 1
    # Wajib bernilai MERGED_BY_BUSINESS_KEY dan canonical_id tetap UUID-A milik server
    assert results_2[0].status == "MERGED_BY_BUSINESS_KEY"
    assert results_2[0].canonical_id == "uuid-guru-1"

    # Verifikasi baris di database
    db_nilai = session.get(Nilai, "uuid-guru-1")
    assert db_nilai is not None
    assert db_nilai.nilai == 90.0
    assert db_nilai.diinput_oleh_guru_id == "guru-2"

    # Verifikasi audit log tercatat
    audit = session.exec(select(AuditLog).where(AuditLog.aksi == "CONFLICT_BUSINESS_KEY_NILAI")).first()
    assert audit is not None
    assert audit.baris_id == "uuid-guru-1"
