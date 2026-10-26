# CLAUDE.md — Panduan Arsitektur & Konvensi Proyek MTs App

Dokumen ini adalah sumber kebenaran teknis (*single source of truth*) untuk pengerjaan **Aplikasi Manajemen Data & Rekap Nilai MTs** (Flutter Android Offline-First + FastAPI Local Server) berdasarkan **PRD v1.5**. Patuhi seluruh aturan di bawah ini secara ketat.

---

## 1. Lingkungan Kerja & Aturan CI/CD (KRUSIAL)

1. **TANPA BUILD ANDROID LOKAL:**
   - Lingkungan ini **tidak** digunakan untuk menjalankan `flutter build apk` atau kompilasi Gradle secara lokal.
   - Semua kompilasi aplikasi Android dan pengujian terintegrasi dijalankan di **GitHub Actions**.
2. **Alur Kerja Pengembangan:**
   - Tulis/ubah kode secara modular dan bersih.
   - Untuk memvalidasi perubahan: lakukan `git add`, `git commit`, dan `git push`.
   - Pantau proses build dan test menggunakan GitHub CLI:
     ```bash
     gh run list --limit 5
     gh run watch <run-id>
     gh run view <run-id> --log-failed
     ```
   - Jika build gagal di GitHub Actions, baca log error lewat `gh run view --log-failed`, perbaiki kode, lalu push kembali.
3. **Pengujian Server Python (Boleh Lokal jika tersedia):**
   - Pengujian unit FastAPI/SQLite (`pytest`) yang ringan dapat dijalankan secara lokal jika environment Python tersedia, namun tetap wajib lolos di GitHub Actions.

---

## 2. Struktur Repositori (Monorepo)

```text
/
├── CLAUDE.md                 # Panduan utama AI Agent
├── docs/
│   └── PRD.md                # Dokumen PRD v1.5
├── app/                      # Aplikasi Android (Flutter)
│   ├── pubspec.yaml
│   └── lib/
│       ├── core/             # Konstanta, crypto, utilitas, tema
│       ├── data/
│       │   ├── db/           # Skema Drift (SQLCipher), DAO, migrasi
│       │   ├── sync/         # Outbox, Push/Pull engine, local_gc()
│       │   └── repositories/ # Implementasi repositori offline-first
│       ├── domain/           # Kalkulator nilai K13, validator bisnis
│       └── presentation/     # UI Layar & State Management (Bahasa Indonesia)
├── server/                   # Server Lokal Operator (FastAPI + SQLite WAL)
│   ├── requirements.txt
│   ├── alembic/              # Migrasi database server
│   ├── app/
│   │   ├── main.py
│   │   ├── core/             # Config, JWT, AES-256-GCM, HMAC-SHA256
│   │   ├── db/               # SQLite WAL engine, session
│   │   ├── models/           # SQLModel / SQLAlchemy tabel
│   │   ├── schemas/          # Pydantic schemas (identik dengan tabel)
│   │   ├── api/              # Endpoints (/auth, /sync, /import-export, /files)
│   │   └── services/         # Logika sync filter, business key upsert, audit
│   └── tests/                # Pytest suite (sync conflict, role filter, fallback)
└── .github/
    └── workflows/
        ├── build-android.yml # Flutter analyze, test, build_runner, build APK
        └── test-server.yml   # Pytest untuk FastAPI server
```

---

## 3. Aturan Emas Skema & Penamaan Data

1. **Nama Identik 100% (`snake_case`):**
   - Nama tabel dan nama kolom di **SQLite (Drift)**, **JSON Payload**, dan **Python (SQLModel)** WAJIB persis sama dalam `snake_case` Bahasa Indonesia sesuai PRD Bagian 9.2 (contoh: `keanggotaan_rombel`, `diinput_oleh_guru_id`, `sumber_nilai_id`).
   - Di Dart/Drift, gunakan anotasi `.named('nama_kolom')` atau pastikan nama getter menghasilkan kolom SQL `snake_case` yang identik saat serialisasi `toJson()` / `fromJson()`.
