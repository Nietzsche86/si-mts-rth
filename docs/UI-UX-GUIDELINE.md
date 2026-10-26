# UI/UX Design Guideline — Aplikasi Manajemen Data & Rekap Nilai MTS ROUDHOTUT THOWALIB

**Gaya Visual:** *Flat Modern Design*, Clean Aesthetic, Tactile Interactive, dengan Harmoni Warna Khas Islami (*Emerald Jade, Warm Sand, & Muted Gold*).
**Target Pengguna:** Guru Mapel, Wali Kelas, Kepala Madrasah, dan Operator/Admin MTs (rentang usia 22–58 tahun, sering menggunakan aplikasi di dalam kelas dengan satu tangan).

---

## 1. Filosofi Desain

1. **Flat Modern & Clean Surface:**
   - Menghindari *drop shadow* tebal yang kuno atau gradien yang berlebihan.
   - Kedalaman visual (*hierarchy*) dibangun melalui **kontras warna latar (*surface layering*)** dan **garis tepi tipis (*1px subtle border*)**.
2. **Harmoni Islami Kontemporer:**
   - Mengangkat warna **Hijau Zamrud (*Emerald/Jade*)** sebagai identitas keislaman/madrasah yang teduh, dipadukan dengan **Krem Pasir Hangat (*Warm Alabaster/Sand*)** agar mata tidak cepat lelah saat menginput ratusan nilai, serta aksen **Emas Kalem (*Warm Amber/Gold*)** untuk elemen penting dan predikat.
   - Ornamen geometris Islami (*Rub el Hizb* / bintang segi delapan) hanya digunakan secara samar (*opacity* 3%–5%) pada *header card* beranda atau layar login—tidak pernah mengganggu area kerja tabel/form.
3. **Interaktif & Taktil (*Micro-Interactions*):**
   - Setiap ketukan pada kartu, tombol absensi (`H/S/I/A`), atau baris nilai memberikan umpan balik visual instan (perubahan warna *surface*, animasi transisi *smooth* 150ms–200ms, dan `HapticFeedback.lightImpact()`).
4. **Ramah Guru (*Thumb-Friendly & High Legibility*):**
   - Area ketuk minimal `48x48 dp`.
   - Angka nilai dan NIS menggunakan fitur font **`tabularFigures`** agar lurus sejajar secara vertikal dan mudah dipindai mata.

---

## 2. Palet Warna Harmoni Islami (Color Tokens)

### 2.1. Warna Utama & Latar (Light Mode — Default Utama)

| Token | Nama Warna | Hex Code | Penggunaan |
| :--- | :--- | :--- | :--- |
| `primary` | **Madrasah Emerald** | `#0F6E56` | AppBar utama, tombol aksi primer (Simpan/Sinkron), indikator aktif |
| `primaryDark` | **Deep Cypress** | `#085041` | Status bar, *pressed state* tombol primer, kartu header beranda |
| `primaryContainer` | **Soft Mint Surface** | `#E1F5EE` | Latar chip aktif, highlight baris terpilih, latar ikon kartu |
| `onPrimaryContainer`| **Dark Emerald Text** | `#04342C` | Teks/ikon di atas `primaryContainer` |
| `secondary` | **Warm Gold / Amber** | `#C68B2C` | Aksen sekunder, badge peran "Guru Utama", indikator bintang/peringkat |
| `secondaryContainer`| **Creamy Gold** | `#FDF3DC` | Latar badge informasi, label "Kelompok Saya", banner pengingat ringan |
| `background` | **Warm Alabaster** | `#F6F8F6` | Latar belakang utama layar (bukan putih menyilaukan `#FFFFFF`) |
| `surface` | **Pure White** | `#FFFFFF` | Latar kartu (*Card*), *Bottom Sheet*, baris tabel, dan kolom input |
| `surfaceVariant` | **Sage Grey Tint** | `#EDF2EF` | Latar kolom pencarian, latar *segmented button* tidak aktif, header tabel |
| `outline` | **Subtle Sage Border** | `#D5E0DA` | Garis tepi kartu (`1px`), garis pembatas tabel, border input normal |
| `textPrimary` | **Forest Charcoal** | `#16241E` | Judul, nama siswa, angka nilai (kontras tinggi, lebih lembut dari `#000000`) |
| `textSecondary` | **Muted Slate Green** | `#52665E` | NIS/NISN, label form, sub-judul, keterangan waktu |
| `textHint` | **Cool Grey Sage** | `#889992` | Placeholder input, teks nonaktif |

### 2.2. Warna Semantik (Status Sinkronisasi, Nilai K13, & Absensi)

