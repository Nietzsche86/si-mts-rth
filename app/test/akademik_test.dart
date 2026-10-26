import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/repositories/rombel_repository.dart';
import 'package:app/data/repositories/pengampu_repository.dart';
import 'package:app/data/providers/database_providers.dart';
import 'package:app/presentation/screens/akademik/naik_kelas_screen.dart';
import 'package:app/presentation/screens/akademik/cek_pengampu_screen.dart';

void main() {
  late AppDatabase db;
  late OutboxManager outbox;
  late RombelRepository rombelRepo;
  late PengampuRepository pengampuRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxManager(db);
    rombelRepo = RombelRepository(db, outbox);
    pengampuRepo = PengampuRepository(db, outbox);

    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Setup Master Data Awal
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

    await db.into(db.mapel).insert(
          MapelCompanion.insert(
            id: 'mapel-arab',
            kode: 'ARAB',
            nama: 'Bahasa Arab',
            kelompok: 'PAI',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.guru).insert(
          GuruCompanion.insert(
            id: 'guru1',
            namaLengkap: 'Ust. Ahmad Fauzi, S.Pd',
            jk: 'L',
            statusKepegawaianKode: const drift.Value('GTY'),
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.guru).insert(
          GuruCompanion.insert(
            id: 'guru2',
            namaLengkap: 'Ustzh. Siti Fatimah, S.Pd',
            jk: 'P',
            statusKepegawaianKode: const drift.Value('GTY'),
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'r7a',
            tahunAjaranId: 'ta1',
            nama: '7A',
            tingkat: '7',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'r8a',
            tahunAjaranId: 'ta1',
            nama: '8A',
            tingkat: '8',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Setup Siswa & Keanggotaan
    for (int i = 1; i <= 4; i++) {
      await db.into(db.siswa).insert(
            SiswaCompanion.insert(
              id: 's$i',
              nis: '100$i',
              namaLengkap: 'Siswa Uji $i',
              jk: i % 2 == 0 ? 'P' : 'L',
              statusAktif: const drift.Value('aktif'),
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      await db.into(db.keanggotaanRombel).insert(
            KeanggotaanRombelCompanion.insert(
              id: 'k$i',
              siswaId: 's$i',
              rombelId: 'r7a',
              tanggalMasuk: nowStr,
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 4: Operasi Akademik & Repositori Tests', () {
    test('4.2 RombelRepository.naikKelasMassal menutup rombel lama & membuka rombel baru', () async {
      final items = [
        const NaikKelasItemInput(
          siswaId: 's1',
          status: 'naik_kelas',
          rombelTujuanId: 'r8a',
          catatan: 'Naik ke 8A',
        ),
        const NaikKelasItemInput(
          siswaId: 's2',
          status: 'tinggal_kelas',
          rombelTujuanId: 'r7a',
          catatan: 'Tinggal di 7A',
        ),
        const NaikKelasItemInput(
          siswaId: 's3',
          status: 'lulus',
        ),
      ];

      final processed = await rombelRepo.naikKelasMassal(
        rombelAsalId: 'r7a',
        items: items,
        tanggal: '2026-07-10',
        deviceId: 'dev1',
      );

      expect(processed, 3);

      // Verifikasi s1: lama ditutup, baru dibuka di r8a
      final oldK1 = await (db.select(db.keanggotaanRombel)..where((t) => t.id.equals('k1'))).getSingle();
      expect(oldK1.tanggalKeluar, '2026-07-10');
      expect(oldK1.alasanKeluar, 'naik_kelas');

      final newK1 = await (db.select(db.keanggotaanRombel)
            ..where((t) => t.siswaId.equals('s1') & t.rombelId.equals('r8a')))
          .getSingle();
      expect(newK1.sumberKeanggotaanId, 'k1');
      expect(newK1.tanggalMasuk, '2026-07-10');

      // Verifikasi riwayat status siswa tercatat
      final riwayatList = await db.select(db.riwayatStatusSiswa).get();
      expect(riwayatList.length, 3);
      expect(riwayatList.any((r) => r.siswaId == 's1' && r.jenisStatus == 'naik_kelas'), isTrue);
      expect(riwayatList.any((r) => r.siswaId == 's2' && r.jenisStatus == 'tinggal_kelas'), isTrue);
      expect(riwayatList.any((r) => r.siswaId == 's3' && r.jenisStatus == 'lulus'), isTrue);

      // Verifikasi outbox terisi
      final pendingCount = await outbox.getPendingCount();
      expect(pendingCount, greaterThanOrEqualTo(5)); // updates + inserts
    });

    test('4.1 & 4.2 RombelRepository.pergantianTahun menyalin rombel & pengampu', () async {
      final nowEpoch = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);

      // Pasang pengampu di semester lama
      await db.into(db.pengampu).insert(
            PengampuCompanion.insert(
              id: 'p1',
              guruId: 'guru1',
              mapelId: 'mapel-arab',
              rombelId: 'r7a',
              semesterId: 'sem1',
              cakupan: const drift.Value('seluruh'),
              peran: const drift.Value('utama'),
              tanggalMulai: '2026-07-15',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      final res = await rombelRepo.pergantianTahun(
        tahunAjaranLamaId: 'ta1',
        namaTahunBaru: '2027/2028',
        jenisSemesterBaru: 'ganjil',
        tanggalMulai: '2027-07-15',
        tanggalSelesai: '2027-12-20',
        salinRombel: true,
        salinPengampu: true,
        kunciSemesterLama: true,
        deviceId: 'dev1',
      );

      expect(res['rombelCopied'], 2); // r7a & r8a
      expect(res['pengampuCopied'], 1); // p1

      // Verifikasi semester lama terkunci
      final semLama = await (db.select(db.semester)..where((t) => t.id.equals('sem1'))).getSingle();
      expect(semLama.dikunci, 1);

      // Verifikasi tahun baru aktif
      final taBaru = await (db.select(db.tahunAjaran)..where((t) => t.id.equals(res['tahunAjaranId']))).getSingle();
      expect(taBaru.aktif, 1);
      expect(taBaru.nama, '2027/2028');

      // Verifikasi pengampu baru terdaftar pada semester baru
      final newPengampus = await (db.select(db.pengampu)..where((t) => t.semesterId.equals(res['semesterId']))).get();
      expect(newPengampus.length, 1);
      expect(newPengampus.first.guruId, 'guru1');
    });

    test('4.3 PengampuRepository.deteksiAnomaliPengampu mendeteksi 4 anomali PRD F9', () async {
      final nowEpoch = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);

      // Kasus 1: Rombel r7a & r8a belum memiliki pengampu utama untuk mapel-arab
      var anomalies = await pengampuRepo.deteksiAnomaliPengampu(semesterId: 'sem1');
      expect(anomalies.any((a) => a.jenis == JenisAnomaliPengampu.mapelTanpaUtama), isTrue);

      // Pasang pengampu guru nonaktif (Kasus Anomali 4)
      await db.into(db.guru).insert(
            GuruCompanion.insert(
              id: 'guru-nonaktif',
              namaLengkap: 'Guru Pensiun',
              jk: 'L',
              statusKepegawaianKode: const drift.Value('PNS'),
              aktif: const drift.Value(0), // Nonaktif
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      await db.into(db.pengampu).insert(
            PengampuCompanion.insert(
              id: 'p-nonaktif',
              guruId: 'guru-nonaktif',
              mapelId: 'mapel-arab',
              rombelId: 'r8a',
              semesterId: 'sem1',
              cakupan: const drift.Value('seluruh'),
              peran: const drift.Value('utama'),
              tanggalMulai: '2026-07-15',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      anomalies = await pengampuRepo.deteksiAnomaliPengampu(semesterId: 'sem1');
      expect(anomalies.any((a) => a.jenis == JenisAnomaliPengampu.guruNonaktif), isTrue);

      // Kasus Anomali 2 & 3: Mapel cakupan sebagian (kelompok)
      await db.into(db.pengampu).insert(
            PengampuCompanion.insert(
              id: 'p-utama-7a',
              guruId: 'guru1',
              mapelId: 'mapel-arab',
              rombelId: 'r7a',
              semesterId: 'sem1',
              cakupan: const drift.Value('sebagian'),
              peran: const drift.Value('utama'),
              tanggalMulai: '2026-07-15',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      await db.into(db.pengampu).insert(
            PengampuCompanion.insert(
              id: 'p-pendamping-7a',
              guruId: 'guru2',
              mapelId: 'mapel-arab',
              rombelId: 'r7a',
              semesterId: 'sem1',
              cakupan: const drift.Value('sebagian'),
              peran: const drift.Value('pendamping'),
              tanggalMulai: '2026-07-15',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      // Hanya s1 yang dimasukkan ke kelompok p-utama-7a
      await db.into(db.pengampuSiswa).insert(
            PengampuSiswaCompanion.insert(
              id: 'ps1',
              pengampuId: 'p-utama-7a',
              keanggotaanId: 'k1',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      // s2, s3, s4 belum masuk kelompok -> Anomali 2 (Siswa Fallback)
      anomalies = await pengampuRepo.deteksiAnomaliPengampu(semesterId: 'sem1');
      expect(anomalies.any((a) => a.jenis == JenisAnomaliPengampu.siswaFallback), isTrue);

      // Masukkan s1 ke p-pendamping-7a juga -> s1 terdaftar di 2 guru (Anomali 3 Tumpang Tindih)
      await db.into(db.pengampuSiswa).insert(
            PengampuSiswaCompanion.insert(
              id: 'ps1-overlap',
              pengampuId: 'p-pendamping-7a',
              keanggotaanId: 'k1',
              deviceId: 'dev1',
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );

      anomalies = await pengampuRepo.deteksiAnomaliPengampu(semesterId: 'sem1');
      expect(anomalies.any((a) => a.jenis == JenisAnomaliPengampu.siswaTumpangTindih), isTrue);
    });

    test('4.4 PengampuRepository.simpanPembagianKelompok menyimpan pemetaan kelompok atomik', () async {
      await pengampuRepo.simpanPembagianKelompok(
        rombelId: 'r7a',
        mapelId: 'mapel-arab',
        semesterId: 'sem1',
        pengampuToKeanggotaanMap: {
          'p1': ['k1', 'k2'],
          'p2': ['k3', 'k4'],
        },
        deviceId: 'dev1',
      );

      final psRows = await db.select(db.pengampuSiswa).get();
      expect(psRows.length, 4);
      expect(psRows.where((r) => r.pengampuId == 'p1').length, 2);
      expect(psRows.where((r) => r.pengampuId == 'p2').length, 2);
    });
  });

  group('Checkpoint 4: Widget UI Tests', () {
    testWidgets('Layar NaikKelasScreen me-render daftar siswa dan opsi status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            rombelRepoProvider.overrideWithValue(rombelRepo),
            activeSemesterProvider.overrideWith(
              (ref) => const ActiveSemesterInfo(
                semesterId: 'sem1',
                tahunAjaranId: 'ta1',
                tahunAjaranNama: '2026/2027',
                semesterNama: 'Ganjil',
                dikunci: false,
              ),
            ),
          ],
          child: const MaterialApp(home: NaikKelasScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan AppBar dan kontrol utama muncul
      expect(find.text('Naik Kelas Massal & Kelulusan'), findsOneWidget);
      expect(find.text('Semua Naik'), findsOneWidget);
      expect(find.text('Semua Tinggal'), findsOneWidget);
      expect(find.text('Semua Lulus'), findsOneWidget);

      // Memastikan siswa dari database ter-render
      expect(find.text('Siswa Uji 1'), findsOneWidget);
      expect(find.text('Proses Mutasi'), findsOneWidget);
    });

    testWidgets('Layar CekPengampuScreen menampilkan kartu anomali & tab filter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pengampuRepoProvider.overrideWithValue(pengampuRepo),
            activeSemesterProvider.overrideWith(
              (ref) => const ActiveSemesterInfo(
                semesterId: 'sem1',
                tahunAjaranId: 'ta1',
                tahunAjaranNama: '2026/2027',
                semesterNama: 'Ganjil',
                dikunci: false,
              ),
            ),
          ],
          child: const MaterialApp(home: CekPengampuScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cek Pengampu & Deteksi Anomali'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });
}
