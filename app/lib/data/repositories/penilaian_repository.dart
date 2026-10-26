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

/// Model rekap nilai satu mata pelajaran untuk seorang siswa
class RekapNilaiMapelSiswa {
  final String mapelId;
  final String mapelNama;
  final String mapelKode;
  final double kkm;
  final double rataPengetahuan;
  final String predikatPengetahuan;
  final double rataKeterampilan;
  final String predikatKeterampilan;
  final double nilaiAkhir;
  final String predikat;
  final bool tuntas;
  final Map<String, List<double>> detailNilaiPerJenis;

  const RekapNilaiMapelSiswa({
    required this.mapelId,
    required this.mapelNama,
    required this.mapelKode,
    required this.kkm,
    required this.rataPengetahuan,
    required this.predikatPengetahuan,
    required this.rataKeterampilan,
    required this.predikatKeterampilan,
    required this.nilaiAkhir,
    required this.predikat,
    required this.tuntas,
    required this.detailNilaiPerJenis,
  });
}

/// Model rekap akumulatif seorang siswa dalam rombel (termasuk ranking & predikat gabungan)
class RekapNilaiSiswaItem {
  final String keanggotaanId;
  final String siswaId;
  final String namaLengkap;
  final String nis;
  final String jenisKelamin;
  final Map<String, RekapNilaiMapelSiswa> nilaiPerMapel;
  final double rataRataAkhir;
  final double totalNilai;
  final int ranking;
  final String predikat;
  final bool tuntasSemua;
  final int jumlahMapelTuntas;
  final int jumlahMapelRemedial;

  const RekapNilaiSiswaItem({
    required this.keanggotaanId,
    required this.siswaId,
    required this.namaLengkap,
    required this.nis,
    required this.jenisKelamin,
    required this.nilaiPerMapel,
    required this.rataRataAkhir,
    required this.totalNilai,
    required this.ranking,
    required this.predikat,
    required this.tuntasSemua,
    required this.jumlahMapelTuntas,
    required this.jumlahMapelRemedial,
  });
}

/// Model hasil rekapitulasi nilai satu rombel lengkap dengan metrik statistik
class RekapRombelResult {
  final String rombelId;
  final String rombelNama;
  final String semesterId;
  final List<RekapNilaiSiswaItem> siswaItems;
  final List<MapelData> mapelList;
  final double rataRataRombel;
  final double nilaiTertinggi;
  final double nilaiTerendah;
  final double persentaseKetuntasan;

  const RekapRombelResult({
    required this.rombelId,
    required this.rombelNama,
    required this.semesterId,
    required this.siswaItems,
    required this.mapelList,
    required this.rataRataRombel,
    required this.nilaiTertinggi,
    required this.nilaiTerendah,
    required this.persentaseKetuntasan,
  });
}

/// Model progres kelengkapan entri nilai untuk setiap penugasan pengampu
class ProgresPengampuItem {
  final String pengampuId;
  final String guruId;
  final String guruNama;
  final String mapelId;
  final String mapelNama;
  final String rombelId;
  final String rombelNama;
  final String peran; // 'utama' | 'pendamping'
  final String cakupan; // 'seluruh' | 'sebagian'
  final int totalSiswaTarget;
  final int jumlahSiswaTernilai;
  final double persentaseKelengkapan;
  final Map<String, int> rincianJenisNilai;
  final String statusKelengkapan; // 'Lengkap' | 'Sedang Berjalan' | 'Belum Mengisi'

  const ProgresPengampuItem({
    required this.pengampuId,
    required this.guruId,
    required this.guruNama,
    required this.mapelId,
    required this.mapelNama,
    required this.rombelId,
    required this.rombelNama,
    required this.peran,
    required this.cakupan,
    required this.totalSiswaTarget,
    required this.jumlahSiswaTernilai,
    required this.persentaseKelengkapan,
    required this.rincianJenisNilai,
    required this.statusKelengkapan,
  });
}

/// Model ringkasan ketuntasan belajar per mata pelajaran (Dashboard Kepala Madrasah)
class MapelKetuntasanSummary {
  final String mapelId;
  final String mapelNama;
  final String mapelKode;
  final double kkm;
  final int totalSiswa;
  final int jumlahTuntas;
  final int jumlahRemedial;
  final double persentaseKetuntasan;
  final double rataRataMapel;

