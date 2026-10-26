import json
from typing import Dict, Any, List, Tuple, Optional
from sqlalchemy import and_, or_, text
from sqlmodel import Session, select

from app.models import (
    Madrasah, User, UserRole, Perangkat, AuditLog, ServerSeqCounter,
    RefItem, RefWilayah, TahunAjaran, Semester, Mapel, Rombel,
    Pengampu, PengampuSiswa, KeanggotaanRombel, RiwayatStatusSiswa,
    JenisNilai, BobotNilai, PengaturanKkm, Nilai, Absensi,
    Siswa, SiswaDetail, SiswaOrtu, Alamat, SiswaSensitif, SiswaBerkas,
    Guru, GuruDetail, GuruSensitif, GuruBerkas,
    current_time_epoch_ms
)
from app.schemas.sync import (
    SyncChangeItem, SyncPushResultItem, SyncPullChangeItem, ActiveScope
)

# Pemetaan urutan dependensi tabel sesuai CLAUDE.md Bagian 6.1
TABLE_TIERS = {
    # Tingkat 1
    "ref_item": 1,
    "ref_wilayah": 1,
    "tahun_ajaran": 1,
    "semester": 1,
    "mapel": 1,
    "jenis_nilai": 1,
    # Tingkat 2
    "guru": 2,
    "guru_detail": 2,
    "guru_sensitif": 2,
    "madrasah": 2,
    "user": 2,
    "user_role": 2,
    # Tingkat 3
    "rombel": 3,
    "siswa": 3,
    "siswa_detail": 3,
    "siswa_ortu": 3,
    "siswa_sensitif": 3,
    "alamat": 3,
    # Tingkat 4
    "keanggotaan_rombel": 4,
    "riwayat_status_siswa": 4,
    "pengampu": 4,
    "pengampu_siswa": 4,
    "bobot_nilai": 4,
    "pengaturan_kkm": 4,
    # Tingkat 5
    "nilai": 5,
    "absensi": 5,
    "siswa_berkas": 5,
    "guru_berkas": 5,
}

MODEL_MAP = {
    "madrasah": Madrasah,
    "user": User,
    "user_role": UserRole,
    "ref_item": RefItem,
    "ref_wilayah": RefWilayah,
    "tahun_ajaran": TahunAjaran,
    "semester": Semester,
    "mapel": Mapel,
    "rombel": Rombel,
    "pengampu": Pengampu,
    "pengampu_siswa": PengampuSiswa,
    "keanggotaan_rombel": KeanggotaanRombel,
    "riwayat_status_siswa": RiwayatStatusSiswa,
    "jenis_nilai": JenisNilai,
    "bobot_nilai": BobotNilai,
    "pengaturan_kkm": PengaturanKkm,
    "nilai": Nilai,
    "absensi": Absensi,
    "siswa": Siswa,
    "siswa_detail": SiswaDetail,
    "siswa_ortu": SiswaOrtu,
    "alamat": Alamat,
    "siswa_sensitif": SiswaSensitif,
    "siswa_berkas": SiswaBerkas,
    "guru": Guru,
    "guru_detail": GuruDetail,
    "guru_sensitif": GuruSensitif,
    "guru_berkas": GuruBerkas,
}

COLUMN_MERGE_TABLES = {"siswa_detail", "siswa_ortu", "alamat", "guru_detail"}

def get_next_server_seq(session: Session) -> int:
    """Mengambil dan menambah nomor urut server_seq secara monotonik."""
    counter = session.get(ServerSeqCounter, 1)
    if not counter:
        counter = ServerSeqCounter(id=1, current_seq=1001)
        session.add(counter)
    else:
        counter.current_seq += 1
    session.flush()
    return counter.current_seq

