# PRD v1.5: Aplikasi Manajemen Data & Rekap Nilai MTS ROUDHOTUT THOWALIB

**Status:** Revisi dari v1.4. Perubahan utama: penutupan celah teknis sinkronisasi, resolusi konflik *business key* (`nilai` & `absensi`), aturan eksplisit *fallback* guru utama pada mode kelompok, *partial unique index* SQLite, mekanisme *local garbage collection* untuk pencabutan akses, serta kontrak payload sinkronisasi untuk kesiapan implementasi AI Agent (*Claude Code*).

## Perubahan dari v1.4
- Spesifikasi eksplisit **Partial Unique Index** pada `pengampu` dan `keanggotaan_rombel` (Bagian 9)
- Aturan query filter sinkronisasi & hak edit untuk *fallback* Guru `utama` pada cakupan `sebagian` (F9, F17)
- Mekanisme **Local Garbage Collection (`local_gc`)** saat pencabutan hak akses pada sinkronisasi pull (F17)
- Resolusi konflik berbasis **Business Key Upsert** pada tabel `nilai` dan `absensi` ketika terjadi tabrakan entri offline dengan UUID berbeda (Bagian 5 & 9)
- Penanda visual nilai bawaan pindahan rombel (`sumber_nilai_id`) di UI Guru (F7, F10)
- Spesifikasi format JSON untuk `kolom_ts`, urutan eksekusi *Foreign Key* saat sinkronisasi, dan struktur kontrak JSON `/sync/push` & `/sync/pull` (Bagian 9)
- Opsi pemrosesan Import/Export Excel berbantuan server jika terhubung (F15, Bagian 7)

---

## 1. Ringkasan
Aplikasi Android **offline-first** untuk MTs: kelola data siswa, guru, rombel, dan nilai, lalu rekap. Sinkron ke server laptop operator lewat WiFi yang sama.
- **Non-tujuan:** cetak rapor, nilai sikap, e-learning, aplikasi siswa/wali, cloud publik
- **Skala:** ±250 pengguna, SQLite cukup
- **Kurikulum:** 2013

## 2. Role & Hak Akses

| Data / Aksi | Admin | Kepala | Wali Kelas | Guru Mapel |
|---|---|---|---|---|
| Daftar siswa | Semua | Semua | Semua | Hanya siswa yang tercakup pengampunya |
| `siswa` (nama, NIS, JK) | Edit | Lihat | Lihat | Lihat |
| `siswa_detail`, `siswa_ortu`, `alamat` | Edit | Lihat | **Edit** (rombelnya) | Tidak ada |
| `siswa_sensitif` | Edit | Lihat | Lihat (rombelnya) | Tidak ada |
| Berkas siswa | Lihat, unggah, hapus | Lihat | Lihat, unggah | Tidak ada |
| Rekam jejak kelas | Seluruh + proses | Seluruh | Seluruh riwayat siswa rombelnya | Tidak ada |
| Status, mutasi, pindah, naik kelas | Edit | Lihat | Tidak | Tidak |
| Input nilai | Ya | Lihat | Lihat rombelnya | Edit (sesuai pengampu) |
| Bobot, KKM, pengampu | Edit | Lihat | Tidak | Tidak |
| Absensi | Ya | Lihat | Edit (rombelnya) | Tidak |
| Data guru | Edit | Lihat | Tidak | Data sendiri |
| Status perangkat sinkron | Ya | Lihat | Tidak | Tidak |

- Role yang disimpan hanya **admin** dan **kepala** (`user_role`). **Wali kelas diturunkan dari `rombel.wali_guru_id`, guru mapel dari `pengampu`**, sehingga tidak ada data ganda.
- Satu orang bisa punya banyak peran. Akses kontekstual per rombel/mapel dan **ditegakkan di server**.
- Guru yang juga wali kelas hanya mendapat detail rombel perwaliannya.

## 3. Kebutuhan Fungsional

**F1. Autentikasi:** nama + PIN (Argon2/bcrypt, batas percobaan). Verifikasi pertama ke server, berikutnya bisa offline. Admin bisa menonaktifkan akun.