  const MapelKetuntasanSummary({
    required this.mapelId,
    required this.mapelNama,
    required this.mapelKode,
    required this.kkm,
    required this.totalSiswa,
    required this.jumlahTuntas,
    required this.jumlahRemedial,
    required this.persentaseKetuntasan,
    required this.rataRataMapel,
  });
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

    final nilaiQuery = db.select(db.nilai)
      ..where((t) =>
          t.mapelId.equals(mapelId) &
          t.semesterId.equals(semesterId) &
          t.jenisNilaiId.equals(jenisNilaiId) &
          t.urutanKe.equals(urutanKe) &
          t.deleted.equals(0));

    final nilaiList = await nilaiQuery.get();
    final nilaiMap = {for (final n in nilaiList) n.keanggotaanId: n};

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
              (t.mapelId.equals(mapelId) | t.mapelId.isNull()) &
              t.semesterId.equals(semesterId) &
              t.deleted.equals(0)))
        .get();

    final bobotMap = <String, double>{};
    for (final b in bobotRows) {
      if (b.mapelId == mapelId || !bobotMap.containsKey(b.jenisNilaiId)) {
        bobotMap[b.jenisNilaiId] = b.bobot;
      }
    }

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

  /// Mengambil rekap nilai lengkap satu rombel (beserta pemeringkatan / ranking otomatis K13)
  Future<RekapRombelResult> getRekapNilaiRombel({
    required String rombelId,
    required String semesterId,
    String? mapelId,
  }) async {
    // 1. Ambil info Rombel
    final rombel = await (db.select(db.rombel)..where((t) => t.id.equals(rombelId))).getSingle();

    // 2. Ambil siswa aktif di rombel
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
    final keanggotaanIds = rows.map((r) => r.readTable(db.keanggotaanRombel).id).toList();

    // 3. Ambil daftar mapel aktif
    final mapelQuery = db.select(db.mapel)
      ..where((t) => t.aktif.equals(1) & t.deleted.equals(0));
    if (mapelId != null) {
      mapelQuery.where((t) => t.id.equals(mapelId));
    }
    mapelQuery.orderBy([(t) => OrderingTerm.asc(t.urutan)]);
    final mapelList = await mapelQuery.get();

    // 4. Ambil semua Jenis Nilai aktif
    final jenisNilaiList = await (db.select(db.jenisNilai)
          ..where((t) => t.aktif.equals(1) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.urutan)]))
        .get();

    final kategoriPerJenis = {for (final j in jenisNilaiList) j.id: j.kategori};
    final kodePerJenis = {for (final j in jenisNilaiList) j.id: j.kode};

    // 5. Ambil Pengaturan KKM di semester ini
    final kkmRows = await (db.select(db.pengaturanKkm)
          ..where((t) => t.semesterId.equals(semesterId) & t.deleted.equals(0)))
        .get();

    // Helper KKM fallback: mapel -> kkm, default 75.0
    double getKkmForMapel(String mId) {
      final specific = kkmRows.where((k) => k.mapelId == mId).firstOrNull;
      if (specific != null) return specific.kkm;
      final global = kkmRows.where((k) => k.mapelId == null).firstOrNull;
      return global?.kkm ?? 75.0;
    }

    // 6. Ambil Bobot Nilai di semester ini
    final bobotRows = await (db.select(db.bobotNilai)
          ..where((t) => t.semesterId.equals(semesterId) & t.deleted.equals(0)))
        .get();

    Map<String, double> getBobotForMapel(String mId) {
      final map = <String, double>{};
      for (final b in bobotRows) {
        if (b.mapelId == mId || b.mapelId == null) {
          if (b.mapelId == mId || !map.containsKey(b.jenisNilaiId)) {
            map[b.jenisNilaiId] = b.bobot;
          }
        }
      }
      return map;
    }

    // 7. Ambil seluruh nilai rombel di semester ini
    final nilaiRows = keanggotaanIds.isEmpty
        ? <NilaiData>[]
        : await (db.select(db.nilai)
              ..where((t) =>
                  t.keanggotaanId.isIn(keanggotaanIds) &
                  t.semesterId.equals(semesterId) &
                  t.deleted.equals(0)))
            .get();

    // Map: keanggotaanId -> mapelId -> jenisNilaiId -> List<double>
    final gradeTree = <String, Map<String, Map<String, List<double>>>>{};
    for (final n in nilaiRows) {
      gradeTree
          .putIfAbsent(n.keanggotaanId, () => {})
          .putIfAbsent(n.mapelId, () => {})
          .putIfAbsent(n.jenisNilaiId, () => [])
          .add(n.nilai);
    }

    // 8. Hitung rekap per siswa
    final precalculatedSiswa = <String, ({
      SiswaData siswa,
      String keanggotaanId,
      Map<String, RekapNilaiMapelSiswa> nilaiMapel,
      double rataRataAkhir,
      double totalNilai,
      String predikat,
      bool tuntasSemua,
      int mapelTuntas,
      int mapelRemedial,
    })>{};

    final scoreMapForRanking = <String, double>{};

    for (final r in rows) {
      final k = r.readTable(db.keanggotaanRombel);
      final s = r.readTable(db.siswa);

      final studentGrades = gradeTree[k.id] ?? {};
      final mapelResults = <String, RekapNilaiMapelSiswa>{};

      double sumMapelScore = 0.0;
      int countMapelWithScore = 0;
      int countTuntas = 0;
      int countRemedial = 0;

      for (final mapel in mapelList) {
        final kkm = getKkmForMapel(mapel.id);
        final bobotMap = getBobotForMapel(mapel.id);
        final rawJenisGrades = studentGrades[mapel.id] ?? {};

        // Rata-rata per jenis
        final avgPerJenis = <String, double>{};
        final detailPerKode = <String, List<double>>{};

        for (final entry in rawJenisGrades.entries) {
          final jId = entry.key;
          final scores = entry.value;
          if (scores.isNotEmpty) {
            final avg = scores.reduce((a, b) => a + b) / scores.length;
            avgPerJenis[jId] = avg;
            final kode = kodePerJenis[jId] ?? jId;
            detailPerKode[kode] = scores;
          }
        }

        final k13 = KalkulatorK13.hitungK13Lengkap(
          rataRataPerJenis: avgPerJenis,
          bobotPerJenis: bobotMap,
          kategoriPerJenis: kategoriPerJenis,
          kkm: kkm,
        );

        final rekapMapel = RekapNilaiMapelSiswa(
          mapelId: mapel.id,
          mapelNama: mapel.nama,
          mapelKode: mapel.kode,
          kkm: kkm,
          rataPengetahuan: k13.rataRataPengetahuan,
          predikatPengetahuan: k13.predikatPengetahuan,
          rataKeterampilan: k13.rataRataKeterampilan,
          predikatKeterampilan: k13.predikatKeterampilan,
          nilaiAkhir: k13.nilaiAkhir,
          predikat: k13.predikat,
          tuntas: k13.tuntas,
          detailNilaiPerJenis: detailPerKode,
        );

        mapelResults[mapel.id] = rekapMapel;

        if (avgPerJenis.isNotEmpty) {
          sumMapelScore += k13.nilaiAkhir;
          countMapelWithScore++;
          if (k13.tuntas) {
            countTuntas++;
          } else {
            countRemedial++;
          }
        }
      }

      final studentAvg = countMapelWithScore > 0
          ? double.parse((sumMapelScore / countMapelWithScore).toStringAsFixed(2))
          : 0.0;

      scoreMapForRanking[s.id] = studentAvg;

      precalculatedSiswa[s.id] = (
        siswa: s,
        keanggotaanId: k.id,
        nilaiMapel: mapelResults,
        rataRataAkhir: studentAvg,
        totalNilai: double.parse(sumMapelScore.toStringAsFixed(2)),
        predikat: KalkulatorK13.tentukanPredikat(studentAvg, 75.0),
        tuntasSemua: countRemedial == 0 && countMapelWithScore > 0,
        mapelTuntas: countTuntas,
        mapelRemedial: countRemedial,
      );
    }

    // 9. Hitung Ranking
    final rankingMap = KalkulatorK13.hitungRanking(scoreMapForRanking);

    final finalSiswaItems = <RekapNilaiSiswaItem>[];
    for (final entry in precalculatedSiswa.entries) {
      final sId = entry.key;
      final data = entry.value;

      finalSiswaItems.add(
        RekapNilaiSiswaItem(
          keanggotaanId: data.keanggotaanId,
          siswaId: sId,
          namaLengkap: data.siswa.namaLengkap,
          nis: data.siswa.nis,
          jenisKelamin: data.siswa.jk,
          nilaiPerMapel: data.nilaiMapel,
          rataRataAkhir: data.rataRataAkhir,
          totalNilai: data.totalNilai,
          ranking: rankingMap[sId] ?? 999,
          predikat: data.predikat,
          tuntasSemua: data.tuntasSemua,
          jumlahMapelTuntas: data.mapelTuntas,
          jumlahMapelRemedial: data.mapelRemedial,
        ),
      );
    }

    // Urutkan berdasarkan ranking asc
    finalSiswaItems.sort((a, b) {
      final rankComp = a.ranking.compareTo(b.ranking);
      if (rankComp != 0) return rankComp;
      return a.namaLengkap.compareTo(b.namaLengkap);
    });

    // 10. Hitung Statistik Rombel
    double rombelSum = 0.0;
    double maxScore = 0.0;
    double minScore = 100.0;
    int tuntasCount = 0;

    for (final s in finalSiswaItems) {
      if (s.rataRataAkhir > 0) {
        rombelSum += s.rataRataAkhir;
        if (s.rataRataAkhir > maxScore) maxScore = s.rataRataAkhir;
        if (s.rataRataAkhir < minScore) minScore = s.rataRataAkhir;
        if (s.tuntasSemua) tuntasCount++;
      }
    }

    final double rataRataRombel = finalSiswaItems.isNotEmpty && rombelSum > 0
        ? double.parse((rombelSum / finalSiswaItems.length).toStringAsFixed(2))
        : 0.0;
    final double persentaseKetuntasan = finalSiswaItems.isNotEmpty
        ? double.parse(((tuntasCount / finalSiswaItems.length) * 100.0).toStringAsFixed(1))
        : 0.0;

    return RekapRombelResult(
      rombelId: rombel.id,
      rombelNama: rombel.nama,
      semesterId: semesterId,
      siswaItems: finalSiswaItems,
      mapelList: mapelList,
      rataRataRombel: rataRataRombel,
      nilaiTertinggi: maxScore,
      nilaiTerendah: minScore == 100.0 && rombelSum == 0.0 ? 0.0 : minScore,
      persentaseKetuntasan: persentaseKetuntasan,
    );
  }

  /// Mengambil progres kelengkapan entri nilai untuk setiap pengampu di semester aktif
  Future<List<ProgresPengampuItem>> getProgresKelengkapanPengampu({
    required String semesterId,
    String? rombelId,
  }) async {
    final pengampuQuery = db.select(db.pengampu).join([
      innerJoin(db.guru, db.guru.id.equalsExp(db.pengampu.guruId)),
      innerJoin(db.rombel, db.rombel.id.equalsExp(db.pengampu.rombelId)),
      innerJoin(db.mapel, db.mapel.id.equalsExp(db.pengampu.mapelId)),
    ])
      ..where(
        db.pengampu.semesterId.equals(semesterId) &
            db.pengampu.tanggalSelesai.isNull() &
            db.pengampu.deleted.equals(0) &
            db.guru.deleted.equals(0) &
            db.rombel.deleted.equals(0) &
            db.mapel.deleted.equals(0),
      );

    if (rombelId != null) {
      pengampuQuery.where(db.pengampu.rombelId.equals(rombelId));
    }

    pengampuQuery.orderBy([
      OrderingTerm.asc(db.rombel.nama),
      OrderingTerm.asc(db.mapel.nama),
    ]);

    final rows = await pengampuQuery.get();
    final result = <ProgresPengampuItem>[];

    // Ambil jenis nilai untuk memetakan kode
    final jenisNilaiList = await (db.select(db.jenisNilai)
          ..where((t) => t.aktif.equals(1) & t.deleted.equals(0)))
        .get();
    final kodePerJenis = {for (final j in jenisNilaiList) j.id: j.kode};

    for (final r in rows) {
      final p = r.readTable(db.pengampu);
      final g = r.readTable(db.guru);
      final rombel = r.readTable(db.rombel);
      final mapel = r.readTable(db.mapel);

      // Hitung target siswa pengampu ini (mengakomodasi pengampu_siswa & fallback guru utama)
      List<String> targetKeanggotaanIds = [];

      if (p.cakupan == 'seluruh') {
        final activeKeanggotaan = await (db.select(db.keanggotaanRombel)
              ..where((t) =>
                  t.rombelId.equals(p.rombelId) &
                  t.tanggalKeluar.isNull() &
                  t.deleted.equals(0)))
            .get();
        targetKeanggotaanIds = activeKeanggotaan.map((k) => k.id).toList();
      } else {
        // Cakupan sebagian
        final assigned = await (db.select(db.pengampuSiswa)
              ..where((t) => t.pengampuId.equals(p.id) & t.deleted.equals(0)))
            .get();
        final assignedIds = assigned.map((ps) => ps.keanggotaanId).toSet();

        if (p.peran == 'utama') {
          // Tambahkan fallback siswa yang belum terpetakan di kelompok mana pun pada mapel ini
          final allPengampuIds = (await (db.select(db.pengampu)
                    ..where((t) =>
                        t.rombelId.equals(p.rombelId) &
                        t.mapelId.equals(p.mapelId) &
                        t.semesterId.equals(semesterId) &
                        t.tanggalSelesai.isNull() &
                        t.deleted.equals(0)))
                  .get())
              .map((e) => e.id)
              .toList();

          final allMappedKeanggotaan = (await (db.select(db.pengampuSiswa)
                    ..where((t) =>
                        t.pengampuId.isIn(allPengampuIds) & t.deleted.equals(0)))
                  .get())
              .map((e) => e.keanggotaanId)
              .toSet();

          final allKeanggotaan = await (db.select(db.keanggotaanRombel)
                ..where((t) =>
                    t.rombelId.equals(p.rombelId) &
                    t.tanggalKeluar.isNull() &
                    t.deleted.equals(0)))
              .get();

          final unassigned = allKeanggotaan
              .where((k) => !allMappedKeanggotaan.contains(k.id))
              .map((k) => k.id);

          assignedIds.addAll(unassigned);
        }

        targetKeanggotaanIds = assignedIds.toList();
      }

      final totalTarget = targetKeanggotaanIds.length;
      int siswaTernilai = 0;
      final rincianJenis = <String, int>{};

      if (totalTarget > 0) {
        final nilaiRows = await (db.select(db.nilai)
              ..where((t) =>
                  t.mapelId.equals(p.mapelId) &
                  t.semesterId.equals(semesterId) &
                  t.keanggotaanId.isIn(targetKeanggotaanIds) &
                  t.deleted.equals(0)))
            .get();

        final ratedKeanggotaan = nilaiRows.map((n) => n.keanggotaanId).toSet();
        siswaTernilai = ratedKeanggotaan.length;

        for (final n in nilaiRows) {
          final kode = kodePerJenis[n.jenisNilaiId] ?? n.jenisNilaiId;
          rincianJenis[kode] = (rincianJenis[kode] ?? 0) + 1;
        }
      }

      final double persentase = totalTarget > 0
          ? double.parse(((siswaTernilai / totalTarget) * 100.0).toStringAsFixed(1))
          : 0.0;

      String status;
      if (totalTarget > 0 && siswaTernilai >= totalTarget) {
        status = 'Lengkap';
      } else if (siswaTernilai > 0) {
        status = 'Sedang Berjalan';
      } else {
        status = 'Belum Mengisi';
      }

      result.add(
        ProgresPengampuItem(
          pengampuId: p.id,
          guruId: g.id,
          guruNama: g.namaLengkap,
          mapelId: mapel.id,
          mapelNama: mapel.nama,
          rombelId: rombel.id,
          rombelNama: rombel.nama,
          peran: p.peran,
          cakupan: p.cakupan,
          totalSiswaTarget: totalTarget,
          jumlahSiswaTernilai: siswaTernilai,
          persentaseKelengkapan: persentase,
          rincianJenisNilai: rincianJenis,
          statusKelengkapan: status,
        ),
      );
    }

    return result;
  }

  /// Mengambil statistik persentase ketuntasan per mata pelajaran (Dashboard Kepala Madrasah)
  Future<List<MapelKetuntasanSummary>> getRingkasanKetuntasanPerMapel({
    required String semesterId,
    String? rombelId,
    String? tingkat,
  }) async {
    // 1. Ambil rombel yang sesuai filter
    final rombelQuery = db.select(db.rombel)
      ..where((t) => t.deleted.equals(0));
    if (rombelId != null) {
      rombelQuery.where((t) => t.id.equals(rombelId));
    }
    if (tingkat != null) {
      rombelQuery.where((t) => t.tingkat.equals(tingkat));
    }
    final targetRombels = await rombelQuery.get();
    final targetRombelIds = targetRombels.map((r) => r.id).toList();

    if (targetRombelIds.isEmpty) return [];

    // 2. Ambil siswa aktif di rombel-rombel ini
    final keanggotaanAktif = await (db.select(db.keanggotaanRombel)
          ..where((t) =>
              t.rombelId.isIn(targetRombelIds) &
              t.tanggalKeluar.isNull() &
              t.deleted.equals(0)))
        .get();
    final keanggotaanIds = keanggotaanAktif.map((k) => k.id).toList();
    if (keanggotaanIds.isEmpty) return [];

    // 3. Ambil daftar mapel aktif
    final mapels = await (db.select(db.mapel)
          ..where((t) => t.aktif.equals(1) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.urutan)]))
        .get();

    // 4. KKM & Bobot
    final kkmRows = await (db.select(db.pengaturanKkm)
          ..where((t) => t.semesterId.equals(semesterId) & t.deleted.equals(0)))
        .get();
    final bobotRows = await (db.select(db.bobotNilai)
          ..where((t) => t.semesterId.equals(semesterId) & t.deleted.equals(0)))
        .get();

    double getKkm(String mId) {
      final specific = kkmRows.where((k) => k.mapelId == mId).firstOrNull;
      if (specific != null) return specific.kkm;
      final global = kkmRows.where((k) => k.mapelId == null).firstOrNull;
      return global?.kkm ?? 75.0;
    }

    Map<String, double> getBobot(String mId) {
      final map = <String, double>{};
      for (final b in bobotRows) {
        if (b.mapelId == mId || b.mapelId == null) {
          if (b.mapelId == mId || !map.containsKey(b.jenisNilaiId)) {
            map[b.jenisNilaiId] = b.bobot;
          }
        }
      }
      return map;
    }

    // 5. Ambil semua nilai
    final allNilai = await (db.select(db.nilai)
          ..where((t) =>
              t.keanggotaanId.isIn(keanggotaanIds) &
              t.semesterId.equals(semesterId) &
              t.deleted.equals(0)))
        .get();

    final result = <MapelKetuntasanSummary>[];

    for (final mapel in mapels) {
      final kkm = getKkm(mapel.id);
      final bobotMap = getBobot(mapel.id);

      final mapelNilai = allNilai.where((n) => n.mapelId == mapel.id).toList();

      // Kelompokkan per keanggotaanId
      final studentGrades = <String, Map<String, List<double>>>{};
      for (final n in mapelNilai) {
        studentGrades
            .putIfAbsent(n.keanggotaanId, () => {})
            .putIfAbsent(n.jenisNilaiId, () => [])
            .add(n.nilai);
      }

      int countTuntas = 0;
      int countRemedial = 0;
      double totalScore = 0.0;
      int scoredStudents = studentGrades.length;

      for (final grades in studentGrades.values) {
        final avgPerJenis = <String, double>{};
        for (final entry in grades.entries) {
          avgPerJenis[entry.key] = entry.value.reduce((a, b) => a + b) / entry.value.length;
        }

        final res = KalkulatorK13.hitungNilaiAkhir(
          rataRataPerJenis: avgPerJenis,
          bobotPerJenis: bobotMap,
          kkm: kkm,
        );

        totalScore += res.nilaiAkhir;
        if (res.tuntas) {
          countTuntas++;
        } else {
          countRemedial++;
        }
      }

      final double persentase = scoredStudents > 0
          ? double.parse(((countTuntas / scoredStudents) * 100.0).toStringAsFixed(1))
          : 0.0;
      final double avgScore = scoredStudents > 0
          ? double.parse((totalScore / scoredStudents).toStringAsFixed(2))
          : 0.0;

      result.add(
        MapelKetuntasanSummary(
          mapelId: mapel.id,
          mapelNama: mapel.nama,
          mapelKode: mapel.kode,
          kkm: kkm,
          totalSiswa: scoredStudents,
          jumlahTuntas: countTuntas,
          jumlahRemedial: countRemedial,
          persentaseKetuntasan: persentase,
          rataRataMapel: avgScore,
        ),
      );
    }

    return result;
  }
}