def merge_column_ts(
    existing_row: Any,
    incoming_data: Dict[str, Any],
    is_wali_kelas: bool = False
) -> None:
    """Menggabungkan nilai per kolom berdasarkan timestamp kolom_ts."""
    try:
        existing_ts = json.loads(getattr(existing_row, "kolom_ts", "{}") or "{}")
    except Exception:
        existing_ts = {}
        
    try:
        incoming_ts = json.loads(incoming_data.get("kolom_ts", "{}") or "{}")
    except Exception:
        incoming_ts = {}

    merged_ts = dict(existing_ts)
    
    for col, incoming_time in incoming_ts.items():
        if col in incoming_data:
            existing_time = existing_ts.get(col, 0)
            if incoming_time >= existing_time:
                setattr(existing_row, col, incoming_data[col])
                merged_ts[col] = incoming_time

    existing_row.kolom_ts = json.dumps(merged_ts)
    if is_wali_kelas and hasattr(existing_row, "diubah_wali_kelas"):
        existing_row.diubah_wali_kelas = 1

def process_push_changes(
    session: Session,
    user: User,
    device_id: str,
    changes: List[SyncChangeItem]
) -> List[SyncPushResultItem]:
    """
    Memproses batch sync push sesuai urutan Foreign Key dan aturan resolusi konflik.
    """
    # 1. Sort changes berdasarkan Tingkat Foreign Key (1 -> 5)
    sorted_changes = sorted(
        changes,
        key=lambda c: TABLE_TIERS.get(c.table, 99)
    )
    
    results: List[SyncPushResultItem] = []
    
    for item in sorted_changes:
        tbl_name = item.table.lower()
        model_cls = MODEL_MAP.get(tbl_name)
        if not model_cls:
            results.append(SyncPushResultItem(
                local_seq=item.local_seq,
                status="REJECTED",
                message=f"Tabel {tbl_name} tidak dikenali"
            ))
            continue
            
        row_data = dict(item.row)
        row_id = row_data.get("id")
        
        # Validasi Business Key Upsert untuk Nilai
        if tbl_name == "nilai":
            keanggotaan_id = row_data.get("keanggotaan_id")
            mapel_id = row_data.get("mapel_id")
            semester_id = row_data.get("semester_id")
            jenis_nilai_id = row_data.get("jenis_nilai_id")
            urutan_ke = row_data.get("urutan_ke")
            
            # Cek baris aktif di server dengan kombinasi business key yang sama
            existing_bk = session.exec(
                select(Nilai).where(
                    Nilai.keanggotaan_id == keanggotaan_id,
                    Nilai.mapel_id == mapel_id,
                    Nilai.semester_id == semester_id,
                    Nilai.jenis_nilai_id == jenis_nilai_id,
                    Nilai.urutan_ke == urutan_ke,
                    Nilai.deleted == 0
                )
            ).first()
            
            if existing_bk and existing_bk.id != row_id:
                # Tabrakan Business Key dengan UUID berbeda
                canonical_id = existing_bk.id
                incoming_updated_at = row_data.get("updated_at", 0)
                
                # Catat versi kalah di audit log
                session.add(AuditLog(
                    device_id=device_id,
                    user_id=user.id,
                    aksi="CONFLICT_BUSINESS_KEY_NILAI",
                    tabel="nilai",
                    baris_id=canonical_id,
                    data_lama=json.dumps({"nilai": existing_bk.nilai, "updated_at": existing_bk.updated_at}),
                    data_baru=json.dumps({"incoming_nilai": row_data.get("nilai"), "incoming_id": row_id}),
                    keterangan="Tabrakan Business Key Nilai dari entri offline"
                ))
                
                if incoming_updated_at >= existing_bk.updated_at:
                    existing_bk.nilai = row_data.get("nilai", existing_bk.nilai)
                    existing_bk.tanggal = row_data.get("tanggal", existing_bk.tanggal)
                    existing_bk.keterangan = row_data.get("keterangan", existing_bk.keterangan)
                    existing_bk.diinput_oleh_guru_id = row_data.get("diinput_oleh_guru_id", existing_bk.diinput_oleh_guru_id)
                    existing_bk.updated_at = incoming_updated_at
                    existing_bk.device_id = device_id
                    existing_bk.deleted = row_data.get("deleted", 0)
                
                seq = get_next_server_seq(session)
                existing_bk.server_seq = seq
                session.add(existing_bk)
                session.commit()
                
                results.append(SyncPushResultItem(
                    local_seq=item.local_seq,
                    status="MERGED_BY_BUSINESS_KEY",
                    canonical_id=canonical_id,
                    server_seq=seq,
                    message="Digabungkan dengan Business Key Nilai di server"
                ))
                continue

        # Validasi Business Key Upsert untuk Absensi
        if tbl_name == "absensi":
            keanggotaan_id = row_data.get("keanggotaan_id")
            tanggal = row_data.get("tanggal")
            
            existing_bk = session.exec(
                select(Absensi).where(
                    Absensi.keanggotaan_id == keanggotaan_id,
                    Absensi.tanggal == tanggal,
                    Absensi.deleted == 0
                )
            ).first()
            
            if existing_bk and existing_bk.id != row_id:
                canonical_id = existing_bk.id
                incoming_updated_at = row_data.get("updated_at", 0)
                
                session.add(AuditLog(
                    device_id=device_id,
                    user_id=user.id,
                    aksi="CONFLICT_BUSINESS_KEY_ABSENSI",
                    tabel="absensi",
                    baris_id=canonical_id,
                    data_lama=json.dumps({"status": existing_bk.status}),
                    data_baru=json.dumps({"incoming_status": row_data.get("status")}),
                    keterangan="Tabrakan Business Key Absensi dari entri offline"
                ))
                
                if incoming_updated_at >= existing_bk.updated_at:
                    existing_bk.status = row_data.get("status", existing_bk.status)
                    existing_bk.keterangan = row_data.get("keterangan", existing_bk.keterangan)
                    existing_bk.diinput_oleh_user_id = row_data.get("diinput_oleh_user_id", existing_bk.diinput_oleh_user_id)
                    existing_bk.updated_at = incoming_updated_at
                    existing_bk.device_id = device_id
                    existing_bk.deleted = row_data.get("deleted", 0)
                    
                seq = get_next_server_seq(session)
                existing_bk.server_seq = seq
                session.add(existing_bk)
                session.commit()
                
                results.append(SyncPushResultItem(
                    local_seq=item.local_seq,
                    status="MERGED_BY_BUSINESS_KEY",
                    canonical_id=canonical_id,
                    server_seq=seq,
                    message="Digabungkan dengan Business Key Absensi di server"
                ))
                continue

        # Normal LWW (Last-Write-Wins) / Column-Merge Upsert
        existing_row = session.get(model_cls, row_id)
        seq = get_next_server_seq(session)
        row_data["server_seq"] = seq
        row_data["device_id"] = device_id
        
        if existing_row:
            incoming_updated_at = row_data.get("updated_at", 0)
            if tbl_name in COLUMN_MERGE_TABLES:
                # Merge per kolom
                merge_column_ts(existing_row, row_data, is_wali_kelas=False)
                existing_row.updated_at = max(existing_row.updated_at, incoming_updated_at)
                existing_row.server_seq = seq
                existing_row.device_id = device_id
                session.add(existing_row)
            else:
                if incoming_updated_at >= existing_row.updated_at:
                    for k, v in row_data.items():
                        if hasattr(existing_row, k):
                            setattr(existing_row, k, v)
                    existing_row.server_seq = seq
                    session.add(existing_row)
        else:
            # Baris baru
            new_instance = model_cls(**row_data)
            session.add(new_instance)
            
        session.commit()
        results.append(SyncPushResultItem(
            local_seq=item.local_seq,
            status="APPLIED",
            canonical_id=row_id,
            server_seq=seq
        ))
        
    return results