2. **Kolom Wajib di Semua Tabel Sinkron:**
   - `id` (`TEXT PRIMARY KEY` — UUID v4, dibuat di sisi pembuat)
   - `created_at` (`INTEGER NOT NULL` — epoch milliseconds UTC)
   - `updated_at` (`INTEGER NOT NULL` — epoch milliseconds UTC)
   - `deleted` (`INTEGER NOT NULL DEFAULT 0` — soft delete `0` atau `1`, **jangan pernah `DELETE` fisik untuk aksi user**)
   - `device_id` (`TEXT NOT NULL` — ID unik perangkat pengubah terakhir)
   - `server_seq` (`INTEGER` — diisi monotonik oleh server saat push berhasil; di HP bernilai `NULL` atau `0` saat masih di outbox)
3. **Tabel Gabung-Per-Kolom (`kolom_ts`):**
   - Hanya tabel: `siswa_detail`, `siswa_ortu`, `alamat`, `guru_detail`.
   - Memiliki kolom `kolom_ts` (`TEXT NOT NULL DEFAULT '{}'`), berisi JSON object `{"nama_kolom": epoch_ms_utc}`.
   - Saat user di HP mengubah satu field (misal `nomor_hp`), hanya timestamp key `"nomor_hp"` di dalam `kolom_ts` yang diperbarui ke waktu sekarang.
4. **Format Tanggal & Referensi:**
   - Tanggal kalender disimpan sebagai `TEXT` dengan format `YYYY-MM-DD`.
   - Kolom referensi menyimpan kode string (`*_kode`, misal `agama_kode`, `pekerjaan_kode`), merujuk pada `ref_item(kategori, kode)`.

---

## 4. Partial Unique Indexes (Wajib di SQLite HP & Server)

Karena sistem memakai *soft delete* (`deleted = 1`) dan riwayat masa tugas (`tanggal_selesai`), **JANGAN** gunakan constraint `UNIQUE` biasa pada tabel-tabel berikut. Gunakan **Partial Unique Index** lewat custom SQL statement saat inisialisasi/migrasi:

```sql
-- 1. Satu keanggotaan rombel terbuka per siswa
CREATE UNIQUE INDEX IF NOT EXISTS idx_keanggotaan_terbuka_unik
ON keanggotaan_rombel(siswa_id)
WHERE tanggal_keluar IS NULL AND deleted = 0;

-- 2. Satu pengampu UTAMA aktif per (mapel, rombel, semester)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_utama_aktif
ON pengampu(mapel_id, rombel_id, semester_id)
WHERE peran = 'utama' AND tanggal_selesai IS NULL AND deleted = 0;

-- 3. Satu penugasan aktif per guru pada (mapel, rombel, semester)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_guru_aktif
ON pengampu(guru_id, mapel_id, rombel_id, semester_id)
WHERE tanggal_selesai IS NULL AND deleted = 0;

-- 4. Business Key Nilai (1 nilai aktif per siswa, mapel, semester, jenis, urutan_ke)
CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_bisnis_unik
ON nilai(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)
WHERE deleted = 0;

-- 5. Business Key Absensi (1 absensi aktif per siswa per tanggal)
CREATE UNIQUE INDEX IF NOT EXISTS idx_absensi_bisnis_unik
ON absensi(keanggotaan_id, tanggal)
WHERE deleted = 0;
```

---

## 5. Logika Bisnis Kritis yang Tidak Boleh Salah

### 5.1. Role & Hak Akses Kontekstual
- Tabel `user_role` hanya menyimpan `admin` dan `kepala`.
- Status **Wali Kelas** diturunkan secara dinamis dari `rombel.wali_guru_id` pada tahun ajaran/semester aktif.
- Status **Guru Mapel** diturunkan secara dinamis dari tabel `pengampu` pada semester aktif (`tanggal_selesai IS NULL AND deleted = 0`).
- Satu guru bisa menjadi Wali Kelas di 7A sekaligus Guru Mapel di 7A, 7B, dan 8C. Hak aksesnya adalah gabungan (*union*) dari perannya pada masing-masing konteks.

