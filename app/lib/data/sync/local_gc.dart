import '../db/app_database.dart';

/// Prosedur Local Garbage Collection (PRD F17 & CLAUDE.md 6.3)
/// Dijalankan setelah Pull Sync selesai untuk menghapus data siswa yang tidak lagi
/// berada dalam active_scope user (misal mutasi, pergantian wali kelas, atau pencabutan pengampu).
/// Penghapusan dilakukan dari Tingkat 5 turun ke Tingkat 3.
/// Item yang masih mengantre di tabel `outbox` TIDAK BOLEH dihapus.
class LocalGarbageCollector {
  final AppDatabase db;

  LocalGarbageCollector(this.db);

  Future<void> runLocalGc({
    required Set<String> allowedKeanggotaanIds,
    required bool isAdminOrKepala,
  }) async {
    // Admin dan Kepala Madrasah berhak atas seluruh data, tidak perlu GC
    if (isAdminOrKepala) return;

    // Ambil semua baris_id yang sedang mengantre di outbox agar tidak terhapus prematur
    final outboxRows = await db.select(db.outbox).get();
    final pendingOutboxBarisIds = outboxRows.map((o) => o.barisId).toSet();

    await db.transaction(() async {
      // 1. Tingkat 5: Nilai & Absensi
      // Hapus nilai yang keanggotaan_id-nya di luar allowedKeanggotaanIds
      final nilaiToDelete = await (db.select(db.nilai)
            ..where((tbl) => tbl.keanggotaanId.isNotIn(allowedKeanggotaanIds)))
          .get();

      for (final n in nilaiToDelete) {
        if (!pendingOutboxBarisIds.contains(n.id)) {
          await (db.delete(db.nilai)..where((tbl) => tbl.id.equals(n.id))).go();
        }
      }

      // Hapus absensi yang keanggotaan_id-nya di luar allowedKeanggotaanIds
      final absensiToDelete = await (db.select(db.absensi)
            ..where((tbl) => tbl.keanggotaanId.isNotIn(allowedKeanggotaanIds)))
          .get();

      for (final a in absensiToDelete) {
        if (!pendingOutboxBarisIds.contains(a.id)) {
          await (db.delete(db.absensi)..where((tbl) => tbl.id.equals(a.id))).go();
        }
      }

      // 2. Tingkat 4: Keanggotaan Rombel
      final keanggotaanToDelete = await (db.select(db.keanggotaanRombel)
            ..where((tbl) => tbl.id.isNotIn(allowedKeanggotaanIds)))
          .get();

      for (final k in keanggotaanToDelete) {
        if (!pendingOutboxBarisIds.contains(k.id)) {
          await (db.delete(db.keanggotaanRombel)..where((tbl) => tbl.id.equals(k.id))).go();
        }
      }

      // 3. Tingkat 3: Siswa & Detail Siswa yang sudah tidak memiliki keanggotaan aktif lokal
      final remainingKeanggotaan = await db.select(db.keanggotaanRombel).get();
      final remainingSiswaIds = remainingKeanggotaan.map((k) => k.siswaId).toSet();

      final siswaToDelete = await (db.select(db.siswa)
            ..where((tbl) => tbl.id.isNotIn(remainingSiswaIds)))
          .get();

      for (final s in siswaToDelete) {
        if (!pendingOutboxBarisIds.contains(s.id)) {
          // Hapus detail terkait terlebih dahulu
          await (db.delete(db.siswaDetail)..where((tbl) => tbl.siswaId.equals(s.id))).go();
          await (db.delete(db.siswaOrtu)..where((tbl) => tbl.siswaId.equals(s.id))).go();
          await (db.delete(db.siswaSensitif)..where((tbl) => tbl.siswaId.equals(s.id))).go();
          await (db.delete(db.alamat)..where((tbl) => tbl.pemilikId.equals(s.id))).go();
          await (db.delete(db.siswaBerkas)..where((tbl) => tbl.siswaId.equals(s.id))).go();
          await (db.delete(db.siswa)..where((tbl) => tbl.id.equals(s.id))).go();
        }
      }
    });
  }
}
