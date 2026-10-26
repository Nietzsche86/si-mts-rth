import uuid
import time
from typing import Dict, Any, List
from sqlmodel import Session, select

from app.core.security import hash_pin
from app.models import (
    Madrasah, TahunAjaran, Semester, Mapel, Rombel, Pengampu,
    JenisNilai, BobotNilai, PengaturanKkm, RefItem,
    Guru, User, UserRole, ServerSeqCounter,
    current_time_epoch_ms
)

def seed_initial_data(session: Session) -> Dict[str, int]:
    """
    Mengisi data master awal madrasah secara idempoten (tidak menduplikasi data).
    Mengembalikan ringkasan jumlah data yang dibuat.
    """
    now = current_time_epoch_ms()
    counts = {"created": 0, "skipped": 0}

    # Inisialisasi Counter Server Seq jika belum ada
    counter = session.get(ServerSeqCounter, 1)
    if not counter:
        session.add(ServerSeqCounter(id=1, current_seq=1000))
        session.commit()

    # 1. Tahun Ajaran & Semester
    ta = session.exec(select(TahunAjaran).where(TahunAjaran.nama == "2026/2027")).first()
    if not ta:
        ta = TahunAjaran(
            id="ta-2026-2027",
            nama="2026/2027",
            tanggal_mulai="2026-07-15",
            tanggal_selesai="2027-06-30",
            aktif=1,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=1
        )
        session.add(ta)
        session.commit()
        counts["created"] += 1
    else:
        counts["skipped"] += 1

    sem = session.exec(
        select(Semester).where(
            Semester.tahun_ajaran_id == ta.id,
            Semester.jenis == "ganjil"
        )
    ).first()
    if not sem:
        sem = Semester(
            id="sem-2026-ganjil",
            tahun_ajaran_id=ta.id,
            jenis="ganjil",
            tanggal_mulai="2026-07-15",
            tanggal_selesai="2026-12-20",
            dikunci=0,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=2
        )
        session.add(sem)
        session.commit()
        counts["created"] += 1
    else:
        counts["skipped"] += 1

    # 2. Identitas Madrasah
    madrasah = session.exec(select(Madrasah)).first()
    if not madrasah:
        madrasah = Madrasah(
            id="madrasah-mts-rth-001",
            nama="MTs Roudhotut Thowalib",
            npsn="20363000",
            nsm="121233000000",
            alamat="Jl. Pesantren No. 12, Kauman, Semarang Tengah",
            semester_aktif_id=sem.id,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=3
        )
        session.add(madrasah)
        session.commit()
        counts["created"] += 1
    else:
        if madrasah.semester_aktif_id != sem.id:
            madrasah.semester_aktif_id = sem.id
            session.add(madrasah)
            session.commit()
        counts["skipped"] += 1

    # 3. 14 Mata Pelajaran Standar Kemenag Kurikulum 2013 MTs
    mapel_list = [
        ("QURAN_HADIS", "Al-Qur'an Hadis", "A", 1),
        ("AKIDAH_AKHLAK", "Akidah Akhlak", "A", 2),
        ("FIKIH", "Fikih", "A", 3),
        ("SKI", "Sejarah Kebudayaan Islam (SKI)", "A", 4),
        ("BAHASA_ARAB", "Bahasa Arab", "A", 5),
        ("PPKN", "Pendidikan Pancasila dan Kewarganegaraan", "A", 6),
        ("BAHASA_INDONESIA", "Bahasa Indonesia", "A", 7),
        ("MATEMATIKA", "Matematika", "A", 8),
        ("IPA", "Ilmu Pengetahuan Alam", "A", 9),
        ("IPS", "Ilmu Pengetahuan Sosial", "A", 10),
        ("BAHASA_INGGRIS", "Bahasa Inggris", "A", 11),
        ("SBK", "Seni Budaya", "B", 12),
        ("PJOK", "Pendidikan Jasmani, Olahraga, dan Kesehatan", "B", 13),
        ("PRAKARYA", "Prakarya", "B", 14),
    ]

    mapel_map = {}
    for kode, nama, kelompok, urutan in mapel_list:
        existing = session.exec(select(Mapel).where(Mapel.kode == kode)).first()
        if not existing:
            m = Mapel(
                id=f"mapel-{kode.lower()}",
                kode=kode,
                nama=nama,
                kelompok=kelompok,
                urutan=urutan,
                aktif=1,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=10 + urutan
            )
            session.add(m)
            mapel_map[kode] = m
            counts["created"] += 1
        else:
            mapel_map[kode] = existing
            counts["skipped"] += 1
    session.commit()

    # 4. 7 Jenis Nilai Standar K13
    jenis_nilai_list = [
        ("TGS", "Tugas", "pengetahuan", 1),
        ("UH", "Ulangan Harian", "pengetahuan", 2),
        ("PAS", "Penilaian Akhir Semester", "pengetahuan", 3),
        ("PAT", "Penilaian Akhir Tahun", "pengetahuan", 4),
        ("PRY", "Proyek", "keterampilan", 5),
        ("PRT", "Portofolio", "keterampilan", 6),
        ("UK", "Unjuk Kerja", "keterampilan", 7),
    ]

    jn_map = {}
    for kode, nama, kat, urutan in jenis_nilai_list:
        existing = session.exec(select(JenisNilai).where(JenisNilai.kode == kode)).first()
        if not existing:
            jn = JenisNilai(
                id=f"jn-{kode.lower()}",
                kode=kode,
                nama=nama,
                kategori=kat,
                urutan=urutan,
                aktif=1,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=30 + urutan
            )
            session.add(jn)
            jn_map[kode] = jn
            counts["created"] += 1
        else:
            jn_map[kode] = existing
            counts["skipped"] += 1
    session.commit()

    # 5. Pengaturan KKM Global (75.0)
    kkm = session.exec(
        select(PengaturanKkm).where(
            PengaturanKkm.semester_id == sem.id,
            PengaturanKkm.mapel_id == None
        )
    ).first()
    if not kkm:
        kkm = PengaturanKkm(
            id="kkm-global-2026",
            semester_id=sem.id,
            mapel_id=None,
            tingkat=None,
            kkm=75.0,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=40
        )
        session.add(kkm)
        session.commit()
        counts["created"] += 1
    else:
        counts["skipped"] += 1

    # 6. Bobot Nilai Standar K13
    default_bobots = {
        "TGS": 2.0, "UH": 3.0, "PAS": 2.0, "PAT": 2.0,
        "PRY": 2.0, "PRT": 2.0, "UK": 3.0
    }
    for kode, bobot_val in default_bobots.items():
        jn = jn_map.get(kode)
        if jn:
            b = session.exec(
                select(BobotNilai).where(
                    BobotNilai.semester_id == sem.id,
                    BobotNilai.jenis_nilai_id == jn.id,
                    BobotNilai.mapel_id == None
                )
            ).first()
            if not b:
                b = BobotNilai(
                    id=f"bobot-{kode.lower()}-{sem.id}",
                    semester_id=sem.id,
                    mapel_id=None,
                    jenis_nilai_id=jn.id,
                    bobot=bobot_val,
                    created_at=now,
                    updated_at=now,
                    device_id="server-seeder",
                    server_seq=50
                )
                session.add(b)
                counts["created"] += 1
            else:
                counts["skipped"] += 1
    session.commit()

    # 7. Referensi Kemenag / EMIS (ref_item)
    ref_items = [
        # Agama
        ("agama", "islam", "Islam", 1),
        ("agama", "kristen", "Kristen", 2),
        ("agama", "katolik", "Katolik", 3),
        ("agama", "hindu", "Hindu", 4),
        ("agama", "buddha", "Buddha", 5),
        ("agama", "khonghucu", "Khonghucu", 6),
        # Status Hidup
        ("status_hidup", "hidup", "Masih Hidup", 1),
        ("status_hidup", "cerai", "Cerai Hidup", 2),
        ("status_hidup", "wafat", "Sudah Wafat", 3),
        # Pekerjaan
        ("pekerjaan", "tidak_bekerja", "Tidak Bekerja", 1),
        ("pekerjaan", "petani", "Petani / Pekebun", 2),
        ("pekerjaan", "nelayan", "Nelayan", 3),
        ("pekerjaan", "pedagang", "Pedagang Kecil", 4),
        ("pekerjaan", "swasta", "Karyawan Swasta", 5),
        ("pekerjaan", "pns", "PNS / TNI / Polri", 6),
        ("pekerjaan", "wiraswasta", "Wiraswasta", 7),
        ("pekerjaan", "buruh", "Buruh / Karyawan Lepas", 8),
        ("pekerjaan", "pensiunan", "Pensiunan", 9),
        ("pekerjaan", "lainnya", "Lainnya", 10),
        # Pendidikan
        ("pendidikan", "tidak_sekolah", "Tidak Pernah Sekolah", 1),
        ("pendidikan", "sd", "SD / MI Sederajat", 2),
        ("pendidikan", "smp", "SMP / MTs Sederajat", 3),
        ("pendidikan", "sma", "SMA / MA / SMK Sederajat", 4),
        ("pendidikan", "diploma", "Diploma (D1 - D3)", 5),
        ("pendidikan", "s1", "Sarjana (S1 / D4)", 6),
        ("pendidikan", "s2", "Magister (S2)", 7),
        ("pendidikan", "s3", "Doktor (S3)", 8),
        # Penghasilan
        ("penghasilan", "p1", "< Rp 500.000", 1),
        ("penghasilan", "p2", "Rp 500.000 - Rp 999.999", 2),
        ("penghasilan", "p3", "Rp 1.000.000 - Rp 1.999.999", 3),
        ("penghasilan", "p4", "Rp 2.000.000 - Rp 4.999.999", 4),
        ("penghasilan", "p5", "Rp 5.000.000 - Rp 20.000.000", 5),
        ("penghasilan", "p6", "> Rp 20.000.000", 6),
        # Jenis Pendaftaran
        ("jenis_pendaftaran", "baru", "Siswa Baru", 1),
        ("jenis_pendaftaran", "pindahan", "Pindahan dari Madrasah/Sekolah Lain", 2),
        ("jenis_pendaftaran", "kembali", "Kembali Bersekolah", 3),
        # Jenis Berkas
        ("jenis_berkas", "kk", "Kartu Keluarga (KK)", 1),
        ("jenis_berkas", "akta", "Akta Kelahiran", 2),
        ("jenis_berkas", "ijazah", "Ijazah SD / MI", 3),
        ("jenis_berkas", "kip", "Kartu KIP / PIP", 4),
        ("jenis_berkas", "mutasi", "Surat Keterangan Mutasi", 5),
        ("jenis_berkas", "foto", "Pas Foto Resmi", 6),
        ("jenis_berkas", "lainnya", "Dokumen Lainnya", 7),
    ]

    for kat, kode, nama, urutan in ref_items:
        existing = session.exec(
            select(RefItem).where(RefItem.kategori == kat, RefItem.kode == kode)
        ).first()
        if not existing:
            ref = RefItem(
                id=f"ref-{kat}-{kode}",
                kategori=kat,
                kode=kode,
                nama=nama,
                urutan=urutan,
                aktif=1,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=60
            )
            session.add(ref)
            counts["created"] += 1
        else:
            counts["skipped"] += 1
    session.commit()

    # 8. Data Guru & Rombel
    gurus_data = [
        ("guru-001", "Ust. Ahmad Fauzan, S.Pd.I", "198501012010011001", "L", "GTY", "ahmad"),
        ("guru-002", "Usth. Siti Aminah, M.Pd", "198802022012012002", "P", "GTY", "siti"),
        ("guru-003", "Ust. Muhammad Rizqi, S.Pd", "199203032018011003", "L", "GTT", "rizqi"),
    ]

    for gid, nama, nip, jk, status_peg, uname in gurus_data:
        g = session.get(Guru, gid)
        if not g:
            g = Guru(
                id=gid,
                nama_lengkap=nama,
                nip=nip,
                jk=jk,
                status_kepegawaian_kode=status_peg,
                aktif=1,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=70
            )
            session.add(g)
            counts["created"] += 1
        else:
            counts["skipped"] += 1

        # Buat user login untuk guru
        u = session.exec(select(User).where(User.username == uname)).first()
        if not u:
            u = User(
                id=f"user-{uname}",
                username=uname,
                guru_id=gid,
                pin_hash=hash_pin("123456"),
                aktif=1,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=75
            )
            session.add(u)
            counts["created"] += 1
        else:
            counts["skipped"] += 1
    session.commit()

    # 9. Rombel Awal (7A, 7B, 8A, 9A)
    rombels_data = [
        ("rombel-7a", "7A", "7", "guru-001"),
        ("rombel-7b", "7B", "7", "guru-002"),
        ("rombel-8a", "8A", "8", None),
        ("rombel-9a", "9A", "9", None),
    ]

    for rid, nama, tingkat, wali_id in rombels_data:
        r = session.get(Rombel, rid)
        if not r:
            r = Rombel(
                id=rid,
                tahun_ajaran_id=ta.id,
                nama=nama,
                tingkat=tingkat,
                wali_guru_id=wali_id,
                created_at=now,
                updated_at=now,
                device_id="server-seeder",
                server_seq=80
            )
            session.add(r)
            counts["created"] += 1
        else:
            counts["skipped"] += 1
    session.commit()

    # 10. Pengampu Contoh
    # Ahmad mengajar Bahasa Arab di 7A
    p1 = session.exec(
        select(Pengampu).where(
            Pengampu.guru_id == "guru-001",
            Pengampu.mapel_id == "mapel-bahasa_arab",
            Pengampu.rombel_id == "rombel-7a",
            Pengampu.semester_id == sem.id
        )
    ).first()
    if not p1:
        p1 = Pengampu(
            id="pengampu-ahmad-arab-7a",
            guru_id="guru-001",
            mapel_id="mapel-bahasa_arab",
            rombel_id="rombel-7a",
            semester_id=sem.id,
            cakupan="seluruh",
            peran="utama",
            tanggal_mulai="2026-07-15",
            tanggal_selesai=None,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=90
        )
        session.add(p1)
        counts["created"] += 1
    else:
        counts["skipped"] += 1

    # 11. User Admin Default
    admin_user = session.exec(select(User).where(User.username == "admin")).first()
    if not admin_user:
        admin_user = User(
            id="user-admin-default",
            username="admin",
            pin_hash=hash_pin("123456"),
            guru_id=None,
            aktif=1,
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=100
        )
        session.add(admin_user)
        session.commit()
        
        # Tambah user_role admin
        session.add(UserRole(
            id="role-admin-default",
            user_id=admin_user.id,
            role="admin",
            created_at=now,
            updated_at=now,
            device_id="server-seeder",
            server_seq=101
        ))
        session.commit()
        counts["created"] += 2
    else:
        counts["skipped"] += 1

    return counts

if __name__ == "__main__":
    from app.db.engine import get_session_context, init_db
    print("Inisialisasi Database WAL...")
    init_db()
    with get_session_context() as session:
        print("Menjalankan Seeder Master Data...")
        res = seed_initial_data(session)
        print(f"Selesai! Dibuat: {res['created']}, Dilewati: {res['skipped']}")
