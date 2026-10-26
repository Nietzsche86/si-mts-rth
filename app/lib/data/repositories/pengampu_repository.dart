import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

enum ModePembagianKelompok { ganjilGenap, rata }

class PengampuRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  PengampuRepository(this.db, this.outbox);

  /// Mengambil daftar siswa yang menjadi tanggung jawab seorang pengampu
  /// Mengimplementasikan aturan Fallback Guru Utama (PRD F9)
  Future<List<SiswaData>> getSiswaForPengampu({
    required String pengampuId,
    required String rombelId,
    required String semesterId,
  }) async {
    final pengampu = await (db.select(db.pengampu)
          ..where((t) => t.id.equals(pengampuId) & t.deleted.equals(0)))
        .getSingleOrNull();

    if (pengampu == null) return [];

    // Jika cakupan seluruh siswa, kembalikan semua siswa aktif di rombel
    if (pengampu.cakupan == 'seluruh') {
      final query = db.select(db.keanggotaanRombel).join([
        innerJoin(db.siswa, db.siswa.id.equalsExp(db.keanggotaanRombel.siswaId)),
      ])
        ..where(
          db.keanggotaanRombel.rombelId.equals(rombelId) &
              db.keanggotaanRombel.tanggalKeluar.isNull() &
              db.keanggotaanRombel.deleted.equals(0) &
              db.siswa.deleted.equals(0),
        )
        ..orderBy([OrderingTerm.asc(db.siswa.namaLengkap)]);

      final rows = await query.get();
      return rows.map((r) => r.readTable(db.siswa)).toList();
    }

    // Jika cakupan sebagian:
    // Ambil siswa yang terdaftar spesifik pada pengampu ini
    final assignedQuery = db.select(db.pengampuSiswa).join([
      innerJoin(db.keanggotaanRombel, db.keanggotaanRombel.id.equalsExp(db.pengampuSiswa.keanggotaanId)),
      innerJoin(db.siswa, db.siswa.id.equalsExp(db.keanggotaanRombel.siswaId)),
    ])
      ..where(
        db.pengampuSiswa.pengampuId.equals(pengampuId) &
            db.pengampuSiswa.deleted.equals(0) &
            db.keanggotaanRombel.deleted.equals(0) &
            db.siswa.deleted.equals(0),
      );

    final assignedRows = await assignedQuery.get();
    final assignedStudents = assignedRows.map((r) => r.readTable(db.siswa)).toList();

    // Jika pengampu pendamping, hanya siswa yang terdaftar di kelompoknya
    if (pengampu.peran != 'utama') {
      assignedStudents.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
      return assignedStudents;
    }

    // Jika GURU UTAMA: tambahkan siswa yang belum memiliki kelompok pada mapel ini (Fallback)
    // 1. Ambil semua keanggotaan ID aktif di rombel
    final allKeanggotaan = await (db.select(db.keanggotaanRombel)
          ..where((t) =>
              t.rombelId.equals(rombelId) &
              t.tanggalKeluar.isNull() &
              t.deleted.equals(0)))
        .get();

    // 2. Ambil semua pengampu untuk mapel & rombel ini
    final allPengampuIds = (await (db.select(db.pengampu)
              ..where((t) =>
                  t.rombelId.equals(rombelId) &
                  t.mapelId.equals(pengampu.mapelId) &
                  t.semesterId.equals(semesterId) &
                  t.tanggalSelesai.isNull() &
                  t.deleted.equals(0)))
            .get())
        .map((p) => p.id)
        .toList();

    // 3. Ambil semua keanggotaan yang sudah terikat di pengampu_siswa untuk mapel ini
    final groupedKeanggotaan = (await (db.select(db.pengampuSiswa)
              ..where((t) => t.pengampuId.isIn(allPengampuIds) & t.deleted.equals(0)))
            .get())
        .map((ps) => ps.keanggotaanId)
        .toSet();

    // 4. Cari keanggotaan yang belum terikat (unassigned)
    final unassignedSiswaIds = allKeanggotaan
        .where((k) => !groupedKeanggotaan.contains(k.id))
        .map((k) => k.siswaId)
        .toList();

    if (unassignedSiswaIds.isNotEmpty) {
      final unassignedStudents = await (db.select(db.siswa)
            ..where((t) => t.id.isIn(unassignedSiswaIds) & t.deleted.equals(0)))
          .get();

      final combinedSet = <String, SiswaData>{};
      for (final s in assignedStudents) {
        combinedSet[s.id] = s;
      }
      for (final s in unassignedStudents) {
        combinedSet[s.id] = s;
      }

      final result = combinedSet.values.toList();
      result.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
      return result;
    }

    assignedStudents.sort((a, b) => a.namaLengkap.compareTo(b.namaLengkap));
    return assignedStudents;
  }

  /// Membagi siswa ke kelompok secara otomatis (Ganjil/Genap atau Rata)
  Future<void> bagiKelompokOtomatis({
    required List<String> pengampuIds,
    required String rombelId,
    required String semesterId,
    required ModePembagianKelompok mode,
    required String deviceId,
  }) async {
    if (pengampuIds.isEmpty) return;

    final query = db.select(db.keanggotaanRombel).join([
      innerJoin(db.siswa, db.siswa.id.equalsExp(db.keanggotaanRombel.siswaId)),
    ])
      ..where(
        db.keanggotaanRombel.rombelId.equals(rombelId) &
            db.keanggotaanRombel.tanggalKeluar.isNull() &
            db.keanggotaanRombel.deleted.equals(0),
      )
      ..orderBy([OrderingTerm.asc(db.siswa.namaLengkap)]);

    final rows = await query.get();
    final keanggotaanList = rows.map((r) => r.readTable(db.keanggotaanRombel)).toList();

    await db.transaction(() async {
      final now = DateTime.now();
      final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

      for (int i = 0; i < keanggotaanList.length; i++) {
        final k = keanggotaanList[i];
        final String targetPengampuId;

        if (mode == ModePembagianKelompok.ganjilGenap) {
          final groupIndex = i % pengampuIds.length;
          targetPengampuId = pengampuIds[groupIndex];
        } else {
          // Mode Rata
          final chunkSize = (keanggotaanList.length / pengampuIds.length).ceil();
          final groupIndex = (i ~/ chunkSize).clamp(0, pengampuIds.length - 1);
          targetPengampuId = pengampuIds[groupIndex];
        }

        final psId = _uuid.v4();
        final item = PengampuSiswaCompanion.insert(
          id: psId,
          pengampuId: targetPengampuId,
          keanggotaanId: k.id,
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        );
        await db.into(db.pengampuSiswa).insert(item);
        await outbox.enqueue(tabel: 'pengampu_siswa', recordId: psId, operasi: 'INSERT');
      }
    });
  }
}
