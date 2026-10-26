import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/repositories/penilaian_repository.dart';
import 'package:app/data/repositories/absensi_repository.dart';
import 'package:app/domain/kalkulator_k13.dart';
import 'package:app/data/providers/database_providers.dart';
import 'package:app/presentation/screens/penilaian/rekap_nilai_screen.dart';
import 'package:app/presentation/screens/penilaian/kelengkapan_pengampu_screen.dart';
import 'package:app/presentation/screens/dashboard/kepala_dashboard_screen.dart';
import 'package:app/presentation/screens/absensi/rekap_absensi_screen.dart';

void main() {
  late AppDatabase db;
  late OutboxManager outbox;
  late PenilaianRepository penilaianRepo;
  late AbsensiRepository absensiRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxManager(db);
    penilaianRepo = PenilaianRepository(db, outbox);
    absensiRepo = AbsensiRepository(db, outbox);

    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Setup Master Data
    await db.into(db.madrasah).insert(
          MadrasahCompanion.insert(
            id: 'm1',
            nama: 'MTs Roudhotut Thowalib',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.tahunAjaran).insert(
          TahunAjaranCompanion.insert(
            id: 'ta1',
            nama: '2026/2027',
            tanggalMulai: nowStr,
            tanggalSelesai: '2027-06-30',
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.semester).insert(
          SemesterCompanion.insert(
            id: 'sem1',
            tahunAjaranId: 'ta1',
            jenis: 'ganjil',
            tanggalMulai: nowStr,
            tanggalSelesai: '2026-12-31',
            dikunci: const drift.Value(0),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Mapel
    await db.into(db.mapel).insert(
          MapelCompanion.insert(
            id: 'mapel-arab',
            kode: 'ARB',
            nama: 'Bahasa Arab',
            kelompok: 'A',
            urutan: const drift.Value(1),
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.mapel).insert(
          MapelCompanion.insert(
            id: 'mapel-fikih',
            kode: 'FIK',
            nama: 'Fikih',
            kelompok: 'A',
            urutan: const drift.Value(2),
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Jenis Nilai K13
    await db.into(db.jenisNilai).insert(
          JenisNilaiCompanion.insert(
            id: 'UH',
            kode: 'UH',
            nama: 'Ulangan Harian',
            kategori: 'pengetahuan',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.jenisNilai).insert(
          JenisNilaiCompanion.insert(
            id: 'TGS',
            kode: 'TGS',
            nama: 'Tugas',
            kategori: 'pengetahuan',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.jenisNilai).insert(
          JenisNilaiCompanion.insert(
            id: 'PRY',
            kode: 'PRY',
            nama: 'Proyek',
            kategori: 'keterampilan',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // KKM Global 75.0
    await db.into(db.pengaturanKkm).insert(
          PengaturanKkmCompanion.insert(
            id: 'kkm1',
            semesterId: 'sem1',
            kkm: const drift.Value(75.0),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Rombel 7A & 8A
    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'rombel-7a',
            nama: '7A',
            tingkat: '7',
            tahunAjaranId: 'ta1',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'rombel-8a',
            nama: '8A',
            tingkat: '8',
            tahunAjaranId: 'ta1',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Guru
    await db.into(db.guru).insert(
          GuruCompanion.insert(
            id: 'guru-1',
            namaLengkap: 'Drs. H. Ahmad Dahlan',
            jk: 'L',
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Pengampu
    await db.into(db.pengampu).insert(
          PengampuCompanion.insert(
            id: 'p-arab-7a',
            guruId: 'guru-1',
            mapelId: 'mapel-arab',
            rombelId: 'rombel-7a',
            semesterId: 'sem1',
            cakupan: const drift.Value('seluruh'),
            peran: const drift.Value('utama'),
            tanggalMulai: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Siswa di 7A
    await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: 's1',
            nis: '2026001',
            namaLengkap: 'Ahmad Zaki',
            jk: 'L',
            statusAktif: const drift.Value('aktif'),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: 's2',
            nis: '2026002',
            namaLengkap: 'Budi Santoso',
            jk: 'L',
            statusAktif: const drift.Value('aktif'),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k1',
            siswaId: 's1',
            rombelId: 'rombel-7a',
            tanggalMasuk: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k2',
            siswaId: 's2',
            rombelId: 'rombel-7a',
            tanggalMasuk: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 5.1: Domain Kalkulator K13 & Ranking Tests', () {
    test('KalkulatorK13.hitungK13Lengkap menghitung KD3, KD4, dan predikat akurat', () {
      final rataPerJenis = {
        'UH': 85.0,
        'TGS': 90.0,
        'PRY': 80.0,
      };
      final bobotPerJenis = {
        'UH': 2.0,
        'TGS': 1.0,
        'PRY': 1.0,
      };
      final kategoriPerJenis = {
        'UH': 'pengetahuan',
        'TGS': 'pengetahuan',
        'PRY': 'keterampilan',
      };

      final hasil = KalkulatorK13.hitungK13Lengkap(
        rataRataPerJenis: rataPerJenis,
        bobotPerJenis: bobotPerJenis,
        kategoriPerJenis: kategoriPerJenis,
        kkm: 75.0,
      );

      // KD3: ((85*2) + (90*1)) / 3 = 260 / 3 = 86.67
      expect(hasil.rataRataPengetahuan, equals(86.67));
      // KD4: 80.0
      expect(hasil.rataRataKeterampilan, equals(80.0));
      // Nilai Akhir: (86.67 + 80.0) / 2 = 83.335 -> 83.34
      expect(hasil.nilaiAkhir, equals(83.34));
      expect(hasil.tuntas, isTrue);
      // KKM 75 -> interval = 8.33; Batas B = 83.33; Batas A = 91.66 -> Predikat B
      expect(hasil.predikat, equals('B'));
    });

    test('KalkulatorK13.hitungRanking menentukan ranking berurutan turun secara benar', () {
      final nilaiMap = {
        's1': 88.5,
        's2': 92.0,
        's3': 75.0,
        's4': 88.5,
      };

      final ranking = KalkulatorK13.hitungRanking(nilaiMap);

      expect(ranking['s2'], equals(1)); // 92.0
      expect(ranking['s1'], equals(2)); // 88.5 (tie)
      expect(ranking['s4'], equals(2)); // 88.5 (tie)
      expect(ranking['s3'], equals(4)); // 75.0
    });
  });

  group('Checkpoint 5.1 & 5.2: PenilaianRepository Rekap & Progres Tests', () {
    test('PenilaianRepository.getRekapNilaiRombel menghitung rekap rombel dan ranking', () async {
      // Input nilai Ahmad Zaki (s1 -> k1)
      await penilaianRepo.simpanNilai(
        keanggotaanId: 'k1',
        mapelId: 'mapel-arab',
        semesterId: 'sem1',
        jenisNilaiId: 'UH',
        urutanKe: 1,
        nilaiAngka: 90.0,
        guruId: 'guru-1',
        deviceId: 'dev1',
      );

      // Input nilai Budi Santoso (s2 -> k2)
      await penilaianRepo.simpanNilai(
        keanggotaanId: 'k2',
        mapelId: 'mapel-arab',
        semesterId: 'sem1',
        jenisNilaiId: 'UH',
        urutanKe: 1,
        nilaiAngka: 70.0, // Di bawah KKM
        guruId: 'guru-1',
        deviceId: 'dev1',
      );

      final rekap = await penilaianRepo.getRekapNilaiRombel(
        rombelId: 'rombel-7a',
        semesterId: 'sem1',
      );

      expect(rekap.rombelNama, equals('7A'));
      expect(rekap.siswaItems.length, equals(2));

      // Ahmad Zaki ranking 1, Budi Santoso ranking 2
      final rank1 = rekap.siswaItems[0];
      final rank2 = rekap.siswaItems[1];

      expect(rank1.namaLengkap, equals('Ahmad Zaki'));
      expect(rank1.ranking, equals(1));
      expect(rank1.rataRataAkhir, equals(90.0));
      expect(rank1.tuntasSemua, isTrue);

      expect(rank2.namaLengkap, equals('Budi Santoso'));
      expect(rank2.ranking, equals(2));
      expect(rank2.rataRataAkhir, equals(70.0));
      expect(rank2.tuntasSemua, isFalse);
      expect(rank2.jumlahMapelRemedial, equals(1));

      // Statistik Rombel
      expect(rekap.rataRataRombel, equals(80.0));
      expect(rekap.nilaiTertinggi, equals(90.0));
      expect(rekap.nilaiTerendah, equals(70.0));
      expect(rekap.persentaseKetuntasan, equals(50.0)); // 1 dari 2 tuntas
    });

    test('PenilaianRepository.getProgresKelengkapanPengampu menghitung persentase entri nilai', () async {
      // k1 sudah dinilai di tes sebelumnya, beri nilai ke k1
      await penilaianRepo.simpanNilai(
        keanggotaanId: 'k1',
        mapelId: 'mapel-arab',
        semesterId: 'sem1',
        jenisNilaiId: 'UH',
        urutanKe: 1,
        nilaiAngka: 85.0,
        guruId: 'guru-1',
        deviceId: 'dev1',
      );

      final progresList = await penilaianRepo.getProgresKelengkapanPengampu(
        semesterId: 'sem1',
        rombelId: 'rombel-7a',
      );

      expect(progresList.length, equals(1));
      final p = progresList.first;
      expect(p.guruNama, equals('Drs. H. Ahmad Dahlan'));
      expect(p.mapelNama, equals('Bahasa Arab'));
      expect(p.totalSiswaTarget, equals(2));
      expect(p.jumlahSiswaTernilai, equals(1));
      expect(p.persentaseKelengkapan, equals(50.0));
      expect(p.statusKelengkapan, equals('Sedang Berjalan'));
      expect(p.rincianJenisNilai['UH'], equals(1));
    });

    test('PenilaianRepository.getRingkasanKetuntasanPerMapel agregat ketuntasan untuk dashboard', () async {
      await penilaianRepo.simpanNilai(
        keanggotaanId: 'k1',
        mapelId: 'mapel-arab',
        semesterId: 'sem1',
        jenisNilaiId: 'UH',
        urutanKe: 1,
        nilaiAngka: 85.0,
        guruId: 'guru-1',
        deviceId: 'dev1',
      );

      final summary = await penilaianRepo.getRingkasanKetuntasanPerMapel(
        semesterId: 'sem1',
      );

      expect(summary.isNotEmpty, isTrue);
      final arab = summary.firstWhere((m) => m.mapelId == 'mapel-arab');
      expect(arab.kkm, equals(75.0));
      expect(arab.totalSiswa, equals(1));
      expect(arab.jumlahTuntas, equals(1));
      expect(arab.persentaseKetuntasan, equals(100.0));
    });
  });

  group('Checkpoint 5.3: AbsensiRepository Rekap Periodik & Statistik Tests', () {
    test('AbsensiRepository.getRekapAbsensiPeriodik menghitung total H, S, I, A dan deteksi perhatian', () async {
      final now = DateTime.now();

      // Siswa 1 (k1): 2 Hadir, 1 Sakit
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k1',
        semesterId: 'sem1',
        tanggal: now,
        status: 'H',
        userId: 'dev1',
        deviceId: 'dev1',
      );
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k1',
        semesterId: 'sem1',
        tanggal: now.subtract(const Duration(days: 1)),
        status: 'H',
        userId: 'dev1',
        deviceId: 'dev1',
      );
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k1',
        semesterId: 'sem1',
        tanggal: now.subtract(const Duration(days: 2)),
        status: 'S',
        userId: 'dev1',
        deviceId: 'dev1',
      );

      // Siswa 2 (k2): 3 Alpa (harus trigger perluPerhatian = true)
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k2',
        semesterId: 'sem1',
        tanggal: now,
        status: 'A',
        userId: 'dev1',
        deviceId: 'dev1',
      );
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k2',
        semesterId: 'sem1',
        tanggal: now.subtract(const Duration(days: 1)),
        status: 'A',
        userId: 'dev1',
        deviceId: 'dev1',
      );
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k2',
        semesterId: 'sem1',
        tanggal: now.subtract(const Duration(days: 2)),
        status: 'A',
        userId: 'dev1',
        deviceId: 'dev1',
      );

      final rekap = await absensiRepo.getRekapAbsensiPeriodik(
        rombelId: 'rombel-7a',
        semesterId: 'sem1',
      );

      expect(rekap.rombelNama, equals('7A'));
      expect(rekap.totalHadir, equals(2));
      expect(rekap.totalSakit, equals(1));
      expect(rekap.totalAlpa, equals(3));
      // Total pertemuan: 6; Hadir: 2 -> persentase: 33.3%
      expect(rekap.persentaseKehadiranRombel, equals(33.3));

      final itemK1 = rekap.siswaItems.firstWhere((s) => s.keanggotaanId == 'k1');
      expect(itemK1.hadir, equals(2));
      expect(itemK1.sakit, equals(1));
      expect(itemK1.alpa, equals(0));
      expect(itemK1.perluPerhatian, isFalse);

      final itemK2 = rekap.siswaItems.firstWhere((s) => s.keanggotaanId == 'k2');
      expect(itemK2.alpa, equals(3));
      expect(itemK2.perluPerhatian, isTrue); // Flag alpa >= 3 aktif
    });

    test('AbsensiRepository.getStatistikKehadiranMadrasah menghitung agregat tingkat dan rombel', () async {
      final now = DateTime.now();
      await absensiRepo.setStatusAbsensi(
        keanggotaanId: 'k1',
        semesterId: 'sem1',
        tanggal: now,
        status: 'H',
        userId: 'dev1',
        deviceId: 'dev1',
      );

      final stat = await absensiRepo.getStatistikKehadiranMadrasah(semesterId: 'sem1');

      expect(stat.totalHadir, equals(1));
      expect(stat.persentaseKehadiranTotal, equals(100.0));
      expect(stat.perTingkat.containsKey('7'), isTrue);
      expect(stat.perRombel.any((r) => r.rombelNama == '7A'), isTrue);
    });
  });

  group('Checkpoint 5: UI Widget Tests', () {
    testWidgets('Layar RekapNilaiScreen me-render filter dan statistik rombel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeSemesterProvider.overrideWith((ref) => const ActiveSemesterInfo(
                  semesterId: 'sem1',
                  tahunAjaranId: 'ta1',
                  semesterNama: 'Ganjil',
                  tahunAjaranNama: '2026/2027',
                )),
          ],
          child: const MaterialApp(
            home: RekapNilaiScreen(initialRombelId: 'rombel-7a'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rekap Nilai & Ranking K13'), findsOneWidget);
      expect(find.text('Peringkat & Nilai Akhir'), findsOneWidget);
      expect(find.text('Matriks K13 Lengkap'), findsOneWidget);
    });

    testWidgets('Layar KepalaDashboardScreen me-render header dan metrik eksekutif', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeSemesterProvider.overrideWith((ref) => const ActiveSemesterInfo(
                  semesterId: 'sem1',
                  tahunAjaranId: 'ta1',
                  semesterNama: 'Ganjil',
                  tahunAjaranNama: '2026/2027',
                )),
          ],
          child: const MaterialApp(
            home: KepalaDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dashboard Kepala Madrasah'), findsOneWidget);
      expect(find.text('MTs Roudhotut Thowalib'), findsOneWidget);
      expect(find.text('Statistik Kehadiran Siswa'), findsOneWidget);
      expect(find.text('Ketuntasan KKM'), findsOneWidget);
    });

    testWidgets('Layar RekapAbsensiScreen me-render filter periode dan kolom absensi', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeSemesterProvider.overrideWith((ref) => const ActiveSemesterInfo(
                  semesterId: 'sem1',
                  tahunAjaranId: 'ta1',
                  semesterNama: 'Ganjil',
                  tahunAjaranNama: '2026/2027',
                )),
          ],
          child: const MaterialApp(
            home: RekapAbsensiScreen(initialRombelId: 'rombel-7a'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rekap Absensi Siswa'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('1 Semester'), findsOneWidget);
    });

    testWidgets('Layar KelengkapanPengampuScreen me-render ringkasan status pengampu', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeSemesterProvider.overrideWith((ref) => const ActiveSemesterInfo(
                  semesterId: 'sem1',
                  tahunAjaranId: 'ta1',
                  semesterNama: 'Ganjil',
                  tahunAjaranNama: '2026/2027',
                )),
          ],
          child: const MaterialApp(
            home: KelengkapanPengampuScreen(initialRombelId: 'rombel-7a'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Progres Kelengkapan Nilai Pengampu'), findsOneWidget);
      expect(find.text('Lengkap'), findsOneWidget);
      expect(find.text('Sedang Berjalan'), findsOneWidget);
      expect(find.text('Belum Mengisi'), findsWidgets);
    });
  });
}
