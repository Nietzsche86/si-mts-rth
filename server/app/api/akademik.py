from typing import List, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select

from app.api.deps import get_current_admin_user
from app.db.engine import get_session
from app.models import (
    User, Madrasah, TahunAjaran, Semester, Rombel,
    Pengampu, KeanggotaanRombel, RiwayatStatusSiswa, AuditLog,
    generate_uuid, current_time_epoch_ms
)
from app.services.sync_service import get_next_server_seq

router = APIRouter(prefix="/akademik", tags=["akademik"])

# ============================================================================
# Schemas
# ============================================================================

class NaikKelasItem(BaseModel):
    siswa_id: str
    status: str  # 'naik_kelas' | 'tinggal_kelas' | 'lulus'
    rombel_tujuan_id: Optional[str] = None

class NaikKelasMassalRequest(BaseModel):
    rombel_asal_id: str
    semester_id: str
    tanggal: str  # YYYY-MM-DD
    catatan: Optional[str] = None
    mutasi_items: List[NaikKelasItem]

class PergantianTahunRequest(BaseModel):
    tahun_ajaran_lama_id: str
    tahun_ajaran_baru_nama: str  # e.g. "2027/2028"
    semester_baru_jenis: str  # 'ganjil' | 'genap'
    tanggal_mulai: str  # YYYY-MM-DD
    tanggal_selesai: str  # YYYY-MM-DD
    salin_rombel: bool = True
    salin_pengampu: bool = True
    kunci_semester_lama: bool = True

# ============================================================================
# Endpoints
# ============================================================================

@router.post("/naik-kelas-massal")
def naik_kelas_massal(
    req: NaikKelasMassalRequest,
    admin: User = Depends(get_current_admin_user),
    session: Session = Depends(get_session)
):
    """
    Mutasi massal naik kelas, tinggal kelas, atau kelulusan siswa per rombel.
    Mengeksekusi penutupan keanggotaan lama, pembuatan keanggotaan baru,
    pencatatan riwayat_status_siswa, dan audit_log dalam satu transaksi WAL.
    """
    semester = session.get(Semester, req.semester_id)
    if not semester or semester.deleted == 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Semester tidak ditemukan"
        )
    if semester.dikunci == 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Semester sudah dikunci, mutasi status siswa ditolak"
        )

    rombel_asal = session.get(Rombel, req.rombel_asal_id)
    if not rombel_asal or rombel_asal.deleted == 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rombel asal tidak ditemukan"
        )

    now_epoch = current_time_epoch_ms()
    processed_count = 0

    for item in req.mutasi_items:
        # Cari keanggotaan rombel lama yang masih aktif
        keanggotaan_lama = session.exec(
            select(KeanggotaanRombel).where(
                KeanggotaanRombel.siswa_id == item.siswa_id,
                KeanggotaanRombel.rombel_id == req.rombel_asal_id,
                KeanggotaanRombel.tanggal_keluar == None,
                KeanggotaanRombel.deleted == 0
            )
        ).first()

        if not keanggotaan_lama:
            continue

        # 1. Tutup keanggotaan lama
        keanggotaan_lama.tanggal_keluar = req.tanggal
        keanggotaan_lama.alasan_keluar = item.status
        keanggotaan_lama.updated_at = now_epoch
        keanggotaan_lama.server_seq = get_next_server_seq(session)
        session.add(keanggotaan_lama)

        # 2. Jika naik kelas atau tinggal kelas, buat keanggotaan rombel baru
        new_keanggotaan_id: Optional[str] = None
        if item.status in ("naik_kelas", "tinggal_kelas") and item.rombel_tujuan_id:
            new_keanggotaan_id = generate_uuid()
            new_keanggotaan = KeanggotaanRombel(
                id=new_keanggotaan_id,
                siswa_id=item.siswa_id,
                rombel_id=item.rombel_tujuan_id,
                tanggal_masuk=req.tanggal,
                sumber_keanggotaan_id=keanggotaan_lama.id,
                device_id="server",
                created_at=now_epoch,
                updated_at=now_epoch,
                server_seq=get_next_server_seq(session)
            )
            session.add(new_keanggotaan)

        # 3. Catat ke riwayat_status_siswa
        riwayat_id = generate_uuid()
        riwayat = RiwayatStatusSiswa(
            id=riwayat_id,
            siswa_id=item.siswa_id,
            tanggal=req.tanggal,
            jenis_status=item.status,
            rombel_asal_id=req.rombel_asal_id,
            rombel_tujuan_id=item.rombel_tujuan_id,
            catatan=req.catatan or f"Mutasi massal ({item.status}) dari rombel {rombel_asal.nama}",
            device_id="server",
            created_at=now_epoch,
            updated_at=now_epoch,
            server_seq=get_next_server_seq(session)
        )
        session.add(riwayat)
        processed_count += 1

    # 4. Catat Audit Log
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=admin.id,
        device_id="server",
        aksi="NAIK_KELAS_MASSAL",
        tabel="keanggotaan_rombel",
        baris_id=req.rombel_asal_id,
        keterangan=f"Mutasi massal rombel {rombel_asal.nama}: {processed_count} siswa diproses oleh admin {admin.username}"
    )
    session.add(audit)
    session.commit()

    return {
        "success": True,
        "rombel_asal_id": req.rombel_asal_id,
        "processed_count": processed_count,
        "message": f"Berhasil memproses mutasi massal {processed_count} siswa"
    }