| Konteks | Status | Warna Utama (Hex) | Latar Lembut (Hex) | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| **Sinkronisasi** | Tersinkron / Aman | `#0F6E56` | `#E1F5EE` | Semua data sudah masuk ke server |
| | Antrean Outbox (< 24j) | `#D97706` | `#FEF3C7` | Ada perubahan lokal menunggu WiFi |
| | Belum Sinkron (> 72j) | `#DC2626` | `#FEE2E2` | Peringatan kritis wajib sinkron ke operator |
| **Nilai & KKM** | Predikat A (Sangat Baik)| `#0D9488` | `#CCFBF1` | Nilai $\ge \text{KKM} + 2 \times \text{interval}$ |
| | Predikat B & C (Tuntas) | `#15803D` | `#DCFCE7` | Nilai $\ge \text{KKM}$ |
| | Predikat D (`< KKM`) | `#B91C1C` | `#FEE2E2` | **Remedial / Di bawah KKM** (teks tebal + badge merah lembut) |
| **Absensi** | **H** — Hadir | `#0F6E56` | `#E1F5EE` | Default terpilih cepat |
| | **S** — Sakit | `#0284C7` | `#E0F2FE` | Biru tenang |
| | **I** — Izin | `#D97706` | `#FEF3C7` | Kuning/Amber |
| | **A** — Alpa | `#DC2626` | `#FEE2E2` | Merah tegas |

---

## 3. Tipografi & Hierarki Teks

- **Font Utama (UI & Teks):** **Plus Jakarta Sans** (atau `Inter` sebagai fallback). Modern, geometris, sangat jelas di layar Android berbagai ukuran.
- **Font Angka (Nilai, NIS, NISN, NIK, Statistik):** Wajib mengaktifkan `FontFeature.tabularFigures()` agar lebar digit `0–9` sama rata.

| Gaya Teks | Ukuran | Ketebalan | Penggunaan |
| :--- | :--- | :--- | :--- |
| `headlineMedium` | `20 sp` | `Bold (700)` | Judul halaman utama, Nama Madrasah di Beranda |
| `titleLarge` | `17 sp` | `SemiBold (600)`| Judul Kartu Kelas ("Bahasa Arab — 7A"), Nama Siswa di Detail |
| `titleMedium` | `15 sp` | `SemiBold (600)`| Nama Siswa di daftar/tabel nilai, judul bagian form (A–G) |
| `bodyMedium` | `14 sp` | `Regular (400)` | Isi form, alamat, informasi umum |
| `labelLarge` | `14 sp` | `SemiBold (600)`| Teks tombol, tab aktif, chip filter |
| `labelSmall` | `11 sp` | `Medium (500)` | Badge status ("Bawaan rombel asal", "Kelompok Saya", "Diubah Wali Kelas") |

---

## 4. Aturan Bentuk, Border, & Spasi (Flat Modern Rules)

1. **Zero Elevation + Crisp Border:**
   - Semua `Card` menggunakan `elevation: 0`, warna latar `#FFFFFF`, dan `BorderSide(color: Color(0xFFD5E0DA), width: 1.0)`.
   - Saat kartu ditekan (*pressed/selected*), border berubah menjadi `#0F6E56` (`width: 1.5`) dan latar berubah halus ke `#F4FBF8`.
2. **Border Radius Konsisten:**
   - Kartu Utama & Dialog: `16 dp`
   - Tombol, Input Field, & Banner: `12 dp`
   - Chip, Badge, & Tombol Nilai/Absensi: `8 dp`
3. **Grid & Padding:**
   - Margin tepi layar: `16 dp`
   - Jarak antar kartu: `12 dp`
   - Padding dalam kartu: `16 dp`

---

## 5. Desain Komponen Spesifik Aplikasi MTs

### 5.1. Banner Status Sinkronisasi (Sticky di Atas Beranda)
- **Desain:** Kotak flat dengan `borderRadius: 12 dp` dan border `1px` sesuai warna status.
- **Isi:** Ikon awan/sinkron beranimasi putar saat aktif + teks ringkas (`"12 perubahan belum tersinkron • Terakhir 2 jam lalu"`) + tombol aksi cepat **`Sinkron`** di sisi kanan.
- **Transisi Warna:**
  - *Hijau Lembut (`#E1F5EE`)*: `"Semua data tersinkron ke server"` (dapat disembunyikan otomatis setelah 3 detik).
  - *Kuning Amber (`#FEF3C7`)*: Muncul ketika `outbox > 0` atau belum sinkron $> 24\text{ jam}$.
  - *Merah Muda (`#FEE2E2`)*: Muncul ketika belum sinkron $> 72\text{ jam}$.

### 5.2. Kartu "Kelas Saya" (Layar Beranda Guru)
- Menampilkan mata pelajaran dan rombel dengan jelas, contoh:
  - Baris atas: Badge **`7A`** (latar `#0F6E56`, teks putih) + Judul **`Bahasa Arab`** + Badge peran (`Utama` atau `Pendamping`).
  - Baris tengah (Konteks Cakupan):
    - Jika `seluruh`: `"Seluruh kelas • 32 Siswa"`
    - Jika `sebagian`: Chip emas lembut `"Kelompok Saya • 16 Siswa"` (ditambah chip peringatan `"+2 belum dikelompokkan"` khusus Guru Utama jika ada siswa *fallback*).
  - Baris bawah: Progress bar tipis (`height: 6 dp`) kelengkapan nilai semester aktif (misal: `"UH 2 terisi 30/32 siswa — 94%"`).