### 5.2. Logika Pengampu & Aturan Fallback Guru `utama`
- Setiap `(mapel_id, rombel_id, semester_id)` yang memiliki pengampu aktif **wajib memiliki tepat satu** baris dengan `peran = 'utama'`. Guru lainnya berperan `'pendamping'`.
- Mode `cakupan` terdiri dari `'seluruh'` (default) atau `'sebagian'` (kelompok).
- **Aturan Fallback (Sangat Penting):**
  Pada mode `cakupan = 'sebagian'`, anggota kelompok dipetakan di tabel `pengampu_siswa(pengampu_id, keanggotaan_id)`.
  - **Guru `pendamping`** hanya berhak melihat dan menilai siswa yang ada di `pengampu_siswa` miliknya.
  - **Guru `utama`** berhak melihat dan menilai siswa di `pengampu_siswa` miliknya **DITAMBAH (`UNION`)** seluruh siswa aktif di rombel tersebut yang **belum terdaftar di `pengampu_siswa` milik pengampu aktif mana pun** untuk mapel & semester tersebut (misal siswa baru pindah rombel atau belum dibagi kelompoknya oleh Admin).

### 5.3. Pindah Rombel (7A → 7B)
- Dijalankan oleh Admin dalam **satu transaksi database**:
  1. Validasi kedua rombel berada di tahun ajaran dan tingkat yang sama, semester belum dikunci.
  2. Tutup baris `keanggotaan_rombel` lama (isi `tanggal_keluar` dan `alasan_keluar = 'pindah_rombel'`).
  3. Buat baris `keanggotaan_rombel` baru di rombel tujuan dengan mengisi `sumber_keanggotaan_id = id_lama`.
  4. Jika opsi **"Bawa Nilai"** dipilih (default): salin semua baris `nilai` aktif dari `keanggotaan_id` lama ke `keanggotaan_id` baru, serta isi `sumber_nilai_id = id_nilai_lama`. Baris nilai di rombel lama tetap utuh (tidak dihapus).
  5. Catat di `riwayat_status_siswa` dan `audit_log`.

### 5.4. Kalkulasi Nilai Kurikulum 2013
- Nilai Akhir **tidak disimpan di database**, melainkan dihitung *on-the-fly* di layar / laporan:
  1. Hitung rata-rata per `jenis_nilai` yang memiliki entri (Pengetahuan: `TGS`, `UH`, `PAS`/`PAT`; Keterampilan: `PRY`, `PRT`, `UK`).
  2. Kalikan dengan `bobot_nilai` masing-masing, lalu bagi dengan total bobot komponen yang aktif.
  3. Tentukan predikat berdasarkan KKM ($\text{interval} = (100 - \text{KKM}) / 3$):
     - $D < \text{KKM}$
     - $\text{KKM} \le C < \text{KKM} + \text{interval}$
     - $\text{KKM} + \text{interval} \le B < \text{KKM} + 2 \times \text{interval}$
     - $A \ge \text{KKM} + 2 \times \text{interval}$

---

## 6. Mesin Sinkronisasi (`/sync/push` & `/sync/pull`)

### 6.1. Urutan Ketergantungan Tabel (*Foreign Key Order*)
Setiap batch insert/upsert saat Push maupun Pull **wajib** diurutkan sesuai tingkat berikut:
1. **Tingkat 1:** `ref_item`, `ref_wilayah`, `tahun_ajaran`, `semester`, `mapel`, `jenis_nilai`
2. **Tingkat 2:** `guru`, `guru_detail`, `guru_sensitif`, `madrasah`, `user`, `user_role`
3. **Tingkat 3:** `rombel`, `siswa`, `siswa_detail`, `siswa_ortu`, `siswa_sensitif`, `alamat`
4. **Tingkat 4:** `keanggotaan_rombel`, `riwayat_status_siswa`, `pengampu`, `pengampu_siswa`, `bobot_nilai`, `pengaturan_kkm`
5. **Tingkat 5:** `nilai`, `absensi`, `siswa_berkas`, `guru_berkas`

