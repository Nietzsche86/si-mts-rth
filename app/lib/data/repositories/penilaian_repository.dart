import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';
import '../../domain/kalkulator_k13.dart';

class SiswaNilaiItem {
  final String keanggotaanId;
  final String siswaId;
  final String namaLengkap;
  final String nis;
  final NilaiData? nilai;
  final bool isBawaanRombelAsal;

  const SiswaNilaiItem({
    required this.keanggotaanId,
    required this.siswaId,
    required this.namaLengkap,
    required this.nis,
    this.nilai,
    required this.isBawaanRombelAsal,
  });

  double? get nilaiAngka => nilai?.nilai;
}

class PenilaianRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  PenilaianRepository(this.db, this.outbox);

  /// Mengambil daftar siswa beserta nilai untuk jenis nilai tertentu
  Future<List<SiswaNilaiItem>> getSiswaNilaiList({
    required String rombelId,
    required String mapelId,
    required String semesterId,
    required String jenisNilaiId,
    required int urutanKe,
  }) async {
    // 1. Ambil keanggotaan aktif siswa di rombel
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

    // 2. Ambil nilai yang sudah ada untuk kombinasi ini
    final nilaiQuery = db.select(db.nilai)
      ..where((t) =>
          t.mapelId.equals(mapelId) &
          t.semesterId.equals(semesterId) &
          t.jenisNilaiId.equals(jenisNilaiId) &
          t.urutanKe.equals(urutanKe) &
          t.deleted.equals(0));

    final nilaiList = await nilaiQuery.get();
    final nilaiMap = {for (final n in nilaiList) n.keanggotaanId: n};

    // 3. Gabungkan menjadi SiswaNilaiItem
    return rows.map((r) {
      final k = r.readTable(db.keanggotaanRombel);
      final s = r.readTable(db.siswa);
      final n = nilaiMap[k.id];

      return SiswaNilaiItem(
        keanggotaanId: k.id,
        siswaId: s.id,
        namaLengkap: s.namaLengkap,
        nis: s.nis,
        nilai: n,
        isBawaanRombelAsal: n?.sumberNilaiId != null,
      );
    }).toList();
  }

  /// Menyimpan atau memperbarui nilai siswa (Fast-Entry Grid)
  Future<void> simpanNilai({
    required String keanggotaanId,
    required String mapelId,
    required String semesterId,
    required String jenisNilaiId,
    required int urutanKe,
    required double nilaiAngka,
    required String guruId,
    String? keterangan,
    required String deviceId,
  }) async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    final existing = await (db.select(db.nilai)
          ..where((t) =>
              t.keanggotaanId.equals(keanggotaanId) &
              t.mapelId.equals(mapelId) &
              t.semesterId.equals(semesterId) &
              t.jenisNilaiId.equals(jenisNilaiId) &
              t.urutanKe.equals(urutanKe) &
              t.deleted.equals(0)))
        .getSingleOrNull();

    if (existing != null) {
      // Update nilai yang ada
      await (db.update(db.nilai)..where((t) => t.id.equals(existing.id))).write(
        NilaiCompanion(
          nilai: Value(nilaiAngka),
          keterangan: Value(keterangan ?? existing.keterangan),
          updatedAt: Value(nowEpoch),
          deviceId: Value(deviceId),
        ),
      );
      await outbox.enqueue(tabel: 'nilai', recordId: existing.id, operasi: 'UPDATE');
    } else {
      // Insert nilai baru
      final newId = _uuid.v4();
      final item = NilaiCompanion.insert(
        id: newId,
        keanggotaanId: keanggotaanId,
        mapelId: mapelId,
        semesterId: semesterId,
        jenisNilaiId: jenisNilaiId,
        urutanKe: Value(urutanKe),
        nilai: nilaiAngka,
        tanggal: nowStr,
        keterangan: Value(keterangan),
        diinputOlehGuruId: guruId,
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.nilai).insert(item);
      await outbox.enqueue(tabel: 'nilai', recordId: newId, operasi: 'INSERT');
    }
  }

  /// Menghitung rekap nilai K13 on-the-fly untuk seorang siswa dalam suatu mapel
  Future<HasilKalkulasiK13> hitungRekapSiswa({
    required String keanggotaanId,
    required String mapelId,
    required String semesterId,
    required double kkm,
  }) async {
    final nilaiRows = await (db.select(db.nilai)
          ..where((t) =>
              t.keanggotaanId.equals(keanggotaanId) &
              t.mapelId.equals(mapelId) &
              t.semesterId.equals(semesterId) &
              t.deleted.equals(0)))
        .get();

    final bobotRows = await (db.select(db.bobotNilai)
          ..where((t) =>
              t.mapelId.equals(mapelId) &
              t.semesterId.equals(semesterId) &
              t.deleted.equals(0)))
        .get();

    final bobotMap = {for (final b in bobotRows) b.jenisNilaiId: b.bobot};

    // Hitung rata-rata per jenis nilai
    final valuesPerJenis = <String, List<double>>{};
    for (final n in nilaiRows) {
      valuesPerJenis.putIfAbsent(n.jenisNilaiId, () => []).add(n.nilai);
    }

    final rataRataPerJenis = <String, double>{};
    for (final entry in valuesPerJenis.entries) {
      final sum = entry.value.reduce((a, b) => a + b);
      rataRataPerJenis[entry.key] = sum / entry.value.length;
    }

    return KalkulatorK13.hitungNilaiAkhir(
      rataRataPerJenis: rataRataPerJenis,
      bobotPerJenis: bobotMap,
      kkm: kkm,
    );
  }
}
