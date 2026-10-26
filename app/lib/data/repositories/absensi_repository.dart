import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

class SiswaAbsensiItem {
  final String keanggotaanId;
  final String siswaId;
  final String namaLengkap;
  final String nis;
  final String? status; // 'H', 'S', 'I', 'A'
  final String? absensiId;

  const SiswaAbsensiItem({
    required this.keanggotaanId,
    required this.siswaId,
    required this.namaLengkap,
    required this.nis,
    this.status,
    this.absensiId,
  });
}

class AbsensiRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  AbsensiRepository(this.db, this.outbox);

  /// Mengambil daftar absensi siswa pada tanggal tertentu
  Future<List<SiswaAbsensiItem>> getAbsensiByTanggal({
    required String rombelId,
    required String semesterId,
    required DateTime tanggal,
  }) async {
    final tanggalStr = tanggal.toIso8601String().substring(0, 10);

    final keanggotaanQuery = db.select(db.keanggotaanRombel).join([
      innerJoin(db.siswa, db.siswa.id.equalsExp(db.keanggotaanRombel.siswaId)),
    ])
      ..where(
        db.keanggotaanRombel.rombelId.equals(rombelId) &
            db.keanggotaanRombel.tanggalKeluar.isNull() &
            db.keanggotaanRombel.deleted.equals(0) &
            db.siswa.deleted.equals(0),
      )
      ..orderBy([OrderingTerm.asc(db.siswa.namaLengkap)]);

    final rows = await keanggotaanQuery.get();

    // Ambil data absensi pada tanggal tersebut
    final absensiRows = await (db.select(db.absensi)
          ..where((t) =>
              t.semesterId.equals(semesterId) &
              t.tanggal.equals(tanggalStr) &
              t.deleted.equals(0)))
        .get();

    final absensiMap = {for (final a in absensiRows) a.keanggotaanId: a};

    return rows.map((r) {
      final k = r.readTable(db.keanggotaanRombel);
      final s = r.readTable(db.siswa);
      final a = absensiMap[k.id];

      return SiswaAbsensiItem(
        keanggotaanId: k.id,
        siswaId: s.id,
        namaLengkap: s.namaLengkap,
        nis: s.nis,
        status: a?.status,
        absensiId: a?.id,
      );
    }).toList();
  }

  /// Memperbarui atau menyimpan status absensi siswa tunggal
  Future<void> setStatusAbsensi({
    required String keanggotaanId,
    required String semesterId,
    required DateTime tanggal,
    required String status, // 'H', 'S', 'I', 'A'
    required String userId,
    required String deviceId,
  }) async {
    final tanggalStr = tanggal.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);

    final existing = await (db.select(db.absensi)
          ..where((t) =>
              t.keanggotaanId.equals(keanggotaanId) &
              t.tanggal.equals(tanggalStr) &
              t.deleted.equals(0)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.absensi)..where((t) => t.id.equals(existing.id))).write(
        AbsensiCompanion(
          status: Value(status),
          updatedAt: Value(nowEpoch),
          deviceId: Value(deviceId),
        ),
      );
      await outbox.enqueue(tabel: 'absensi', recordId: existing.id, operasi: 'UPDATE');
    } else {
      final newId = _uuid.v4();
      final item = AbsensiCompanion.insert(
        id: newId,
        keanggotaanId: keanggotaanId,
        semesterId: semesterId,
        tanggal: tanggalStr,
        status: status,
        diinputOlehUserId: userId,
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.absensi).insert(item);
      await outbox.enqueue(tabel: 'absensi', recordId: newId, operasi: 'INSERT');
    }
  }

  /// Mengatur semua siswa di kelas menjadi Hadir (H) secara massal
  Future<void> setSemuaHadir({
    required String rombelId,
    required String semesterId,
    required DateTime tanggal,
    required String userId,
    required String deviceId,
  }) async {
    final siswaList = await getAbsensiByTanggal(
      rombelId: rombelId,
      semesterId: semesterId,
      tanggal: tanggal,
    );

    await db.transaction(() async {
      for (final s in siswaList) {
        if (s.status != 'H') {
          await setStatusAbsensi(
            keanggotaanId: s.keanggotaanId,
            semesterId: semesterId,
            tanggal: tanggal,
            status: 'H',
            userId: userId,
            deviceId: deviceId,
          );
        }
      }
    });
  }
}