@router.post("/pergantian-tahun")
def pergantian_tahun(
    req: PergantianTahunRequest,
    admin: User = Depends(get_current_admin_user),
    session: Session = Depends(get_session)
):
    """
    Pergantian tahun ajaran baru & semester:
    - Nonaktifkan tahun ajaran lama dan kunci semester lama.
    - Buat tahun ajaran baru & semester baru.
    - Salin rombel dari tahun lalu (opsional).
    - Salin pengampu guru dari semester lalu (opsional).
    - Catat audit log seluruh proses dalam satu transaksi.
    """
    tahun_lama = session.get(TahunAjaran, req.tahun_ajaran_lama_id)
    if not tahun_lama or tahun_lama.deleted == 1:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tahun ajaran lama tidak ditemukan"
        )

    now_epoch = current_time_epoch_ms()

    # 1. Nonaktifkan tahun ajaran lama
    tahun_lama.aktif = 0
    tahun_lama.updated_at = now_epoch
    tahun_lama.server_seq = get_next_server_seq(session)
    session.add(tahun_lama)

    # 2. Kunci semester lama jika diminta
    semesters_old = session.exec(
        select(Semester).where(
            Semester.tahun_ajaran_id == req.tahun_ajaran_lama_id,
            Semester.deleted == 0
        )
    ).all()

    if req.kunci_semester_lama:
        for sem in semesters_old:
            sem.dikunci = 1
            sem.updated_at = now_epoch
            sem.server_seq = get_next_server_seq(session)
            session.add(sem)

    # 3. Buat Tahun Ajaran baru
    new_tahun_id = generate_uuid()
    new_tahun = TahunAjaran(
        id=new_tahun_id,
        nama=req.tahun_ajaran_baru_nama,
        tanggal_mulai=req.tanggal_mulai,
        tanggal_selesai=req.tanggal_selesai,
        aktif=1,
        device_id="server",
        created_at=now_epoch,
        updated_at=now_epoch,
        server_seq=get_next_server_seq(session)
    )
    session.add(new_tahun)

    # 4. Buat Semester baru
    new_sem_id = generate_uuid()
    new_sem = Semester(
        id=new_sem_id,
        tahun_ajaran_id=new_tahun_id,
        jenis=req.semester_baru_jenis,
        tanggal_mulai=req.tanggal_mulai,
        tanggal_selesai=req.tanggal_selesai,
        dikunci=0,
        device_id="server",
        created_at=now_epoch,
        updated_at=now_epoch,
        server_seq=get_next_server_seq(session)
    )
    session.add(new_sem)

    # Perbarui semester aktif di tabel madrasah
    madrasah = session.exec(select(Madrasah)).first()
    if madrasah:
        madrasah.semester_aktif_id = new_sem_id
        madrasah.updated_at = now_epoch
        madrasah.server_seq = get_next_server_seq(session)
        session.add(madrasah)

    # 5. Salin rombel jika diminta
    rombel_map = {}  # old_rombel_id -> new_rombel_id
    rombel_copied_count = 0
    if req.salin_rombel:
        old_rombels = session.exec(
            select(Rombel).where(
                Rombel.tahun_ajaran_id == req.tahun_ajaran_lama_id,
                Rombel.deleted == 0
            )
        ).all()

        for r in old_rombels:
            new_r_id = generate_uuid()
            new_r = Rombel(
                id=new_r_id,
                tahun_ajaran_id=new_tahun_id,
                nama=r.nama,
                tingkat=r.tingkat,
                wali_guru_id=r.wali_guru_id,
                device_id="server",
                created_at=now_epoch,
                updated_at=now_epoch,
                server_seq=get_next_server_seq(session)
            )
            session.add(new_r)
            rombel_map[r.id] = new_r_id
            rombel_copied_count += 1

    # 6. Salin pengampu jika diminta
    pengampu_copied_count = 0
    if req.salin_pengampu:
        old_sem_ids = [s.id for s in semesters_old]
        if old_sem_ids:
            old_pengampus = session.exec(
                select(Pengampu).where(
                    Pengampu.semester_id.in_(old_sem_ids),
                    Pengampu.tanggal_selesai == None,
                    Pengampu.deleted == 0
                )
            ).all()

            for p in old_pengampus:
                target_rombel_id = rombel_map.get(p.rombel_id, p.rombel_id)
                new_p_id = generate_uuid()
                new_p = Pengampu(
                    id=new_p_id,
                    guru_id=p.guru_id,
                    mapel_id=p.mapel_id,
                    rombel_id=target_rombel_id,
                    semester_id=new_sem_id,
                    cakupan=p.cakupan,
                    peran=p.peran,
                    tanggal_mulai=req.tanggal_mulai,
                    device_id="server",
                    created_at=now_epoch,
                    updated_at=now_epoch,
                    server_seq=get_next_server_seq(session)
                )
                session.add(new_p)
                pengampu_copied_count += 1

    # 7. Audit log
    audit = AuditLog(
        id=generate_uuid(),
        waktu=now_epoch,
        user_id=admin.id,
        device_id="server",
        aksi="PERGANTIAN_TAHUN",
        tabel="tahun_ajaran",
        baris_id=new_tahun_id,
        keterangan=(
            f"Pergantian tahun ajaran ke {req.tahun_ajaran_baru_nama} ({req.semester_baru_jenis}) "
            f"oleh admin {admin.username}. Rombel disalin: {rombel_copied_count}, Pengampu disalin: {pengampu_copied_count}"
        )
    )
    session.add(audit)
    session.commit()

    return {
        "success": True,
        "tahun_ajaran_id": new_tahun_id,
        "semester_id": new_sem_id,
        "rombel_copied_count": rombel_copied_count,
        "pengampu_copied_count": pengampu_copied_count,
        "message": f"Tahun ajaran {req.tahun_ajaran_baru_nama} berhasil diaktifkan"
    }
