import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:app/data/db/app_database.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/sync/local_gc.dart';

void main() {
  late AppDatabase db;
  late OutboxManager outboxManager;
  late LocalGarbageCollector localGc;

  setUp(() {
    // Gunakan in-memory database untuk pengujian unit
    db = AppDatabase(NativeDatabase.memory());
    outboxManager = OutboxManager(db);
    localGc = LocalGarbageCollector(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift SQLite & Partial Unique Indexes Tests', () {
    test('Partial unique index idx_keanggotaan_terbuka_unik', () async {
      const siswaId = 'siswa-001';
      const rombel1 = 'rombel-7a';
      const rombel2 = 'rombel-7b';

      // 1. Keanggotaan terbuka pertama
      await db.into(db.keanggotaanRombel).insert(
        KeanggotaanRombelCompanion.insert(
          id: 'k-1',
          siswaId: siswaId,
          rombelId: rombel1,
          tanggalMasuk: '2026-07-15',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test-device',
        ),
      );

      // 2. Keanggotaan terbuka kedua untuk siswa yang sama -> WAJIB GAGAL UNIQUE CONSTRAINT
      expect(
        () async => await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k-2',
            siswaId: siswaId,
            rombelId: rombel2,
            tanggalMasuk: '2026-08-01',
            createdAt: BigInt.from(2000),
            updatedAt: BigInt.from(2000),
            deviceId: 'test-device',
          ),
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );

      // 3. Tutup keanggotaan pertama (pindah rombel), lalu tambah yang baru -> SUKSES
      await (db.update(db.keanggotaanRombel)..where((tbl) => tbl.id.equals('k-1'))).write(
        const KeanggotaanRombelCompanion(
          tanggalKeluar: drift.Value('2026-07-31'),
          alasanKeluar: drift.Value('pindah_rombel'),
        ),
      );

      await db.into(db.keanggotaanRombel).insert(
        KeanggotaanRombelCompanion.insert(
          id: 'k-3',
          siswaId: siswaId,
          rombelId: rombel2,
          tanggalMasuk: '2026-08-01',
          sumberKeanggotaanId: const drift.Value('k-1'),
          createdAt: BigInt.from(3000),
          updatedAt: BigInt.from(3000),
          deviceId: 'test-device',
        ),
      );

      final openRows = await (db.select(db.keanggotaanRombel)
            ..where((tbl) => tbl.siswaId.equals(siswaId) & tbl.tanggalKeluar.isNull()))
          .get();
      expect(openRows.length, 1);
      expect(openRows.first.id, 'k-3');
    });

    test('Outbox Manager enqueue and count', () async {
      expect(await outboxManager.getPendingCount(), 0);

      await outboxManager.enqueueUpsert(
        table: 'nilai',
        barisId: 'nilai-123',
        payload: {'nilai': 85.0, 'urutan_ke': 1},
      );

      expect(await outboxManager.getPendingCount(), 1);

      await outboxManager.removeOutboxItem(1);
      expect(await outboxManager.getPendingCount(), 0);
    });

    test('Local Garbage Collection menghapus data di luar active_scope dan melindungi outbox', () async {
      // Siswa 1 (diizinkan)
      await db.into(db.siswa).insert(
        SiswaCompanion.insert(
          id: 's-1',
          nis: '202601',
          namaLengkap: 'Siswa Satu',
          jk: 'L',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );
      await db.into(db.keanggotaanRombel).insert(
        KeanggotaanRombelCompanion.insert(
          id: 'k-1',
          siswaId: 's-1',
          rombelId: 'rombel-7a',
          tanggalMasuk: '2026-07-15',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );

      // Siswa 2 (dicabut hak aksesnya, tapi memiliki entri outbox lokal belum terkirim)
      await db.into(db.siswa).insert(
        SiswaCompanion.insert(
          id: 's-2',
          nis: '202602',
          namaLengkap: 'Siswa Dua',
          jk: 'P',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );
      await db.into(db.keanggotaanRombel).insert(
        KeanggotaanRombelCompanion.insert(
          id: 'k-2',
          siswaId: 's-2',
          rombelId: 'rombel-7b',
          tanggalMasuk: '2026-07-15',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );
      // Masukkan k-2 ke outbox antrean
      await outboxManager.enqueueUpsert(
        table: 'keanggotaan_rombel',
        barisId: 'k-2',
        payload: {'id': 'k-2'},
      );

      // Siswa 3 (dicabut hak aksesnya, tidak ada outbox)
      await db.into(db.siswa).insert(
        SiswaCompanion.insert(
          id: 's-3',
          nis: '202603',
          namaLengkap: 'Siswa Tiga',
          jk: 'L',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );
      await db.into(db.keanggotaanRombel).insert(
        KeanggotaanRombelCompanion.insert(
          id: 'k-3',
          siswaId: 's-3',
          rombelId: 'rombel-7b',
          tanggalMasuk: '2026-07-15',
          createdAt: BigInt.from(1000),
          updatedAt: BigInt.from(1000),
          deviceId: 'test',
        ),
      );

      // Jalankan Local GC: hanya k-1 yang ada di active_scope
      await localGc.runLocalGc(
        allowedKeanggotaanIds: {'k-1'},
        isAdminOrKepala: false,
      );

      // Verifikasi:
      // k-1 tetap ada
      final k1Db = await (db.select(db.keanggotaanRombel)..where((tbl) => tbl.id.equals('k-1'))).getSingleOrNull();
      expect(k1Db, isNotNull);

      // k-2 tetap ada karena dilindungi outbox
      final k2Db = await (db.select(db.keanggotaanRombel)..where((tbl) => tbl.id.equals('k-2'))).getSingleOrNull();
      expect(k2Db, isNotNull);

      // k-3 dan s-3 terhapus bersih oleh local_gc()
      final k3Db = await (db.select(db.keanggotaanRombel)..where((tbl) => tbl.id.equals('k-3'))).getSingleOrNull();
      expect(k3Db, isNull);

      final s3Db = await (db.select(db.siswa)..where((tbl) => tbl.id.equals('s-3'))).getSingleOrNull();
      expect(s3Db, isNull);
    });
  });
}
