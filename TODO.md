# TODO.md — Checklist Pengerjaan MTs App (PRD v1.5)

> **ATURAN WAJIB:**  
> Dokumen ini adalah panduan kontrol pengerjaan (*living checklist*). **Setiap kali menyelesaikan sebuah checkpoint atau sub-tugas, file ini WAJIB diperbarui (`[x]`) dan dicatat tanggal/commit-nya agar arah pengembangan tetap konsisten dan tidak tersesat.**

---

## Ringkasan Progres Keseluruhan

| Checkpoint | Deskripsi | Status | Tanggal Selesai |
|---|---|:---:|:---:|
| **CP-0** | Fondasi Monorepo, Golden Schema, Engine Sync, CI/CD Android | **SELESAI (100%)** | 2026-10-26 |
| **CP-1** | Penegakan Hak Push Server (PRD 9.6) & Data Master Seeder | **SELESAI (100%)** | 2026-10-26 |
| **CP-2** | Integrasi Penuh Layar UI Flutter ke Database Drift SQLite | **SELESAI (100%)** | 2026-10-26 |
| **CP-3** | Offline Authentication, Keystore PIN Cache, & QR Pairing | **SELESAI (100%)** | 2026-10-26 |
| **CP-4** | Operasi Akademik Admin: Naik Kelas, Salin Semester, Cek Pengampu | **BELUM (0%)** | - |
| **CP-5** | Rekap Nilai K13 Lengkap, Ranking Rombel, & Rekap Absensi | **BELUM (0%)** | - |
| **CP-6** | Sandboxed File Viewer (F5), Offline EMIS, & Backup Terenkripsi | **BELUM (0%)** | - |

---

## Checkpoint 0: Fondasi Monorepo & Core Engine (SUDAH SELESAI)
- [x] Inisialisasi Git monorepo (`main`) terhubung ke `Nietzsche86/si-mts-rth.git`.
- [x] Pipeline CI/CD: `.github/workflows/build-android.yml` dan `test-server.yml`.
- [x] Verifikasi build APK release split (`arm64-v8a`, `armeabi-v7a`) di GitHub Actions (Run `40285086672` PASSED).
- [x] 26 Model SQLModel Python (`server/app/models/`) & Drift SQLite (`app/lib/data/db/`).
- [x] 5 Partial Unique Indexes terpasang di SQLite & Server (idx keanggotaan terbuka, pengampu utama, pengampu guru, business key nilai, business key absensi).
- [x] Modul kriptografi: AES-256-GCM (`nonce_12 + cipher + tag_16`), HMAC-SHA256 blind index, Argon2/bcrypt PIN.
- [x] Engine sinkronisasi: FK Order 1–5, `kolom_ts` merge, Business Key Upsert (canonical ID), fallback Guru Utama.
- [x] Kalkulator Nilai K13 (`KalkulatorK13`): rata-rata terbobot, interval KKM dinamis $(100 - \text{KKM}) / 3$, predikat A–D.
- [x] Unit test: 9/9 pytest lulus, 13/13 flutter test lulus, 0 issues pada `dart analyze`.

---

## Checkpoint 1: Penegakan Hak Push Server (PRD 9.6) & Master Data Seeder
Target: Server FastAPI menolak pelanggaran hak akses saat sync push dan memiliki master data awal madrasah.

- [x] **1.1 Penegakan Aturan Push Server di `sync_service.py` (PRD 9.6):**
  - [x] Tolak push tabel Admin-only (`siswa`, `siswa_sensitif`, `keanggotaan_rombel`, `riwayat_status_siswa`, `pengampu`, `pengampu_siswa`, `bobot_nilai`, `pengaturan_kkm`, `tahun_ajaran`, `semester`, `mapel`, `madrasah`) jika user bukan role `admin`.
  - [x] Batasi push Wali Kelas pada `siswa_detail`, `siswa_ortu`, `alamat` hanya untuk siswa di rombel perwaliannya, serta paksa `diubah_wali_kelas = 1`.
  - [x] Tolak push data akademik (`nilai`, `absensi`, `keanggotaan_rombel`, `pengampu`) jika semester terkait memiliki `dikunci = 1`.
  - [x] Tolak push `nilai` oleh Guru Mapel jika tidak memenuhi syarat hak edit F10 (bukan pengampu aktif atau di luar cakupan).