**F2. Data master:** identitas madrasah, tahun ajaran/semester (satu aktif, hanya Admin yang mengganti), mapel (Qur'an Hadis, Akidah Akhlak, Fikih, SKI, Bahasa Arab, dll.), tabel referensi EMIS.

**F3. Daftar siswa:** NIS, nama, JK, rombel; pencarian, filter, deteksi duplikat.

**F4. Detail Siswa (Admin, Kepala, Wali Kelas)**

**A. Data diri** (`siswa` + `siswa_detail`)
- Nama lengkap, NISN, NIS, jenis kelamin
- Tempat dan tanggal lahir (tampil `dd MMMM yyyy`, input date picker)
- Agama (dropdown, default Islam), anak ke-, jumlah saudara, foto
- Kontak: nomor HP, email (opsional)
- Kondisi: kebutuhan khusus, tinggi dan berat badan
- Tempat tinggal dan akses: tinggal bersama, transportasi, jarak (km), waktu tempuh (menit)
- Bantuan sosial: penerima KIP/PIP, KPS, PKH (ya/tidak)
- Asal sekolah: nama sekolah asal, tanggal masuk, jenis pendaftaran (baru/pindahan)

**B. Ayah dan ibu** (`siswa_ortu`): nama lengkap, tempat dan tanggal lahir, pekerjaan, pendidikan terakhir, penghasilan bulanan (rentang), nomor HP, kebutuhan khusus (opsional), **status hidup/cerai/wafat** (jika wafat: tahun wafat opsional, alamat tidak wajib, NIK tetap boleh disimpan).

**C. Wali (opsional):** field sama seperti B tanpa status. Saklar "Siswa memiliki wali"; jika mati, baris wali dan NIK wali tidak dibuat.

**D. Alamat** (siswa, ayah, ibu, wali, masing-masing terpisah): jalan, RT, RW, dusun, desa/kelurahan, kecamatan, kabupaten/kota, provinsi, kode pos. Tombol **"Sama dengan..."** menyalin nilai (bukan tautan) dari ayah/ibu/wali.

**E. Data sensitif** (`siswa_sensitif`, terenkripsi): Nomor KK, NIK siswa/ayah/ibu/wali, nomor KIP/PIP, KPS, PKH. Disamarkan sampai diketuk, pembukaan tercatat di audit.

**F. Rekam jejak siswa:** timeline dari `keanggotaan_rombel` dan `riwayat_status_siswa` (tahun ajaran/semester, rombel, periode, alasan keluar, wali kelas, rata-rata nilai, ringkasan absensi, catatan mutasi, tanda "nilai dibawa dari 7A"). Wali kelas melihat seluruh riwayat tetapi tidak menerima daftar teman sekelas rombel lama.

**G. Berkas siswa:** KK, Akta Kelahiran, Ijazah SD, KIP/PIP, Surat Mutasi, Pas Foto, Lainnya (jenis bisa ditambah Admin).

**Aturan form:** semua field selain NIS, nama, dan JK **opsional**. Form dipecah per bagian A-G dengan **indikator kelengkapan**.

**F5. Berkas & foto**
- JPG, PNG, PDF; server memeriksa isi berkas (*magic bytes*)
- Foto dikompres di HP (±480 px, ±100 KB); berkas foto ±1 MB; PDF maks ±5 MB; opsi scan kamera
- Metadata ikut sinkron, **isi diunduh saat dibuka**, cache dibatasi
- Antrean unggah terpisah dan bisa dilanjutkan
- Dienkripsi (AES-GCM) di server dan penyimpanan privat app; viewer bawaan, `FLAG_SECURE`, tanpa bagikan/simpan ke galeri; pembukaan tercatat

**F6. Rombel & riwayat kelas:** rombel milik satu tahun ajaran; satu siswa hanya punya satu keanggotaan terbuka.

**F7. Mutasi & perubahan status (hanya Admin)**
- **Naik kelas:** massal per rombel dengan pratinjau, pilih naik atau tinggal
- **Pindah rombel (7A → 7B)** dalam satu transaksi: validasi (aktif, tahun dan tingkat sama, belum dikunci) → tutup keanggotaan lama → buka baru → catat di `riwayat_status_siswa` dan `audit_log`
- **Nilai saat pindah:** default **dibawa** (disalin ke `keanggotaan_id` baru dengan mengisi `sumber_keanggotaan_id` dan `sumber_nilai_id`, baris asli di rombel lama tetap utuh); Admin bisa pilih "mulai kosong". Absensi tidak disalin, rekap menjumlahkan keduanya.
- **Penanganan kelompok saat pindah:** Jika di rombel baru (7B) ada mapel dengan pola pengampu `sebagian` (kelompok), siswa pindahan yang belum dimasukkan ke kelompok mana pun otomatis jatuh ke cakupan Guru `utama` 7B sampai Admin memasukkannya ke kelompok tertentu, dan memicu indikator peringatan di layar **Cek Pengampu**. Jika mapel belum punya pengampu sama sekali di rombel baru, Admin mendapat peringatan.
- Lulus, mutasi keluar (tanggal, sekolah tujuan, nomor surat), mutasi masuk, non-aktif/aktif kembali
- Tidak ada yang dihapus; koreksi dengan catatan pembalik (`membatalkan_id`)

**F8. Pergantian tahun ajaran (wizard Admin):** buat tahun/semester → buat rombel (opsi salin) → naik kelas dan kelulusan → **salin pengampu dari semester sebelumnya lalu sesuaikan** → aktifkan semester baru → kunci tahun lama.

**F9. Pengampu**
- **Pengaturan Pengampu:** Admin memilih rombel, mapel, guru. Cakupan otomatis `seluruh`, peran otomatis `utama` untuk guru pertama.
- Saat menambah guru **kedua** untuk mapel dan rombel yang sama, peran guru kedua otomatis `pendamping`, dan app bertanya sekali:
  - "Kedua guru menilai seluruh kelas" (tetap `seluruh`)
  - "Bagi siswa jadi kelompok" (beralih ke `sebagian`, muncul layar pembagian)
- **Layar pembagian kelompok:** daftar siswa dengan centang per guru, tombol "Bagi otomatis ganjil/genap absen" dan "Bagi rata berdasarkan urutan", bisa diubah manual.
- Guru yang sendirian di sebuah mapel tidak ditanya apa pun.
- **Aturan Fallback Peran `utama`:** Peran `utama` wajib ada tepat satu yang aktif per `(mapel, rombel, semester)`. Pada mode `sebagian`, jika ada siswa aktif di rombel tersebut yang belum dipetakan di `pengampu_siswa` milik guru aktif mana pun (misalnya siswa baru pindah masuk atau terlewat dicentang), siswa tersebut **otomatis menjadi tanggung jawab Guru `utama`** (masuk ke daftar siswa dan hak edit Guru `utama`) sehingga tidak ada nilai siswa yang tertahan.
- **Pergantian guru** di tengah semester: baris lama ditutup (`tanggal_selesai` diisi), baris baru dibuat (mewarisi peran dan memindahkan daftar `pengampu_siswa` jika mode `sebagian`, dengan opsi sesuaikan). Nilai lama tetap, guru lama tidak bisa edit lagi.
- **Pengampu dicabut:** nilai tidak dihapus, daftar siswa mapel itu dihapus dari HP guru pada sinkron berikutnya melalui mekanisme *local garbage collection*.
- **Cek Pengampu (layar Admin):** menampilkan anomali:
  1. Mapel di rombel aktif yang belum punya pengampu `utama`
  2. Siswa aktif yang belum masuk ke `pengampu_siswa` pada mapel mode `sebagian` (sedang ditangani fallback Guru `utama`)
  3. Siswa yang tercakup di lebih dari satu guru pada mapel mode `sebagian` (peringatan tumpang tindih)
  4. Guru nonaktif yang masih tercatat di pengampu aktif
  5. Rombel yang daftar siswanya berubah setelah salin pengampu semester

**F10. Input nilai (Kurikulum 2013)**
- **Pengetahuan:** Tugas (TGS), UH, PAT, PAS. **Keterampilan:** Proyek (PRY), Portofolio (PRT), Unjuk Kerja (UK)
- Satu jenis boleh banyak entri (`urutan_ke`: 1, 2, 3...)
- Hitung: rata-rata per jenis → dibobot → **nilai akhir pengetahuan** dan **keterampilan** per mapel, predikat A-D menurut KKM ($\text{interval} = (100 - \text{KKM}) / 3$). **Dihitung, tidak disimpan**
- Bobot dan KKM diatur Admin (default global, bisa per mapel/tingkat). Asumsi: PAS di ganjil, PAT di genap
- Validasi 0-100, penanda kosong dan di bawah KKM
- **Penanda Nilai Pindahan:** Baris nilai yang memiliki `sumber_nilai_id IS NOT NULL` ditampilkan dengan badge/label kecil *"Bawaan rombel asal"* di layar input nilai guru agar guru maklum jika jumlah/urutan penilaian siswa pindahan berbeda dengan siswa asli kelas tersebut. Guru rombel baru tetap berhak mengedit atau menyesuaikannya.
- **Hak edit:** guru boleh menginput/mengedit nilai jika:
  1. Ada pengampu aktif (`tanggal_selesai IS NULL AND deleted = 0`) untuk `(guru, mapel, rombel, semester)`
  2. Cakupannya `seluruh`, ATAU siswa ada di `pengampu_siswa` miliknya, ATAU guru tersebut berperan `utama` dan siswa belum terdaftar di `pengampu_siswa` milik pengampu aktif mana pun pada mapel & semester tersebut
  3. Keanggotaan rombel siswa masih terbuka (`tanggal_keluar IS NULL`) dan semester belum dikunci (`dikunci = 0`)
- Pada pola dua guru `seluruh` (atau tumpang tindih kelompok), keduanya memakai **satu tabel nilai yang sama**; konflik terbaru menang per entri penilaian `(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)`, dan `diinput_oleh_guru_id` dicatat ("Tugas 2 oleh Bu Sari")
- Nilai akhir dihitung dari seluruh baris aktif, siapa pun penginputnya

**F11. Layar guru:** beranda berisi kartu "Kelas saya" per `(mapel, rombel)`, contoh "Bahasa Arab 7A" dan "Bahasa Arab 7C". Jika cakupan `sebagian`, ada label "Kelompok saya: 18 siswa" (dan "+ 1 belum dikelompokkan" khusus bagi Guru `utama` jika ada siswa fallback). Guru yang mengajar 7A tetapi tidak 7B hanya melihat 7A.

**F12. Rekap nilai:** per siswa, per mapel, per rombel (rata-rata, peringkat), **kelengkapan per pengampu** (jika mapel punya dua guru kelompok, progres terlihat per kelompok masing-masing), riwayat antar semester, dashboard Kepala.

**F13. Absensi:** harian per rombel (hadir/sakit/izin/alpa), diinput oleh Wali Kelas atau Admin, rekap bulanan dan semester.

**F14. Data guru**
- `guru`: nama lengkap (dengan gelar), NIP, JK, status kepegawaian (PNS, PPPK, GTY, GTT), aktif
- `guru_detail`: NUPTK, tempat/tanggal lahir, agama, nomor HP, email, foto, pendidikan terakhir, jurusan, perguruan tinggi, tahun lulus, tanggal mulai tugas, golongan, sertifikasi, alamat. Mapel dan tugas tambahan ditarik dari pengampu/rombel
- `guru_sensitif`: NIK terenkripsi (Admin dan Kepala)
- `guru_berkas` (tahap lanjut)
- `guru` terpisah dari `user`, relasi opsional satu ke satu
- Tidak disimpan: NPWP, rekening, gaji

**F15. Import/Export:**
- Excel (`.xlsx`) dan CSV untuk siswa, guru, nilai, dengan template, pratinjau, validasi (NIS/NISN/NIK ganda, format), laporan baris gagal.
- **Kolom dan kode mengikuti EMIS.** Ekspor nilai memakai pemetaan kolom yang bisa diubah.
- Jika perangkat Admin terhubung ke server, parsing/generasi file `.xlsx` kompleks dapat didelegasikan ke endpoint server (FastAPI + `openpyxl`) untuk performa tinggi, dengan fallback pemrosesan lokal di HP saat offline.

**F16. Backup/restore:** berkas database dan lampiran dienkripsi password (AES-256), pengingat berkala untuk operator.

**F17. Sinkron**
- `POST /sync/push`, `GET /sync/pull?since_seq=` dengan pagination. Memakai **`server_seq`**, bukan jam HP.
- **Filter per tabel dan role di server:**
  - Data `siswa_detail`, `siswa_ortu`, `alamat`, `siswa_sensitif`, dan `siswa_berkas` tidak dikirim ke Guru Mapel (hanya ke Admin, Kepala, dan Wali Kelas untuk rombel perwaliannya).
  - **Filter Siswa untuk Guru Mapel:**
    - Pengampu `seluruh`: menerima seluruh siswa yang memiliki `keanggotaan_rombel` di rombel tersebut pada semester aktif.
    - Pengampu `sebagian` (`pendamping`): hanya menerima siswa yang terdaftar di `pengampu_siswa` miliknya.
    - Pengampu `sebagian` (`utama`): menerima siswa di `pengampu_siswa` miliknya **UNION** siswa aktif di rombel tersebut yang belum terdaftar di `pengampu_siswa` milik pengampu aktif mana pun pada mapel dan semester tersebut.
- **Pencabutan Data (*Data Revocation & Local Garbage Collection*):**
  - Saat wali kelas diganti, siswa naik/pindah/lulus, pengampu dicabut/ditutup, atau kelompok `pengampu_siswa` diubah, server menyertakan sinyal `recalculate_scope: true` (atau daftar ID ruang lingkup aktif) pada respons `/sync/pull`.
  - Klien wajib menjalankan prosedur **`local_gc()`** seusai menerapkan batch pull: menghapus dari SQLite lokal semua baris `siswa`, `siswa_detail`, `siswa_ortu`, `siswa_sensitif`, `alamat`, `nilai`, `absensi`, dan file cache `siswa_berkas` yang tidak lagi berada dalam himpunan rombel/pengampu aktif milik user tersebut (kecuali baris yang masih ada di `outbox` belum terkirim).
- Push ditolak bila di luar hak (aturan bagian 9.7).
- Naik kelas/mutasi hanya dari satu perangkat Admin dan mengunci sinkron (`/sync/lock`) selama transaksi berjalan.
- Nilai untuk keanggotaan tertutup ditolak dengan pesan spesifik (contoh: *"Gagal simpan: Siswa sudah pindah ke rombel 7B"*).
- Alamat server diatur lewat input IP/hostname manual atau scan QR dari layar server operator.

**F18. Peringatan belum tersinkron:** antrean `outbox` (termasuk `berkas_antrean`), banner beranda ("12 perubahan belum tersinkron, terakhir sinkron 3 hari lalu") yang berubah warna melewati ambang (kuning > 24 jam, merah > 72 jam), pengingat saat app dibuka/keluar dan notifikasi lokal, layar **Status Perangkat** untuk operator.

**F19. Audit:** siapa, kapan, nilai lama dan baru untuk nilai, status, dan data siswa. Pembukaan data sensitif, berkas, ekspor, konflik sinkronisasi yang tertimpa, dan akses riwayat tahun lama oleh wali kelas juga tercatat. Untuk kolom sensitif hanya penanda `"diubah"`, bukan isinya.

---

## 4. Keamanan Data Sensitif

| Lapisan | Kontrol |
|---|---|
| Jaringan | HTTPS self-signed + certificate pinning (fingerprint disertakan di QR pairing server) |
| HP | SQLCipher (AES-256), kunci di Android Keystore, `allowBackup=false`, `FLAG_SECURE` pada layar sensitif & berkas |
| Server | Kolom sensitif AES-256-GCM (`*_enc`), kunci master di luar database dan repo (env/file keystore), `*_hash` (HMAC-SHA256 dengan secret key server) untuk cek duplikat tanpa dekripsi (kolom `*_hash` tidak dikirim ke HP), BitLocker, berkas terenkripsi |
| Tampilan | NIK/KK/nomor bansos disamarkan (`3201************`), dibuka dengan ketukan per baris |
| Ekspor | Disamarkan default; ekspor lengkap hanya Admin/Kepala dan dicatat di `audit_log`; wali kelas hanya bisa ekspor rombelnya (sensitif tetap disamarkan kecuali diberi izin) |
| Log | Data sensitif tidak boleh muncul di log aplikasi, console, maupun pesan error HTTP |

Data pribadi anak dibatasi seperlunya sesuai prinsip pelindungan data pribadi (UU PDP).

---

## 5. Konflik & Integritas

1. **Resolusi Per Kolom (`kolom_ts`):**
   - Berlaku pada tabel profil yang memiliki banyak atribut independen: `siswa_detail`, `siswa_ortu`, `alamat`, `guru_detail`.
   - Kolom `kolom_ts` bertipe `TEXT` berisi JSON object yang memetakan `nama_kolom -> epoch_ms_utc` (contoh: `{"nomor_hp": 1710000123000, "jarak_km": 1710000456000}`).
   - Saat server menerima `POST /sync/push`, server membandingkan timestamp per kolom yang dikirim dengan `kolom_ts` di server. Hanya kolom dengan timestamp lebih baru yang menimpa nilai di server, lalu `kolom_ts` digabung (*merge*).
2. **Resolusi Per Baris & *Business Key Upsert* (`nilai` dan `absensi`):**
   - Untuk tabel transaksi seperti `nilai` dan `absensi`, resolusi dilakukan per baris berdasarkan `updated_at` terbaru.
   - **Penanganan Tabrakan Business Key dengan UUID Berbeda:** Jika dua guru pada mode `seluruh` sama-sama membuat entri baru secara offline untuk kombinasi unik bisnis yang sama—misalnya `nilai` untuk `(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)` yang sama, atau `absensi` untuk `(keanggotaan_id, tanggal)` yang sama—masing-masing HP akan menghasilkan `id` (UUID) yang berbeda.
   - Saat push ke server, jika kombinasi *business key* tersebut sudah ada di server (meskipun `id` UUID-nya berbeda):
     1. Server **tidak melempar error constraint**, melainkan melakukan **Upsert berbasis Business Key**.
     2. Server mempertahankan `id` (UUID) yang sudah lebih dulu tercatat di server sebagai *canonical ID*.
     3. Server membandingkan `updated_at`: jika data yang baru masuk lebih baru, kolom nilai/status dan `diinput_oleh_guru_id` diperbarui; jika lebih lama, diabaikan.
     4. Versi yang kalah tetap dicatat di `audit_log` (sebagai rekaman riwayat konflik).
     5. Server mengembalikan `canonical_id` dalam respons push (atau melalui `server_seq` baru saat pull) sehingga klien yang menggunakan UUID sementara akan mengganti baris lokalnya dengan baris ber-UUID kanonik dari server.
3. **Aturan Edit Wali Kelas:**
   - Edit data siswa oleh wali kelas hanya diizinkan selama semester aktif belum dikunci, dan otomatis ditandai `diubah_wali_kelas = 1` untuk ditinjau Admin.
4. **Prinsip Umum:**
   - Semua primary key menggunakan UUID v4, penghapusan menggunakan *soft delete* (`deleted = 1`), dan operasi mutasi/naik kelas dieksekusi dalam satu transaksi database.

---

## 6. Non-Fungsional
Offline penuh untuk seluruh fitur inti di HP, lancar menangani 1.000+ siswa dan puluhan ribu baris nilai, mendukung Android 8.0+ (API 26+), konsumsi RAM server lokal ±100–150 MB, antarmuka seluruhnya dalam Bahasa Indonesia yang jelas bagi guru madrasah.

---

## 7. Arsitektur
- **App (Android):** Flutter, `drift` + `sqlcipher_flutter_libs`, `excel` / `csv`, `file_picker`, `pdf`, `printing`, kamera/scan dokumen.
- **Server (Laptop Operator):** Python FastAPI + Uvicorn (1 worker untuk menghindari database lock pada SQLite), SQLite dengan mode `WAL` (*Write-Ahead Logging*) dan `synchronous=NORMAL`, SQLModel/SQLAlchemy, Alembic (migrasi), JWT, `cryptography` (AES-GCM & HMAC), `openpyxl` (untuk pemrosesan Excel berat di server).
- **Build & CI/CD:** GitHub Actions (dengan caching untuk Flutter SDK, pub-cache, Gradle, dan `build_runner`), tanpa ketergantungan build lokal.
- **Alur Pengerjaan:** Claude Code + `gh` CLI + panduan arsitektur di `CLAUDE.md`.

---

## 8. Rencana Rilis

| Tahap | Isi |
|---|---|
| **1 (MVP)** | Master data, siswa A-D, guru, rombel + keanggotaan, **pengampu (seluruh + peran utama)**, mutasi/naik kelas, input nilai, import/export |
| **2** | Rekap nilai, absensi, berkas dan foto, PDF, KKM, backup terenkripsi, rekam jejak lengkap, **pengampu kelompok (`pengampu_siswa`) dan Cek Pengampu** |
| **3** | Server FastAPI, HTTPS + QR Pairing, sinkronisasi per role + `local_gc`, enkripsi kolom sensitif, audit log, peringatan sinkron, dashboard |

Struktur tabel lengkap (termasuk `pengampu_siswa` dan `kolom_ts`), UUID, kolom enkripsi, serta tabel `outbox` dirancang sejak **Tahap 1** agar tidak terjadi perombakan skema pada Tahap 2 dan 3.

---

## 9. Skema Tabel & Spesifikasi Sinkronisasi

### 9.1 Konvensi Kolom Wajib
- Semua tabel sinkron wajib memiliki:
  - `id` (`TEXT PRIMARY KEY`, UUID v4)
  - `created_at` (`INTEGER NOT NULL`, epoch ms UTC)
  - `updated_at` (`INTEGER NOT NULL`, epoch ms UTC)
  - `deleted` (`INTEGER NOT NULL DEFAULT 0`, boolean `0|1`)
  - `device_id` (`TEXT NOT NULL`)
  - `server_seq` (`INTEGER`, diisi/di-increment secara monotonik oleh server setiap kali baris diinsert/diupdate; bernilai `NULL` atau `0` di HP sebelum tersinkron)
- Tabel gabung-per-kolom (`siswa_detail`, `siswa_ortu`, `alamat`, `guru_detail`) memiliki kolom tambahan:
  - `kolom_ts` (`TEXT NOT NULL DEFAULT '{}'`, JSON string berisi timestamp per nama kolom)
- Kolom referensi menyimpan **kode** (`*_kode`), bukan foreign key UUID ke `ref_item`, untuk menyederhanakan query dan ekspor EMIS.
- Format tanggal kalender: `YYYY-MM-DD` (`TEXT`).
- **Nama tabel dan nama kolom di SQLite (Drift/Dart), SQLModel (Python), dan payload JSON wajib identik (`snake_case`).**

### 9.2 Daftar Tabel

**A. Sistem & Akun**
- `madrasah`: `nama`, `npsn`, `nsm`, `alamat`, `kepala_guru_id`, `logo_berkas_id`, `semester_aktif_id`
- `user`: `guru_id` (nullable), `username` (UNIQUE), `aktif` (`0|1`); *khusus di server:* `pin_hash`, `gagal_login`, `terkunci_sampai`
- `user_role`: `user_id`, `role` (`admin` | `kepala`), `UNIQUE(user_id, role)`
- `perangkat` *(server saja)*: `id` (`device_id`), `user_id`, `nama_perangkat`, `versi_app`, `last_sync_at`, `last_pull_seq`, `jumlah_outbox_terakhir`, `aktif`
- `audit_log`: `id`, `waktu`, `user_id`, `device_id`, `aksi`, `tabel`, `baris_id`, `data_lama` (JSON, nullable), `data_baru` (JSON, nullable), `keterangan`
- *Khusus HP (tidak disinkronkan sebagai tabel domain):*
  - `outbox`: `local_seq` (PK autoincrement), `tabel`, `baris_id`, `operasi` (`UPSERT` | `DELETE`), `payload_json`, `created_at`, `percobaan`, `error_terakhir`
  - `sync_state`: `kunci` (PK), `nilai` (menyimpan `last_server_seq`, `last_sync_time`, `server_url`, `cert_fingerprint`, `scope_hash`)
  - `berkas_antrean`: `berkas_id`, `jenis_pemilik` (`siswa` | `guru`), `jalur_lokal`, `arah` (`UPLOAD` | `DOWNLOAD`), `status`, `progres`, `error_terakhir`

**B. Referensi**
- `ref_item`: `kategori`, `kode`, `nama`, `urutan`, `aktif`; `UNIQUE(kategori, kode)`
- `ref_wilayah`: `kode` (PK), `nama`, `tingkat` (`prov` | `kab` | `kec` | `desa`), `induk_kode`

**C. Akademik**
- `tahun_ajaran`: `nama` (contoh: `2026/2027`), `tanggal_mulai`, `tanggal_selesai`, `aktif`
- `semester`: `tahun_ajaran_id`, `jenis` (`ganjil` | `genap`), `tanggal_mulai`, `tanggal_selesai`, `dikunci` (`0|1`); `UNIQUE(tahun_ajaran_id, jenis)`
- `mapel`: `kode`, `nama`, `kelompok`, `urutan`, `aktif`; `UNIQUE(kode)`
- `rombel`: `tahun_ajaran_id`, `nama` (contoh: `7A`), `tingkat` (`7` | `8` | `9`), `wali_guru_id`
- `pengampu`: `guru_id`, `mapel_id`, `rombel_id`, `semester_id`, `cakupan` (`seluruh` | `sebagian`), `peran` (`utama` | `pendamping`), `tanggal_mulai`, `tanggal_selesai` (nullable)
- `pengampu_siswa`: `pengampu_id`, `keanggotaan_id`; `UNIQUE(pengampu_id, keanggotaan_id)` *(hanya diisi jika `pengampu.cakupan = 'sebagian'`)*
- `keanggotaan_rombel`: `siswa_id`, `rombel_id`, `tanggal_masuk`, `tanggal_keluar` (nullable), `alasan_keluar` (`naik_kelas` | `tinggal_kelas` | `pindah_rombel` | `mutasi_keluar` | `lulus` | `keluar`, nullable), `sumber_keanggotaan_id` (nullable)
- `riwayat_status_siswa`: `siswa_id`, `tanggal`, `jenis_status` (`masuk_baru` | `mutasi_masuk` | `pindah_rombel` | `naik_kelas` | `tinggal_kelas` | `mutasi_keluar` | `lulus` | `nonaktif` | `aktif_kembali`), `rombel_asal_id`, `rombel_tujuan_id`, `sekolah_tujuan`, `nomor_surat`, `catatan`, `membatalkan_id` (nullable; tabel ini *append-only*)
- `jenis_nilai`: `kategori` (`pengetahuan` | `keterampilan`), `kode` (`TGS`, `UH`, `PAS`, `PAT`, `PRY`, `PRT`, `UK`), `nama`, `urutan`, `aktif`; `UNIQUE(kode)`
- `bobot_nilai`: `semester_id`, `mapel_id` (nullable untuk default global), `jenis_nilai_id`, `bobot`
- `pengaturan_kkm`: `semester_id`, `mapel_id` (nullable), `tingkat` (nullable), `kkm`
- `nilai`: `keanggotaan_id`, `mapel_id`, `semester_id`, `jenis_nilai_id`, `urutan_ke` (`INTEGER >= 1`), `nilai` (`REAL`, 0–100), `tanggal`, `keterangan`, `sumber_nilai_id` (nullable), `diinput_oleh_guru_id`
- `absensi`: `keanggotaan_id`, `semester_id`, `tanggal`, `status` (`H` | `S` | `I` | `A`), `keterangan`, `diinput_oleh_user_id`

**D. Siswa**
- `siswa`: `nis` (UNIQUE), `nisn`, `nama_lengkap`, `jk` (`L` | `P`), `status_aktif` (`aktif` | `lulus` | `mutasi_keluar` | `nonaktif`), `diubah_wali_kelas` (`0|1`)
- `siswa_detail`: `siswa_id` (UNIQUE), `tempat_lahir`, `tanggal_lahir`, `agama_kode`, `anak_ke`, `jumlah_saudara`, `foto_berkas_id`, `nomor_hp`, `email`, `kebutuhan_khusus_kode`, `tinggi_cm`, `berat_kg`, `tinggal_bersama_kode`, `transportasi_kode`, `jarak_km`, `waktu_tempuh_menit`, `penerima_kip` (`0|1`), `penerima_kps` (`0|1`), `penerima_pkh` (`0|1`), `sekolah_asal`, `tanggal_masuk`, `jenis_pendaftaran_kode`, `diubah_wali_kelas` (`0|1`), `kolom_ts`
- `siswa_ortu`: `siswa_id`, `hubungan` (`ayah` | `ibu` | `wali`), `nama_lengkap`, `tempat_lahir`, `tanggal_lahir`, `status_hidup_kode` (`hidup` | `cerai` | `wafat`, nullable untuk wali), `tahun_wafat`, `pekerjaan_kode`, `pendidikan_kode`, `penghasilan_kode`, `nomor_hp`, `kebutuhan_khusus_kode`, `diubah_wali_kelas` (`0|1`), `kolom_ts`; `UNIQUE(siswa_id, hubungan)`
- `alamat`: `pemilik_tipe` (`siswa` | `siswa_ortu` | `guru`), `pemilik_id`, `siswa_id` (diisi untuk `siswa` dan `siswa_ortu` guna memudahkan filter sinkronisasi per siswa), `jalan`, `rt`, `rw`, `dusun`, `desa_kode`, `desa_nama`, `kecamatan_kode`, `kecamatan_nama`, `kabupaten_kode`, `kabupaten_nama`, `provinsi_kode`, `provinsi_nama`, `kode_pos`, `diubah_wali_kelas` (`0|1`), `kolom_ts`; `UNIQUE(pemilik_tipe, pemilik_id)`
- `siswa_sensitif`: `siswa_id` (UNIQUE), `no_kk_enc`, `nik_siswa_enc`, `nik_ayah_enc`, `nik_ibu_enc`, `nik_wali_enc`, `no_kip_enc`, `no_kps_enc`, `no_pkh_enc`; *khusus di server ditambah kolom:* `nik_siswa_hash`, `no_kk_hash`
- `siswa_berkas`: `siswa_id`, `jenis_berkas_kode`, `nama_tampil`, `mime_type`, `ukuran_byte`, `sha256_plain`, `server_path_enc`, `status_unggah`, `diunggah_oleh_user_id`

**E. Guru**
- `guru`: `nip`, `nama_lengkap`, `jk` (`L` | `P`), `status_kepegawaian_kode`, `aktif` (`0|1`)
- `guru_detail`: `guru_id` (UNIQUE), `nuptk`, `tempat_lahir`, `tanggal_lahir`, `agama_kode`, `nomor_hp`, `email`, `foto_berkas_id`, `pendidikan_kode`, `jurusan`, `perguruan_tinggi`, `tahun_lulus`, `tmt_guru`, `golongan_kode`, `sertifikasi` (`0|1`), `kolom_ts`
- `guru_sensitif`: `guru_id` (UNIQUE), `nik_enc`; *khusus di server:* `nik_hash`
- `guru_berkas`: `guru_id`, `jenis_berkas_kode`, `nama_tampil`, `mime_type`, `ukuran_byte`, `sha256_plain`, `server_path_enc`, `status_unggah`

### 9.3 Partial Unique Indexes & Constraints (Wajib di SQLite & Server)
Untuk mencegah duplikasi data aktif sekaligus mengizinkan *soft delete* (`deleted = 1`) dan riwayat masa tugas yang sudah selesai (`tanggal_selesai IS NOT NULL`), database wajib menerapkan **Partial Unique Index** berikut:

1. **Satu keanggotaan rombel terbuka per siswa:**
   ```sql
   CREATE UNIQUE INDEX idx_keanggotaan_terbuka_unik
   ON keanggotaan_rombel(siswa_id)
   WHERE tanggal_keluar IS NULL AND deleted = 0;
   ```
2. **Satu pengampu `utama` aktif per `(mapel, rombel, semester)`:**
   ```sql
   CREATE UNIQUE INDEX idx_pengampu_utama_aktif
   ON pengampu(mapel_id, rombel_id, semester_id)
   WHERE peran = 'utama' AND tanggal_selesai IS NULL AND deleted = 0;
   ```
3. **Satu baris penugasan aktif per guru pada `(mapel, rombel, semester)` yang sama:**
   ```sql
   CREATE UNIQUE INDEX idx_pengampu_guru_aktif
   ON pengampu(guru_id, mapel_id, rombel_id, semester_id)
   WHERE tanggal_selesai IS NULL AND deleted = 0;
   ```
4. **Satu entri nilai aktif per urutan penilaian (*Business Key* `nilai`):**
   ```sql
   CREATE UNIQUE INDEX idx_nilai_bisnis_unik
   ON nilai(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)
   WHERE deleted = 0;
   ```
5. **Satu entri absensi aktif per siswa per tanggal (*Business Key* `absensi`):**
   ```sql
   CREATE UNIQUE INDEX idx_absensi_bisnis_unik
   ON absensi(keanggotaan_id, tanggal)
   WHERE deleted = 0;
   ```

**Indeks Performa Tambahan:**
- `siswa(nis)`, `keanggotaan_rombel(siswa_id, rombel_id)`, `nilai(keanggotaan_id, semester_id)`, `nilai(mapel_id, semester_id)`, `pengampu(guru_id, semester_id)`, `pengampu_siswa(keanggotaan_id)`, `rombel(wali_guru_id)`, `alamat(siswa_id)`, serta indeks pada kolom `(server_seq)` di semua tabel sinkron.

### 9.4 Urutan Ketergantungan Tabel Saat Sinkronisasi (FK Order)
Saat memproses batch `/sync/push` di server maupun `/sync/pull` di HP, operasi `UPSERT` wajib dijalankan sesuai urutan tingkat ketergantungan (*Foreign Key Order*) berikut agar tidak memicu *Foreign Key Constraint Error*:

1. **Tingkat 1 (Referensi & Master):** `ref_item`, `ref_wilayah`, `tahun_ajaran`, `semester`, `mapel`, `jenis_nilai`
2. **Tingkat 2 (SDM & Organisasi):** `guru`, `guru_detail`, `guru_sensitif`, `madrasah`, `user`, `user_role`
3. **Tingkat 3 (Rombel & Siswa Inti):** `rombel`, `siswa`, `siswa_detail`, `siswa_ortu`, `siswa_sensitif`, `alamat`
4. **Tingkat 4 (Relasi Akademik):** `keanggotaan_rombel`, `riwayat_status_siswa`, `pengampu`, `pengampu_siswa`, `bobot_nilai`, `pengaturan_kkm`
5. **Tingkat 5 (Transaksi & Berkas):** `nilai`, `absensi`, `siswa_berkas`, `guru_berkas`

*(Untuk operasi penghapusan fisik saat `local_gc()`, urutan dijalankan secara terbalik dari Tingkat 5 ke Tingkat 3).*

### 9.5 Kontrak Ringkas JSON `/sync/push` dan `/sync/pull`

**Contoh Request `POST /sync/push`:**
```json
{
  "device_id": "d8a1-4b2c-9910",
  "last_pulled_seq": 10450,
  "changes": [
    {
      "local_seq": 41,
      "table": "nilai",
      "operation": "UPSERT",
      "row": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "keanggotaan_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        "mapel_id": "1b9d6bcd-bbfd-4b2d-9b5d-ab8dfbbd4bed",
        "semester_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
        "jenis_nilai_id": "2c5ea4c0-4067-11e9-8bad-9b1deb4d3b7d",
        "urutan_ke": 2,
        "nilai": 85.0,
        "tanggal": "2026-10-26",
        "keterangan": "UH Bab Thaharah",
        "sumber_nilai_id": null,
        "diinput_oleh_guru_id": "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
        "created_at": 1761447600000,
        "updated_at": 1761447600000,
        "deleted": 0,
        "device_id": "d8a1-4b2c-9910"
      }
    }
  ]
}
```

**Contoh Respons `POST /sync/push`:**
```json
{
  "results": [
    {
      "local_seq": 41,
      "status": "APPLIED",
      "canonical_id": "550e8400-e29b-41d4-a716-446655440000",
      "server_seq": 10455,
      "message": null
    }
  ]
}
```
*(Catatan: Jika terjadi Business Key Upsert di mana server mempertahankan UUID lama, `status` bernilai `"MERGED_BY_BUSINESS_KEY"` dan `canonical_id` berisi UUID milik server agar HP mengganti UUID lokalnya).*

**Contoh Respons `GET /sync/pull?since_seq=10450&limit=500`:**
```json
{
  "from_seq": 10450,
  "to_seq": 10482,
  "has_more": false,
  "recalculate_scope": true,
  "active_scope": {
    "semester_aktif_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
    "wali_rombel_ids": ["3f333df6-90a4-4fda-8dd3-9485d27cee36"],
    "pengampu_ids": ["8f14e45fceea-167a-5a36-dedd4bea2543"],
    "allowed_keanggotaan_ids": [
      "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "8d0f7780-8536-51ef-a55c-f18gd2g01bf8"
    ]
  },
  "changes": [
    {
      "table": "nilai",
      "server_seq": 10455,
      "row": { "...": "..." }
    }
  ]
}
```
*(Catatan: Daftar `allowed_keanggotaan_ids` dan `wali_rombel_ids` memudahkan HP menjalankan `local_gc()` dengan cepat dan akurat tanpa perlu mereplikasi logika query server yang kompleks di klien).*

### 9.6 Aturan Validasi Server (Ditegakkan di Server)
1. Satu `keanggotaan_rombel` terbuka per siswa.
2. `nis` wajib unik; duplikat `nisn` dan `*_hash` NIK hanya menghasilkan peringatan (*warning*) agar proses import massal tidak terblokir.
3. **Push `nilai`** hanya diterima jika seluruh syarat hak edit pengampu pada **F10** terpenuhi (termasuk aturan fallback Guru `utama`).
4. **Push `siswa_detail`, `siswa_ortu`, `alamat`** oleh Wali Kelas hanya diizinkan untuk siswa yang sedang memiliki keanggotaan aktif di rombel perwaliannya; server memaksa nilai `diubah_wali_kelas = 1`.
5. **Push `siswa`, `siswa_sensitif`, `keanggotaan_rombel`, `riwayat_status_siswa`, `pengampu`, `pengampu_siswa`** hanya diizinkan dari user dengan role `admin`.
6. Semester atau tahun ajaran dengan `dikunci = 1` menolak semua perubahan data akademik (`nilai`, `absensi`, `keanggotaan_rombel`, `pengampu`).
7. `madrasah.semester_aktif_id` hanya dapat diubah oleh `admin`.
8. Wajib ada tepat satu pengampu `utama` aktif per `(mapel, rombel, semester)` jika mapel tersebut memiliki pengampu aktif di rombel tersebut.

---

## 10. Kriteria Keberhasilan
- Import satu rombel dari Excel selesai kurang dari 5 menit dengan validasi pratinjau yang jelas.
- Naik kelas satu angkatan selesai dalam satu sesi transaksi tanpa data hilang.
- Dua guru menginput nilai bersamaan secara offline (baik untuk urutan penilaian berbeda maupun urutan penilaian yang tidak sengaja sama), hasil tergabung otomatis tanpa error constraint saat sinkronisasi.
- Guru yang mengajar 7A tetapi tidak 7B tidak menerima data siswa 7B di database SQLite HP-nya.
- Pada mapel berkelompok (`sebagian`), guru `pendamping` hanya menerima siswa kelompoknya, dan siswa yang belum memiliki kelompok otomatis masuk ke cakupan Guru `utama` sehingga tidak ada siswa yang tertahan tanpa penilai.
- Saat pengampu dicabut atau siswa pindah kelas, data siswa yang tidak lagi relevan otomatis dibersihkan (`local_gc`) dari HP guru pada sinkronisasi berikutnya.
- Database HP Guru Mapel terbukti bersih dari baris `siswa_detail`, `siswa_ortu`, `alamat`, `siswa_sensitif`, maupun berkas siswa.
- Riwayat siswa dan nilai bawaan (`sumber_nilai_id`) utuh setelah pindah rombel, naik kelas, mutasi, atau lulus.
- Operator dapat memantau perangkat guru yang belum sinkron lebih dari 1 hari.
- Kolom ekspor/impor cocok dengan template EMIS tanpa penyesuaian struktur manual.

---

## 11. Risiko & Mitigasi

| Risiko | Mitigasi |
|---|---|
| Kebocoran data sensitif dari HP yang hilang/dipinjam | Tidak dikirim ke role yang tak berhak, SQLCipher (AES-256) dengan Android Keystore, pencabutan otomatis lewat `local_gc()` saat sinkron, fitur nonaktifkan akun/perangkat dari server |
| Siswa terlewat belum masuk kelompok pada mapel `sebagian` (termasuk siswa pindahan baru) | Otomatis masuk ke cakupan Guru `utama` (aturan fallback F9/F17) + indikator peringatan di layar **Cek Pengampu** Admin |
| Tabrakan *Unique Constraint* saat 2 guru membuat entri `nilai` ke-N secara offline | Mekanisme **Business Key Upsert** di server + pengembalian `canonical_id` ke HP + pencatatan versi kalah di `audit_log` |
| Data lama tertinggal di HP guru setelah pergantian pengampu/wali kelas | Server mengirimkan daftar `active_scope` (`allowed_keanggotaan_ids`) saat `/sync/pull` dan klien mengeksekusi `local_gc()` |
| Field tidak cocok dengan perubahan EMIS | Menggunakan tabel referensi berbasis kode (`ref_item`), pemetaan kolom ekspor dinamis, dan membuat seluruh field selain NIS/Nama/JK bersifat opsional |
| File Excel EMIS berat/lambat diparsing di HP | Delegasi parsing/ekspor `.xlsx` ke server FastAPI (`openpyxl`) saat terhubung ke WiFi lokal, dengan fallback CSV/Excel lokal saat offline |
| HP penuh karena berkas lampiran siswa | Hanya metadata yang disinkronkan; isi berkas diunduh *on-demand* saat dibuka dengan batas kuota cache lokal |
| Error build CI/CD (Gradle / `build_runner`) | Konfigurasi caching GitHub Actions sejak awal, langkah kompilasi modular, inspeksi otomatis log via `gh` CLI |
| Laptop operator rusak atau kunci enkripsi hilang | Aplikasi di HP tetap berfungsi offline; prosedur backup terenkripsi terjadwal dan panduan penyimpanan salinan *Master Key* di media terpisah |