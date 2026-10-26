import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:app/core/utils/berkas_util.dart';
import 'package:app/core/utils/emis_csv_helper.dart';
import 'package:app/data/db/app_database.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/repositories/berkas_repository.dart';
import 'package:app/data/repositories/emis_repository.dart';
import 'package:app/data/repositories/rombel_repository.dart';
import 'package:app/data/providers/database_providers.dart';
import 'package:app/presentation/screens/berkas/sandboxed_viewer_screen.dart';
import 'package:app/presentation/screens/berkas/berkas_siswa_screen.dart';
import 'package:app/presentation/screens/emis/emis_screen.dart';
import 'package:app/presentation/screens/backup/backup_screen.dart';

void main() {
  late AppDatabase db;
  late OutboxManager outbox;
  late BerkasRepository berkasRepo;
  late EmisRepository emisRepo;
  late RombelRepository rombelRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxManager(db);
    berkasRepo = BerkasRepository(db: db, outbox: outbox);
    emisRepo = EmisRepository(db: db, outbox: outbox);
    rombelRepo = RombelRepository(db, outbox);

    final now = DateTime.now();
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Setup master data Rombel 7A
    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'rombel-7a',
            tahunAjaranId: 'ta1',
            nama: '7A',
            tingkat: '7',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
            deviceId: 'test-device',
          ),
        );

    // Setup 1 siswa awal di 7A
    await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: 'siswa-001',
            nis: '1001',
            nisn: const drift.Value('0011223344'),
            namaLengkap: 'Ahmad Fauzi',
            jk: 'L',
            statusAktif: const drift.Value('aktif'),
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
            deviceId: 'test-device',
          ),
        );

    await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'kr-001',
            siswaId: 'siswa-001',
            rombelId: 'rombel-7a',
            tanggalMasuk: '2026-07-15',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
            deviceId: 'test-device',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 6.1: Utilitas Berkas & Validasi Magic Bytes Tests', () {
    test('detectMimeType mendeteksi JPG, PNG, dan PDF berdasarkan magic bytes asli', () {
      final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);
      final fakeBytes = Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello"

      expect(BerkasUtil.detectMimeType(jpegBytes), equals(BerkasMimeType.jpeg));
      expect(BerkasUtil.detectMimeType(pngBytes), equals(BerkasMimeType.png));
      expect(BerkasUtil.detectMimeType(pdfBytes), equals(BerkasMimeType.pdf));
      expect(BerkasUtil.detectMimeType(fakeBytes), equals(BerkasMimeType.unknown));
    });

    test('validateBerkas memvalidasi ukuran, hash SHA-256, dan menolak ekstensi palsu', () {
      final validJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02]);
      final resValid = BerkasUtil.validateBerkas(validJpeg, 'foto.jpg');
      expect(resValid.isValid, isTrue);
      expect(resValid.mimeType, equals(BerkasMimeType.jpeg));
      expect(resValid.sha256Checksum.length, equals(64));

      // Berkas kosong
      final resEmpty = BerkasUtil.validateBerkas(Uint8List(0), 'kosong.jpg');
      expect(resEmpty.isValid, isFalse);
      expect(resEmpty.errorMessage, contains('kosong'));

      // Berkas bukan gambar/pdf
      final resFake = BerkasUtil.validateBerkas(Uint8List.fromList([1, 2, 3, 4]), 'fake.jpg');
      expect(resFake.isValid, isFalse);
      expect(resFake.errorMessage, contains('Format berkas tidak valid'));
    });
  });

  group('Checkpoint 6.2: Utilitas Offline EMIS CSV Helper Tests', () {
    test('generateTemplateCsv menghasilkan 16 header EMIS standar dan baris contoh', () {
      final template = EmisCsvHelper.generateTemplateCsv();
      expect(template, contains('NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK'));
      expect(template, contains('Ahmad Fauzi'));
      expect(template, contains('3301011205120001'));
    });

    test('parseCsvString dan escapeCsvCell mematuhi standar RFC-4180', () {
      final escaped = EmisCsvHelper.escapeCsvCell('Semarang, Jawa Tengah');
      expect(escaped, equals('"Semarang, Jawa Tengah"'));

      const csv = 'Nama,Kota\n"Fauzi, Ahmad","Semarang"\n"Siti ""Aminah""",Kudus';
      final parsed = EmisCsvHelper.parseCsvString(csv);
      expect(parsed.length, equals(3));
      expect(parsed[1][0], equals('Fauzi, Ahmad'));
      expect(parsed[2][0], equals('Siti "Aminah"'));
    });

    test('validateAndPreviewCsv memvalidasi kelengkapan data siswa dan deteksi duplikat', () {
      const csvData = '''
NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK,TEMPAT LAHIR,TANGGAL LAHIR (YYYY-MM-DD),NAMA IBU,NAMA AYAH,ALAMAT JALAN,DESA/KELURAHAN,KECAMATAN,KABUPATEN/KOTA,PROVINSI
1,330101,330102,1001,001122,Siswa Duplikat DB,L,Kudus,2012-05-12,Ibu,Ayah,Jalan,Desa,Kec,Kab,Prov
2,330103,330104,1002,001123,Siswa Valid Baru,P,Kudus,2012-08-17,Ibu,Ayah,Jalan,Desa,Kec,Kab,Prov
3,330105,330106,,001124,Siswa Tanpa NIS,L,Kudus,2012-08-17,Ibu,Ayah,Jalan,Desa,Kec,Kab,Prov
''';

      final preview = EmisCsvHelper.validateAndPreviewCsv(
        csvData,
        existingNisSet: {'1001'}, // 1001 sudah ada di database
      );

      expect(preview.totalRows, equals(3));
      expect(preview.validCount, equals(1)); // Hanya baris 2 yang valid
      expect(preview.errorCount, equals(2));

      // Baris 1: Duplikat NIS
      expect(preview.rows[0].isValid, isFalse);
      expect(preview.rows[0].errors.first, contains("sudah terdaftar di database"));

      // Baris 2: Valid
      expect(preview.rows[1].isValid, isTrue);
      expect(preview.rows[1].namaLengkap, equals('Siswa Valid Baru'));

      // Baris 3: NIS kosong
      expect(preview.rows[2].isValid, isFalse);
      expect(preview.rows[2].errors.first, contains("NIS wajib diisi"));
    });
  });

  group('Checkpoint 6.1: BerkasRepository Drift SQLite & Outbox Tests', () {
    test('simpanBerkasSiswa menyimpan metadata, antrean upload, dan mendaftar ke outbox', () async {
      final validJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(100, 70)]);

      final berkas = await berkasRepo.simpanBerkasSiswa(
        siswaId: 'siswa-001',
        jenisBerkasKode: 'KK',
        namaTampil: 'KK_Ahmad.jpg',
        bytes: validJpeg,
        diunggahOlehUserId: 'user-001',
      );

      expect(berkas.id, isNotEmpty);
      expect(berkas.statusUnggah, equals('PENDING'));
      expect(berkas.mimeType, equals('image/jpeg'));

      // Verifikasi di database Drift
      final list = await berkasRepo.getBerkasForSiswa('siswa-001');
      expect(list.length, equals(1));
      expect(list.first.namaTampil, equals('KK_Ahmad.jpg'));

      // Verifikasi di tabel berkas_antrean
      final antrean = await berkasRepo.getAntreanBerkas();
      expect(antrean.length, equals(1));
      expect(antrean.first.arah, equals('UPLOAD'));
      expect(antrean.first.status, equals('PENDING'));

      // Verifikasi di outbox
      final outboxItems = await db.select(db.outbox).get();
      final berkasOutbox = outboxItems.where((o) => o.tabel == 'siswa_berkas').firstOrNull;
      expect(berkasOutbox, isNotNull);
      expect(berkasOutbox!.operasi, equals('UPSERT'));
    });

    test('hapusBerkasSiswa melakukan soft-delete dan mendaftarkan DELETE ke outbox', () async {
      final validPdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, ...List.filled(100, 80)]);
      final berkas = await berkasRepo.simpanBerkasSiswa(
        siswaId: 'siswa-001',
        jenisBerkasKode: 'IJAZAH',
        namaTampil: 'Ijazah_Ahmad.pdf',
        bytes: validPdf,
      );

      await berkasRepo.hapusBerkasSiswa(berkas.id);

      final list = await berkasRepo.getBerkasForSiswa('siswa-001');
      expect(list, isEmpty); // Tersembunyi karena deleted = 1

      final outboxItems = await db.select(db.outbox).get();
      final deleteOutbox = outboxItems.where((o) => o.tabel == 'siswa_berkas' && o.operasi == 'DELETE').firstOrNull;
      expect(deleteOutbox, isNotNull);
    });

    test('logBukaBerkas mencatat audit log pembukaan dokumen ke outbox (PRD F5)', () async {
      await berkasRepo.logBukaBerkas(
        berkasId: 'berkas-xyz',
        namaBerkas: 'Akta_Ahmad.pdf',
        userId: 'guru-dahlan',
      );

      final outboxItems = await db.select(db.outbox).get();
      final auditItem = outboxItems.where((o) => o.tabel == 'audit_log').firstOrNull;
      expect(auditItem, isNotNull);
      expect(auditItem!.payloadJson, contains('BUKA_BERKAS'));
    });
  });

  group('Checkpoint 6.2: EmisRepository Offline Import & Export Tests', () {
    test('exportRombelToCsv mengekspor data siswa aktif rombel dengan penyamaran sensitif', () async {
      final csv = await emisRepo.exportRombelToCsv('rombel-7a', maskSensitif: true);
      expect(csv, contains('NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK'));
      expect(csv, contains('Ahmad Fauzi'));
      expect(csv, contains('1001'));
    });

    test('commitImportOffline menyimpan siswa baru ke Drift SQLite dan outbox secara atomik', () async {
      final previewResult = EmisCsvHelper.validateAndPreviewCsv('''
NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK,TEMPAT LAHIR,TANGGAL LAHIR (YYYY-MM-DD),NAMA IBU,NAMA AYAH,ALAMAT JALAN,DESA/KELURAHAN,KECAMATAN,KABUPATEN/KOTA,PROVINSI
1,33010122,33010133,1002,008899,Siti Zulaikha,P,Semarang,2012-04-10,Fatimah,Mansur,Jl. Melati No. 2,Kauman,Kota,Semarang,Jawa Tengah
''');

      final res = await emisRepo.commitImportOffline(
        validRows: previewResult.rows,
        rombelId: 'rombel-7a',
        tanggalMasuk: '2026-07-15',
      );

      expect(res.success, isTrue);
      expect(res.importedCount, equals(1));

      // Verifikasi siswa tersimpan di SQLite lokal
      final siswaBaru = await (db.select(db.siswa)..where((s) => s.nis.equals('1002'))).getSingleOrNull();
      expect(siswaBaru, isNotNull);
      expect(siswaBaru!.namaLengkap, equals('Siti Zulaikha'));

      // Verifikasi keanggotaan rombel dibuat
      final keanggotaan = await (db.select(db.keanggotaanRombel)..where((k) => k.siswaId.equals(siswaBaru.id))).getSingleOrNull();
      expect(keanggotaan, isNotNull);
      expect(keanggotaan!.rombelId, equals('rombel-7a'));

      // Verifikasi outbox terisi
      final outboxItems = await db.select(db.outbox).get();
      expect(outboxItems.any((o) => o.tabel == 'siswa' && o.barisId == siswaBaru.id), isTrue);
      expect(outboxItems.any((o) => o.tabel == 'keanggotaan_rombel' && o.barisId == keanggotaan.id), isTrue);
    });
  });

  group('Checkpoint 6: UI Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          outboxManagerProvider.overrideWithValue(outbox),
          berkasRepoProvider.overrideWithValue(berkasRepo),
          emisRepoProvider.overrideWithValue(emisRepo),
          rombelRepoProvider.overrideWithValue(rombelRepo),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('Layar SandboxedViewerScreen me-render banner FLAG_SECURE dan info dokumen', (tester) async {
      final nowBig = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);
      final dummyBerkas = SiswaBerkasData(
        id: 'b-001',
        siswaId: 'siswa-001',
        jenisBerkasKode: 'KK',
        namaTampil: 'Kartu_Keluarga_Ahmad.jpg',
        mimeType: 'image/jpeg',
        ukuranByte: 102400,
        sha256Plain: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        statusUnggah: 'SELESAI',
        createdAt: nowBig,
        updatedAt: nowBig,
        deleted: 0,
        deviceId: 'dev1',
      );

      await tester.pumpWidget(
        buildTestApp(
          SandboxedViewerScreen(
            berkas: dummyBerkas,
            namaSiswa: 'Ahmad Fauzi',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kartu_Keluarga_Ahmad.jpg'), findsWidgets);
      expect(find.text('FLAG_SECURE Aktif • Tangkapan layar dinonaktifkan'), findsOneWidget);
      expect(find.text('TERLINDUNGI'), findsOneWidget);
      expect(find.textContaining('100.0 KB'), findsOneWidget);
    });

    testWidgets('Layar BerkasSiswaScreen me-render daftar berkas dan tombol unggah', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const BerkasSiswaScreen(
            siswaId: 'siswa-001',
            namaSiswa: 'Ahmad Fauzi',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Berkas Siswa: Ahmad Fauzi'), findsOneWidget);
      expect(find.text('Tambah Berkas'), findsOneWidget);
      expect(find.text('Belum ada berkas terunggah'), findsOneWidget);

      // Ketuk tombol tambah berkas
      await tester.tap(find.text('Tambah Berkas'));
      await tester.pumpAndSettle();

      expect(find.text('Unggah Berkas Sandboxed'), findsOneWidget);
      expect(find.text('Simpan & Enkripsi'), findsOneWidget);
    });

    testWidgets('Layar EmisScreen me-render tab Ekspor dan Impor EMIS', (tester) async {
      await tester.pumpWidget(buildTestApp(const EmisScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ekspor & Impor EMIS Kemenag'), findsOneWidget);
      expect(find.text('Ekspor EMIS'), findsOneWidget);
      expect(find.text('Impor EMIS Offline'), findsOneWidget);
      expect(find.text('Konfigurasi Ekspor Rombel'), findsOneWidget);
      expect(find.text('Pratinjau Data CSV EMIS'), findsOneWidget);

      // Pindah ke tab Impor EMIS
      await tester.tap(find.text('Impor EMIS Offline'));
      await tester.pumpAndSettle();

      expect(find.text('Impor Data Siswa EMIS'), findsOneWidget);
      expect(find.text('Muat Contoh'), findsOneWidget);
      expect(find.text('Validasi & Pratinjau Baris'), findsOneWidget);
    });

    testWidgets('Layar BackupScreen me-render card buat cadangan dan verifikasi integritas', (tester) async {
      await tester.pumpWidget(buildTestApp(const BackupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Cadangan & Pemulihan (AES-256)'), findsOneWidget);
      expect(find.text('Pengingat Cadangan Berkala'), findsOneWidget);
      expect(find.text('Buat Cadangan Terenkripsi'), findsOneWidget);
      expect(find.text('Verifikasi & Pemulihan (Restore)'), findsOneWidget);
      expect(find.text('Buat & Unduh Cadangan (.bak)'), findsOneWidget);
    });
  });
}
