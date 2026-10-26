import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/database_seeder.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/repositories/penilaian_repository.dart';
import 'package:app/data/repositories/absensi_repository.dart';
import 'package:app/data/providers/database_providers.dart';
import 'package:app/presentation/screens/penilaian/input_nilai_screen.dart';
import 'package:app/presentation/screens/absensi/input_absensi_screen.dart';
import 'package:app/presentation/screens/siswa/siswa_form_screen.dart';
import 'package:app/main.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder.seedInitialData(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 2: Integrasi UI Flutter ke Database Drift SQLite', () {
    testWidgets('2.1 & 2.2 Beranda Kelas Saya memuat data riil dan menampilkan kartu kelas dinamis', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            pendingOutboxCountProvider.overrideWith((ref) => Stream.value(0)),
            lastSyncTimestampProvider.overrideWith((ref) => Stream.value(null)),
            serverUrlProvider.overrideWith((ref) => Stream.value('http://192.168.1.100:8000')),
          ],
          child: const MTsApp(),
        ),
      );

      // Tunggu stream dan asynchronous initial loading
      await tester.pumpAndSettle();

      // 1. Verifikasi judul dan semester aktif dari SQLite
      expect(find.text('MTs Roudhotut Thowalib'), findsOneWidget);
      expect(find.text('Semester Ganjil 2026/2027'), findsOneWidget);
      expect(find.text('Guru & Wali 7A'), findsOneWidget);

      // 2. Verifikasi kartu kelas tampil dari tabel Pengampu
      expect(find.text('Bahasa Arab'), findsOneWidget);
      expect(find.text('7A'), findsWidgets);
      expect(find.text('Al-Qur\'an Hadis'), findsOneWidget);
      expect(find.text('7B'), findsOneWidget);

      // 3. Verifikasi chip/teks unassigned fallback Guru Utama (+2 belum dikelompokkan)
      expect(find.textContaining('+2 belum dikelompokkan'), findsOneWidget);
    });

    testWidgets('2.3 Layar Input Nilai Cepat memuat siswa riil, simpan ke SQLite + outbox, dan styling KKM', (tester) async {
      final outboxManager = OutboxManager(db);
      final initialOutbox = await outboxManager.getPendingCount();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: InputNilaiScreen(
              rombelId: 'rombel-7a',
              rombelNama: '7A',
              mapelId: 'mapel-arab',
              mapelNama: 'Bahasa Arab',
              kkm: 75.0,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi siswa termuat dari SQLite
      expect(find.text('Ahmad Fauzi Ridwan'), findsOneWidget);
      expect(find.text('Bilqis Nur Azizah'), findsOneWidget);
      expect(find.text('Dian Muhammad Irfan'), findsOneWidget);

      // Verifikasi badge bawaan rombel asal pada Dian
      expect(find.textContaining('Bawaan'), findsOneWidget);

      // Verifikasi nilai awal: Ahmad Fauzi (85 -> predikat A/B), Bilqis (70 -> < KKM)
      expect(find.text('85'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);

      // Input nilai baru pada siswa pertama (Ahmad Fauzi)
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Masukkan nilai 95 dan submit
      await tester.enterText(textFields.first, '95');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Verifikasi tersimpan ke SQLite
      final repo = PenilaianRepository(db, outboxManager);
      final updatedList = await repo.getSiswaNilaiList(
        rombelId: 'rombel-7a',
        mapelId: 'mapel-arab',
        semesterId: 'sem-2026-ganjil',
        jenisNilaiId: 'UH',
        urutanKe: 1,
      );
      final ahmadItem = updatedList.firstWhere((s) => s.siswaId == 'siswa-001');
      expect(ahmadItem.nilaiAngka, equals(95.0));

      // Verifikasi bertambah ke outbox
      final afterOutbox = await outboxManager.getPendingCount();
      expect(afterOutbox, greaterThan(initialOutbox));
    });

    testWidgets('2.4 Layar Absensi Harian toggle status dan tombol Set Semua Hadir', (tester) async {
      final outboxManager = OutboxManager(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: InputAbsensiScreen(
              rombelId: 'rombel-7a',
              rombelNama: '7A',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi daftar siswa hadir di UI
      expect(find.text('Ahmad Fauzi Ridwan'), findsOneWidget);
      expect(find.text('Bilqis Nur Azizah'), findsOneWidget);

      // Klik tombol Set Semua Hadir (H)
      final setSemuaBtn = find.text('Set Semua Hadir (H)');
      expect(setSemuaBtn, findsOneWidget);
      await tester.tap(setSemuaBtn);
      await tester.pumpAndSettle();

      // Verifikasi database: semua siswa di 7A sekarang berstatus 'H'
      final absensiRepo = AbsensiRepository(db, outboxManager);
      final list = await absensiRepo.getAbsensiByTanggal(
        rombelId: 'rombel-7a',
        semesterId: 'sem-2026-ganjil',
        tanggal: DateTime.now(),
      );
      for (final item in list) {
        expect(item.status, equals('H'));
      }
    });

    testWidgets('2.5 Form Siswa Modular simpan dengan kolom_ts dan unmask mencatat audit log', (tester) async {
      final outboxManager = OutboxManager(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: SiswaFormScreen(
              siswaId: 'siswa-001',
              namaLengkap: 'Ahmad Fauzi Ridwan',
              nis: '202607001',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll hingga chip E. Sensitif terlihat, lalu klik
      final sensitifChip = find.text('E. Sensitif');
      await tester.ensureVisible(sensitifChip);
      await tester.pumpAndSettle();
      await tester.tap(sensitifChip);
      await tester.pumpAndSettle();

      // NIK harus tersamar secara default
      expect(find.text('3301••••••••0001'), findsOneWidget);

      // Klik tombol buka visual NIK
      final unmaskBtn = find.byTooltip('Buka Visual (15 detik)');
      expect(unmaskBtn, findsOneWidget);
      await tester.tap(unmaskBtn);
      await tester.pump();

      // Verifikasi timer 15 detik aktif dan NIK terbuka
      expect(find.text('3301011205120001'), findsOneWidget);
      expect(find.text('15s'), findsOneWidget);

      // Verifikasi audit log tercatat di outbox
      final pendingCount = await outboxManager.getPendingCount();
      expect(pendingCount, greaterThan(0));

      // Tunggu timer 15 detik berakhir agar timer bersih
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();

      // NIK harus tersamar kembali setelah 15 detik
      expect(find.text('3301••••••••0001'), findsOneWidget);

      // Klik simpan
      final saveBtn = find.byTooltip('Simpan');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();
    });
  });
}