### 6.2. Resolusi Konflik di Server (`POST /sync/push`)
1. **Validasi Otorisasi Server:** Tolak perubahan jika semester terkunci (`dikunci = 1`) atau user tidak punya hak atas baris tersebut (lihat PRD Bagian 9.6).
2. **Tabel `kolom_ts` (`siswa_detail`, `siswa_ortu`, `alamat`, `guru_detail`):**
   - Bandingkan setiap key timestamp di `row.kolom_ts` dengan `server.kolom_ts`.
   - Hanya update kolom yang timestamp-nya `>=` timestamp di server. Gabungkan JSON `kolom_ts`.
   - Jika pengirim adalah Wali Kelas (bukan Admin), paksa `diubah_wali_kelas = 1`.
3. **Business Key Upsert (`nilai` dan `absensi`):**
   - Sebelum insert `nilai` baru, cek apakah sudah ada baris aktif (`deleted = 0`) dengan `(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)` yang sama di server (atau `(keanggotaan_id, tanggal)` untuk `absensi`).
   - Jika ditemukan dengan UUID berbeda:
     - **Jangan lempar IntegrityError.**
     - Pertahankan `id` (UUID) yang sudah ada di server sebagai `canonical_id`.
     - Jika `incoming.updated_at >= existing.updated_at`, perbarui nilai, tanggal, keterangan, `diinput_oleh_guru_id`, dan `updated_at` pada baris server tersebut.
     - Catat nilai yang tertimpa ke `audit_log`.
     - Kembalikan status `"MERGED_BY_BUSINESS_KEY"` beserta `canonical_id` ke HP agar HP menghapus UUID lokal sementaranya dan memakai `canonical_id`.

### 6.3. Filter Role & Local Garbage Collection (`GET /sync/pull`)
- Server **tidak boleh** mengirim `siswa_detail`, `siswa_ortu`, `alamat`, `siswa_sensitif`, dan `siswa_berkas` ke user yang hanya berperan sebagai Guru Mapel.
- Server menyertakan objek `active_scope` berisi `allowed_keanggotaan_ids` dan `wali_rombel_ids` pada respons `/sync/pull`.
- Di sisi HP (Flutter), setelah menerapkan semua baris dari `changes`, jika `recalculate_scope == true` (atau `scope_hash` berubah), jalankan fungsi `local_gc()`:
  - Hapus secara lokal (dari Tingkat 5 turun ke Tingkat 3) baris data siswa/nilai/absensi/detail yang `keanggotaan_id` atau `siswa_id`-nya tidak lagi termasuk dalam `active_scope` milik user tersebut, **kecuali** baris yang masih mengantre di tabel `outbox`.

---

## 7. Keamanan & Enkripsi

1. **Jangan Pernah Log Data Sensitif:**
   - Kolom pada `siswa_sensitif` dan `guru_sensitif` (NIK, KK, KIP, KPS, PKH) tidak boleh dicetak ke `print()`, `debugPrint()`, atau logger Python.
2. **Enkripsi Kolom Sensitif di Server:**
   - Gunakan `AES-256-GCM` (library `cryptography` di Python). Format penyimpanan di kolom `*_enc`: `base64(nonce_12_bytes + ciphertext + tag_16_bytes)`.
   - Gunakan `HMAC-SHA256` dengan secret key server untuk mengisi kolom `*_hash` (`nik_siswa_hash`, `no_kk_hash`, `nik_hash`) guna keperluan deteksi duplikat. Kolom `*_hash` hanya ada di server dan tidak dikirim ke HP.
3. **Database Lokal HP:**
   - Gunakan `drift` dengan `sqlcipher_flutter_libs`. Kunci enkripsi 256-bit digenerate secara acak di HP dan disimpan di dalam `flutter_secure_storage` (Android Keystore).

---

## 8. Panduan UI/UX Flutter
- Seluruh teks antarmuka, pesan validasi, dan pesan error menggunakan **Bahasa Indonesia** yang natural dan mudah dipahami guru madrasah.
- Tampilkan **Banner Status Sinkronisasi** di Beranda jika ada item di `outbox` atau jika waktu sinkronisasi terakhir melewati 24 jam.
- Pada layar Input Nilai Guru, tampilkan badge kecil `"Bawaan rombel asal"` jika `sumber_nilai_id != null`.
- Gunakan `FLAG_SECURE` saat pengguna membuka detail data sensitif (NIK/KK) atau melihat dokumen berkas siswa.