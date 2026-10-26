import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

enum SectionKey { aDataDiri, bOrangTua, cWali, dAlamat, eSensitif, fRekamJejak, gBerkas }

class SiswaFullProfile {
  final SiswaData siswa;
  final SiswaDetailData? detail;
  final List<SiswaOrtuData> ortuList;
  final AlamatData? alamat;
  final SiswaSensitifData? sensitif;

  const SiswaFullProfile({
    required this.siswa,
    this.detail,
    this.ortuList = const [],
    this.alamat,
    this.sensitif,
  });

  /// Menghitung persentase kelengkapan profil (0 - 100%)
  int get completenessPercentage {
    int total = 5;
    int filled = 0;

    // A. Data Diri
    if (siswa.namaLengkap.isNotEmpty && siswa.nis.isNotEmpty && (siswa.nisn?.isNotEmpty ?? false)) {
      filled++;
    }

    // B. Orang Tua (Ayah dan Ibu)
    final hasAyah = ortuList.any((o) => o.hubungan == 'ayah' && o.namaLengkap.isNotEmpty);
    final hasIbu = ortuList.any((o) => o.hubungan == 'ibu' && o.namaLengkap.isNotEmpty);
    if (hasAyah && hasIbu) {
      filled++;
    }

    // C. Wali / Kebutuhan
    final hasWali = ortuList.any((o) => o.hubungan == 'wali' && o.namaLengkap.isNotEmpty);
    if (hasWali || (hasAyah && hasIbu)) {
      filled++;
    }

    // D. Alamat
    if (alamat != null && (alamat!.jalan?.isNotEmpty ?? false) && (alamat!.desaNama?.isNotEmpty ?? false)) {
      filled++;
    }

    // E. Data Sensitif
    if (sensitif != null && (sensitif!.nikSiswaEnc?.isNotEmpty ?? false)) {
      filled++;
    }

    return ((filled / total) * 100).round();
  }
}

class SiswaRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  SiswaRepository(this.db, this.outbox);

  /// Mengambil daftar siswa aktif dalam rombel
  Future<List<SiswaData>> getSiswaByRombel(String rombelId, String semesterId) async {
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

  /// Mengambil profil lengkap siswa A-E
  Future<SiswaFullProfile?> getSiswaFullProfile(String siswaId) async {
    final siswa = await (db.select(db.siswa)..where((t) => t.id.equals(siswaId) & t.deleted.equals(0))).getSingleOrNull();
    if (siswa == null) return null;

    final detail = await (db.select(db.siswaDetail)..where((t) => t.siswaId.equals(siswaId) & t.deleted.equals(0))).getSingleOrNull();
    final ortuList = await (db.select(db.siswaOrtu)..where((t) => t.siswaId.equals(siswaId) & t.deleted.equals(0))).get();
    final alamat = await (db.select(db.alamat)..where((t) => t.pemilikId.equals(siswaId) & t.deleted.equals(0))).getSingleOrNull();
    final sensitif = await (db.select(db.siswaSensitif)..where((t) => t.siswaId.equals(siswaId) & t.deleted.equals(0))).getSingleOrNull();

    return SiswaFullProfile(
      siswa: siswa,
      detail: detail,
      ortuList: ortuList,
      alamat: alamat,
      sensitif: sensitif,
    );
  }

  /// Menyimpan profil siswa dan antrekan perubahan ke outbox
  Future<void> saveSiswaProfile({
    required SiswaData siswa,
    SiswaDetailData? detail,
    List<SiswaOrtuData> ortuList = const [],
    AlamatData? alamat,
    SiswaSensitifData? sensitif,
  }) async {
    await db.transaction(() async {
      // 1. Simpan Siswa (Tier 1)
      await db.into(db.siswa).insertOnConflictUpdate(siswa);
      await outbox.enqueue(tabel: 'siswa', recordId: siswa.id, operasi: 'UPDATE');

      // 2. Simpan Detail (Tier 2)
      if (detail != null) {
        await db.into(db.siswaDetail).insertOnConflictUpdate(detail);
        await outbox.enqueue(tabel: 'siswa_detail', recordId: detail.id, operasi: 'UPDATE');
      }

      // 3. Simpan Ortu (Tier 2)
      for (final ortu in ortuList) {
        await db.into(db.siswaOrtu).insertOnConflictUpdate(ortu);
        await outbox.enqueue(tabel: 'siswa_ortu', recordId: ortu.id, operasi: 'UPDATE');
      }

      // 4. Simpan Alamat (Tier 2)
      if (alamat != null) {
        await db.into(db.alamat).insertOnConflictUpdate(alamat);
        await outbox.enqueue(tabel: 'alamat', recordId: alamat.id, operasi: 'UPDATE');
      }

      // 5. Simpan Sensitif (Tier 2)
      if (sensitif != null) {
        await db.into(db.siswaSensitif).insertOnConflictUpdate(sensitif);
        await outbox.enqueue(tabel: 'siswa_sensitif', recordId: sensitif.id, operasi: 'UPDATE');
      }
    });
  }

  /// Mencatat audit log saat data sensitif (NIK/KK) dibuka
  Future<void> logSensitifAccess({
    required String siswaId,
    required String kolom,
    required String userId,
    required String deviceId,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final logId = _uuid.v4();
    await outbox.enqueue(
      tabel: 'audit_log',
      recordId: logId,
      operasi: 'INSERT',
      payload: {
        'id': logId,
        'waktu': nowMs,
        'user_id': userId,
        'device_id': deviceId,
        'tabel': 'siswa_sensitif',
        'record_id': siswaId,
        'aksi': 'VIEW_SENSITIVE',
        'metadata_json': '{"kolom": "$kolom", "keterangan": "Akses visual NIK/KK disamarkan"}',
      },
    );
  }
}