### 5.3. Layar Input Nilai Cepat (Fast-Entry Grid / List)
Guru sering menginput nilai 30+ siswa sekaligus di HP. Hindari membuka dialog baru untuk setiap siswa:
- **Header Sticky:** Pilihan Jenis Nilai (`TGS`, `UH`, `PAS`, `PAT`, `PRY`, `PRT`, `UK`) menggunakan *Horizontal ChoiceChips* + tombol `+ Tambah Urutan (UH 3)`. Info KKM tampil di pojok kanan (`KKM: 75`).
- **Baris Siswa Interaktif:**
  - Kiri: Nomor urut, Nama Siswa, NIS.
  - Bawah Nama (Kondisional):
    - Jika `sumber_nilai_id != null`: Tampilkan badge kecil biru-hijau **`Bawaan rombel asal (7A)`**.
    - Jika `diinput_oleh_guru_id` berbeda (pada mode 2 guru `seluruh`): Teks kecil `"Oleh: Ust. Ahmad"`.
  - Kanan: Kotak input angka (`width: 72 dp`, `height: 44 dp`), teks rata tengah, font `16 sp SemiBold tabularFigures`.
  - **Fitur Keyboard Cepat:** Keyboard numerik dilengkapi tombol **`Lanjut (Next)`** yang langsung memindahkan kursor ke siswa di bawahnya + otomatis menyimpan ke database lokal (`outbox`) setiap kali fokus berpindah.
  - **Validasi Visual Langsung:**
    - Nilai `< KKM`: Kotak input otomatis berubah latar menjadi `#FEE2E2` dengan teks merah `#B91C1C`.
    - Nilai `> 100` atau `< 0`: Getar (*haptic error*) + border merah tegas.

### 5.4. Input Absensi Satu Ketuk (Wali Kelas)
- Secara default, tombol **`Set Semua Hadir (H)`** tersedia di bagian atas agar Wali Kelas cukup mengubah 1–2 siswa yang tidak hadir.
- Setiap baris siswa memiliki *Segmented Pill* 4 tombol: **`[ H ] [ S ] [ I ] [ A ]`**.
- Mengetuk salah satu huruf langsung mengubah warna pil sesuai warna semantik absensi dengan animasi *scale-bounce* halus (`150ms`).

### 5.5. Komponen Data Sensitif (Privacy Masking)
- Untuk kolom di `siswa_sensitif` (NIK, No. KK, KIP/PKH):
  - Tampilan default: `3201 •••• •••• 0004` di dalam kotak berlatar `#EDF2EF` dengan ikon mata (`Icons.visibility_outlined`).
  - Saat diketuk: Meminta konfirmasi/mencatat ke `audit_log`, mengaktifkan `FLAG_SECURE`, lalu menampilkan angka penuh selama 15 detik sebelum kembali disamarkan otomatis.

### 5.6. Indikator Kelengkapan Form Siswa (Bagian A–G)
- Di atas form Detail Siswa, tampilkan *Horizontal Step Pill* (`A. Diri`, `B. Ortu`, `C. Wali`, `D. Alamat`, `E. Sensitif`, `F. Riwayat`, `G. Berkas`) lengkap dengan titik indikator hijau jika bagian tersebut sudah lengkap, atau titik kuning jika ada perubahan dari Wali Kelas (`diubah_wali_kelas == 1`) yang menunggu tinjauan Admin.

---

## 6. Implementasi Kode `app_theme.dart` (Siap Pakai di Flutter)

Salin konfigurasi berikut ke dalam `app/lib/core/theme/app_theme.dart` agar seluruh komponen Flutter otomatis mengikuti panduan ini:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';

class AppColors {
  // Brand & Harmoni Islami
  static const Color primary = Color(0xFF0F6E56);
  static const Color primaryDark = Color(0xFF085041);
  static const Color primaryContainer = Color(0xFFE1F5EE);
  static const Color onPrimaryContainer = Color(0xFF04342C);

  static const Color secondary = Color(0xFFC68B2C);
  static const Color secondaryContainer = Color(0xFFFDF3DC);
  static const Color onSecondaryContainer = Color(0xFF4A3208);

  // Neutral & Surfaces (Flat Modern)
  static const Color background = Color(0xFFF6F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEDF2EF);
  static const Color outline = Color(0xFFD5E0DA);

  // Typography
  static const Color textPrimary = Color(0xFF16241E);
  static const Color textSecondary = Color(0xFF52665E);
  static const Color textHint = Color(0xFF889992);

  // Semantik (KKM, Absensi, Sinkronisasi)
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0xFFE0F2FE);
}

class AppTheme {
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.outline,
      error: AppColors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'PlusJakartaSans',

      // AppBar Flat & Bersih
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(
          bottom: BorderSide(color: AppColors.outline, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // Card Flat Modern (Zero Shadow + 1px Border)
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
      ),

      // Input Field Bersih & Kontras
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // Tombol Primer Taktil
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(88, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chip Filter & Jenis Nilai
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primaryContainer,
        side: const BorderSide(color: AppColors.outline, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // Divider Tipis
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Helper style untuk angka tabel (Nilai, NIS, NISN, KKM) agar sejajar lurus
  static const TextStyle tabularNumberStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}
```