def compute_active_scope(session: Session, user: User) -> Tuple[ActiveScope, List[str]]:
    """
    Menghitung active_scope untuk user dan aturan fallback Guru Utama:
    - allowed_keanggotaan_ids
    - wali_rombel_ids
    - pengampu_ids
    """
    madrasah = session.exec(select(Madrasah)).first()
    active_sem_id = madrasah.semester_aktif_id if madrasah else None
    
    # Cek role
    roles = session.exec(select(UserRole).where(UserRole.user_id == user.id)).all()
    role_names = {r.role for r in roles}
    
    is_admin = "admin" in role_names
    is_kepala = "kepala" in role_names
    
    # Wali Rombel
    wali_rombels = []
    if user.guru_id:
        wali_rombels = session.exec(
            select(Rombel).where(Rombel.wali_guru_id == user.guru_id)
        ).all()
    wali_rombel_ids = [r.id for r in wali_rombels]
    
    # Pengampu aktif
    pengampus = []
    if user.guru_id:
        pengampus = session.exec(
            select(Pengampu).where(
                Pengampu.guru_id == user.guru_id,
                Pengampu.semester_id == active_sem_id,
                Pengampu.tanggal_selesai == None,
                Pengampu.deleted == 0
            )
        ).all()
    pengampu_ids = [p.id for p in pengampus]
    
    allowed_keanggotaan_ids = set()
    
    if is_admin or is_kepala:
        # Admin & Kepala mendapatkan seluruh keanggotaan aktif
        all_keanggotaan = session.exec(
            select(KeanggotaanRombel).where(
                KeanggotaanRombel.tanggal_keluar == None,
                KeanggotaanRombel.deleted == 0
            )
        ).all()
        allowed_keanggotaan_ids.update([k.id for k in all_keanggotaan])
    else:
        # Siswa di rombel perwalian wali kelas
        if wali_rombel_ids:
            wali_keanggotaan = session.exec(
                select(KeanggotaanRombel).where(
                    KeanggotaanRombel.rombel_id.in_(wali_rombel_ids),
                    KeanggotaanRombel.tanggal_keluar == None,
                    KeanggotaanRombel.deleted == 0
                )
            ).all()
            allowed_keanggotaan_ids.update([k.id for k in wali_keanggotaan])
            
        # Logika Pengampu & Fallback Guru Utama
        for p in pengampus:
            if p.cakupan == "seluruh":
                # Semua siswa di rombel
                r_keanggotaan = session.exec(
                    select(KeanggotaanRombel).where(
                        KeanggotaanRombel.rombel_id == p.rombel_id,
                        KeanggotaanRombel.tanggal_keluar == None,
                        KeanggotaanRombel.deleted == 0
                    )
                ).all()
                allowed_keanggotaan_ids.update([k.id for k in r_keanggotaan])
            else:
                # Mode sebagian: ambil pengampu_siswa
                mapped_ps = session.exec(
                    select(PengampuSiswa).where(
                        PengampuSiswa.pengampu_id == p.id,
                        PengampuSiswa.deleted == 0
                    )
                ).all()
                allowed_keanggotaan_ids.update([m.keanggotaan_id for m in mapped_ps])
                
                # Aturan Fallback Guru Utama
                if p.peran == "utama":
                    # Cari seluruh anggota rombel aktif
                    all_rombel_k = session.exec(
                        select(KeanggotaanRombel).where(
                            KeanggotaanRombel.rombel_id == p.rombel_id,
                            KeanggotaanRombel.tanggal_keluar == None,
                            KeanggotaanRombel.deleted == 0
                        )
                    ).all()
                    
                    # Cari semua pengampu aktif untuk (mapel, rombel, semester) yang sama
                    all_active_p = session.exec(
                        select(Pengampu).where(
                            Pengampu.mapel_id == p.mapel_id,
                            Pengampu.rombel_id == p.rombel_id,
                            Pengampu.semester_id == p.semester_id,
                            Pengampu.tanggal_selesai == None,
                            Pengampu.deleted == 0
                        )
                    ).all()
                    p_ids = [ap.id for ap in all_active_p]
                    
                    # Ambil semua siswa yang sudah terpetakan di pengampu aktif tersebut
                    already_mapped = set()
                    if p_ids:
                        mapped_all = session.exec(
                            select(PengampuSiswa).where(
                                PengampuSiswa.pengampu_id.in_(p_ids),
                                PengampuSiswa.deleted == 0
                            )
                        ).all()
                        already_mapped = {m.keanggotaan_id for m in mapped_all}
                        
                    # Tambahkan fallback siswa yang belum terpetakan ke Guru Utama
                    for k in all_rombel_k:
                        if k.id not in already_mapped:
                            allowed_keanggotaan_ids.add(k.id)

    scope = ActiveScope(
        semester_aktif_id=active_sem_id,
        wali_rombel_ids=wali_rombel_ids,
        pengampu_ids=pengampu_ids,
        allowed_keanggotaan_ids=list(allowed_keanggotaan_ids)
    )
    return scope, list(role_names)