- [x] **1.2 Master Data Initial Seeder (`server/app/db/seeder.py`):**
  - [x] Data Madrasah: MTs Roudhotut Thowalib, NSM, NPSN, semester aktif default.
  - [x] 14 Mapel Standar Kemenag (Qur'an Hadis, Akidah Akhlak, Fikih, SKI, Bahasa Arab, PPKn, Bahasa Indonesia, Matematika, IPA, IPS, Bahasa Inggris, SBK, Penjasorkes, Prakarya).
  - [x] 7 Jenis Nilai: `TGS`, `UH`, `PAS`, `PAT`, `PRY`, `PRT`, `UK`.
  - [x] Pengaturan KKM global (75.0) dan Bobot Nilai standar K13.
  - [x] Referensi Kemenag/EMIS (`ref_item`): agama, status hidup, pekerjaan, pendidikan, penghasilan, hubungan keluarga, jenis pendaftaran.
  - [x] Rombel awal (7A, 7B, 8A, 9A) + sample akun Admin & Guru.
- [x] **1.3 Verifikasi Otomatis (Pytest):**
  - [x] Test push rejection untuk non-admin pada tabel dilindungi (14/14 Pytest passing).
  - [x] Test push rejection pada semester terkunci.
  - [x] Test seeder berjalan idempoten tanpa duplikasi.

---

## Checkpoint 2: Integrasi Layar UI Flutter ke Database Drift SQLite Lokal (SUDAH SELESAI)
Target: Seluruh antarmuka Flutter tidak lagi memakai data tiruan (*mock*), melainkan terhubung langsung ke SQLite terenkripsi.

- [x] **2.1 State Management & Dependency Injection (Riverpod):**
  - [x] Buat `database_providers.dart` untuk instance `AppDatabase` tunggal & seeder idempoten.
  - [x] Provider repositori: `siswaRepoProvider`, `penilaianRepoProvider`, `absensiRepoProvider`, `rombelRepoProvider`, `pengampuRepoProvider`.
  - [x] Provider user session aktif (`currentUserProvider`, `activeSemesterProvider`, `pendingOutboxCountProvider`).
- [x] **2.2 Sambungkan Beranda "Kelas Saya" (`main.dart`):**
  - [x] Query daftar pengampu aktif guru dari `PengampuRepository.getPengampuSummaryForGuru`.
  - [x] Tampilkan kartu kelas dinamis dengan hitungan siswa riil dari SQLite.
  - [x] Tampilkan *progress bar* persentase entri nilai riil.
  - [x] Tampilkan chip "+X belum dikelompokkan" jika guru adalah Guru Utama dan terdapat siswa *fallback*.
- [x] **2.3 Sambungkan Layar Input Nilai Cepat (`input_nilai_screen.dart`):**
  - [x] Muat daftar siswa aktif di rombel terpilih dari `KeanggotaanRombel` & `Siswa`.
  - [x] Tampilkan nilai yang tersimpan untuk jenis dan urutan penilaian terpilih (`TGS`, `UH`, dst.).
  - [x] Simpan otomatis ke SQLite + antrean `outbox` saat input berpindah (`FocusNode` / tombol *Next*).
  - [x] Validasi visual: kotak merah muda `#FEE2E2` jika `< KKM`, getar jika `> 100` atau `< 0`.
  - [x] Tampilkan badge `Bawaan rombel asal` jika `sumber_nilai_id != null`.
- [x] **2.4 Sambungkan Layar Absensi Harian (`input_absensi_screen.dart`):**
  - [x] Muat daftar kehadiran siswa sesuai tanggal yang dipilih.
  - [x] Tombol `Set Semua Hadir (H)` memperbarui seluruh siswa dan memasukkan perubahan ke `outbox`.
  - [x] Segmented pill `[H] [S] [I] [A]` menyimpan status individual ke SQLite seketika.
- [x] **2.5 Sambungkan Form Siswa Modular A–G (`siswa_form_screen.dart`):**
  - [x] Muat profil lengkap (`siswa`, `siswa_detail`, `siswa_ortu`, `alamat`, `siswa_sensitif`).
  - [x] Simpan perubahan dengan pelacakan `kolom_ts` per field.
  - [x] Timer 15 detik unmasking NIK/KK mencatat event ke `audit_log`.
- [x] **2.6 Verifikasi:**
  - [x] Jalankan `flutter test` dan pastikan seluruh test widget & integrasi lolos 100% (17/17 tests passing).

---

## Checkpoint 3: Offline Authentication & QR Server Pairing (SUDAH SELESAI)
Target: Guru dapat login offline dengan PIN 6-digit dan menghubungkan aplikasi ke laptop operator via QR.

- [x] **3.1 Kredensial Lokal Terenkripsi (Offline Login):**
  - [x] Saat login online pertama kali ke `/api/v1/auth/login`: simpan PIN hash (salted SHA-256), token JWT, data user, dan role di penyimpanan lokal aman (`flutter_secure_storage`).
  - [x] Saat offline: verifikasi input PIN terhadap PIN hash lokal di Android Keystore atau akun seeder SQLite.
  - [x] Batasi percobaan login gagal (kunci selama 15 menit setelah 5x salah).
  - [x] Bangun model sesi `CurrentUserSession` secara kontekstual lengkap dengan status `isWaliKelas` dan nama rombel perwalian.
- [x] **3.2 QR Scanner & Server Pairing (`sync_pairing_screen.dart`):**
  - [x] Terapkan parser/scanner QR untuk membaca payload pairing server: `{"url": "...", "fingerprint": "..."}`.
  - [x] Simpan konfigurasi server (`server_url`, `server_fingerprint`) ke tabel `sync_state`.
  - [x] Tombol "Sinkron Sekarang": panggil `DioSyncClient.sync()` lengkap dengan push outbox, pull delta, dan `LocalGarbageCollector`.
  - [x] Banner status sinkronisasi di beranda bereaksi dinamis terhadap jumlah outbox dan selisih waktu sinkron terakhir (`lastSyncTimestampProvider`).
  - [x] Sediakan opsi "Keluar Akun (Logout)" di Tab Pengaturan untuk beralih kembali ke layar login.
- [x] **3.3 Verifikasi Otomatis:**
  - [x] Seluruh 8 test suite di `auth_sync_test.dart` lolos 100%.
  - [x] Seluruh 25 flutter test di proyek lolos 100%.
  - [x] `dart analyze lib test` melaporkan 0 issues.
  - [x] Seluruh 14 pytest server tetap lulus 100%.

---

## Checkpoint 4: Operasi Akademik Admin (PRD F7, F8, F9)
Target: Admin madrasah dapat menjalankan mutasi massal, naik kelas, pergantian semester, dan memantau penugasan guru.

- [ ] **4.1 Endpoint Transaksional Server:**
  - [ ] `POST /api/v1/akademik/naik-kelas-massal`: Menerima daftar siswa, menutup keanggotaan lama, membuka keanggotaan baru, mencatat riwayat status.
  - [ ] `POST /api/v1/akademik/pergantian-tahun`: Membuat tahun/semester baru, menyalin rombel, menyalin pengampu semester lalu, mengunci semester lama.
- [ ] **4.2 Layar Naik Kelas Massal di App (Admin):**
  - [ ] Pratinjau daftar siswa per rombel dengan opsi naik / tinggal kelas.
  - [ ] Pemilihan rombel tujuan dan eksekusi transaksi tunggal.
- [ ] **4.3 Layar & Deteksi "Cek Pengampu" (PRD F9 106–111):**
  - [ ] Deteksi anomali 1: Mapel aktif tanpa Guru Utama.
  - [ ] Deteksi anomali 2: Siswa aktif belum terpetakan pada mapel kelompok (sedang di-fallback ke Guru Utama).
  - [ ] Deteksi anomali 3: Siswa terdaftar ganda di lebih dari satu kelompok guru.
  - [ ] Deteksi anomali 4: Guru nonaktif yang masih ditugaskan.
- [ ] **4.4 Dialog Pembagian Kelompok Siswa:**
  - [ ] Tombol "Bagi Otomatis Ganjil/Genap".
  - [ ] Tombol "Bagi Rata Sesuai Urutan Absen".
  - [ ] Simpan pemetaan ke tabel `pengampu_siswa`.

---

## Checkpoint 5: Rekap Nilai K13 Lengkap & Laporan (PRD F11, F12, F13)
Target: Rekapitulasi nilai otomatis sesuai kurikulum 2013 dan rekap kehadiran periodik.

- [ ] **5.1 Layar Rekap Nilai Rombel & Siswa:**
  - [ ] Matriks nilai siswa per mapel: rata-rata pengetahuan, rata-rata keterampilan, nilai akhir, predikat K13.
  - [ ] Perhitungan ranking siswa dalam satu rombel berdasarkan nilai akhir gabungan.
  - [ ] Tampilan progres kelengkapan nilai per pengampu (termasuk pengampu kelompok).
- [ ] **5.2 Dashboard Kepala Madrasah:**
  - [ ] Ringkasan statistik kehadiran siswa per rombel/tingkat.
  - [ ] Ringkasan persentase ketuntasan belajar per mata pelajaran terhadap KKM.
- [ ] **5.3 Rekap Absensi Bulanan & Semester:**
  - [ ] Ringkasan total H, S, I, A per siswa dalam rentang tanggal tertentu.

---

## Checkpoint 6: Berkas Siswa Sandboxed, Ekspor/Impor Offline, & Backup Terenkripsi
Target: Pengelolaan berkas aman, fallback import/export lokal, dan pemulihan bencana database.

- [ ] **6.1 Berkas Siswa & Viewer Sandboxed (PRD F5):**
  - [ ] Kompresi gambar kamera (±480 px, <100 KB) dan dokumen (<1 MB).
  - [ ] Server endpoint `/api/v1/berkas/upload` dan download dengan dekripsi AES-256-GCM.
  - [ ] Viewer PDF & Foto bawaan aplikasi dengan perlindungan `FLAG_SECURE`.
- [ ] **6.2 Fallback Ekspor / Impor Lokal di HP (PRD F15):**
  - [ ] Generator & parser CSV/Excel lokal pada perangkat saat tidak terhubung ke server operator.
- [ ] **6.3 Backup & Restore Terenkripsi (PRD F16):**
  - [ ] Endpoint/skrip server untuk membuat cadangan database SQLite WAL + seluruh berkas lampiran terenkripsi password (AES-256).
  - [ ] Fitur verifikasi integritas backup dan restore database.

---

## Prosedur Verifikasi Tiap Checkpoint

1. **Python / Server:**
   ```powershell
   $env:PYTHONPATH='server'
   pytest server/tests
   ```
2. **Flutter / Klien:**
   ```powershell
   flutter test
   dart analyze app/lib app/test
   ```
3. **Android APK Compilation (GitHub Actions):**
   ```powershell
   git add .
   git commit -m "feat/fix: <keterangan checkpoint>"
   git push origin main
   gh run watch
   ```
4. **Update Dokumen Ini:**
   Ubah tanda `[ ]` menjadi `[x]` pada setiap item yang selesai dan perbarui tabel ringkasan di atas.
