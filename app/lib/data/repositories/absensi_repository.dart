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

/// Model akumulasi absensi per siswa dalam rentang periode tertentu
class RekapAbsensiSiswaItem {
  final String keanggotaanId;
  final String siswaId;
  final String namaLengkap;
  final String nis;
  final String jenisKelamin;
  final int hadir;
  final int sakit;
  final int izin;
  final int alpa;
  final int totalPertemuan;
  final double persentaseKehadiran;
  final bool perluPerhatian; // Indikasi jika alpa >= 3 hari

  const RekapAbsensiSiswaItem({
    required this.keanggotaanId,
    required this.siswaId,
    required this.namaLengkap,
    required this.nis,
    required this.jenisKelamin,
    required this.hadir,
    required this.sakit,
    required this.izin,
    required this.alpa,
    required this.totalPertemuan,
    required this.persentaseKehadiran,
    required this.perluPerhatian,
  });
}

/// Model hasil rekapitulasi absensi rombel dalam periode tertentu
class RekapAbsensiRombelResult {
  final String rombelId;
  final String rombelNama;
  final String semesterId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<RekapAbsensiSiswaItem> siswaItems;
  final int totalHadir;
  final int totalSakit;
  final int totalIzin;
  final int totalAlpa;
  final double persentaseKehadiranRombel;

  const RekapAbsensiRombelResult({
    required this.rombelId,
    required this.rombelNama,
    required this.semesterId,
    this.startDate,
    this.endDate,
    required this.siswaItems,
    required this.totalHadir,
    required this.totalSakit,
    required this.totalIzin,
    required this.totalAlpa,
    required this.persentaseKehadiranRombel,
  });
}

/// Model ringkasan kehadiran per rombel untuk Dashboard Eksekutif
class StatistikKehadiranRombelItem {
  final String rombelId;
  final String rombelNama;
  final String tingkat;
  final int totalSiswa;
  final int hadir;
  final int sakit;
  final int izin;
  final int alpa;
  final double persentaseKehadiran;

  const StatistikKehadiranRombelItem({
    required this.rombelId,
    required this.rombelNama,
    required this.tingkat,
    required this.totalSiswa,
    required this.hadir,
    required this.sakit,
    required this.izin,
    required this.alpa,
    required this.persentaseKehadiran,
  });
}

/// Model statistik kehadiran tingkat madrasah (Dashboard Kepala Madrasah)
class StatistikKehadiranMadrasah {
  final double persentaseKehadiranTotal;
  final int totalHadir;
  final int totalSakit;
  final int totalIzin;
  final int totalAlpa;
  final Map<String, double> perTingkat;
  final List<StatistikKehadiranRombelItem> perRombel;

  const StatistikKehadiranMadrasah({
    required this.persentaseKehadiranTotal,
    required this.totalHadir,
    required this.totalSakit,
    required this.totalIzin,
    required this.totalAlpa,
    required this.perTingkat,
    required this.perRombel,
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

  /// Mengambil rekap akumulatif absensi (H, S, I, A) rombel dalam rentang periode tertentu
  Future<RekapAbsensiRombelResult> getRekapAbsensiPeriodik({
    required String rombelId,
    required String semesterId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final rombel = await (db.select(db.rombel)..where((t) => t.id.equals(rombelId))).getSingle();

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

    // Query absensi
    final absensiQuery = db.select(db.absensi)
      ..where((t) =>
          t.semesterId.equals(semesterId) &
          t.keanggotaanId.isIn(keanggotaanIds) &
          t.deleted.equals(0));

    if (startDate != null) {
      final startStr = startDate.toIso8601String().substring(0, 10);
      absensiQuery.where((t) => t.tanggal.isBiggerOrEqualValue(startStr));
    }
    if (endDate != null) {
      final endStr = endDate.toIso8601String().substring(0, 10);
      absensiQuery.where((t) => t.tanggal.isSmallerOrEqualValue(endStr));
    }

    final absensiRows = keanggotaanIds.isEmpty ? <AbsensiData>[] : await absensiQuery.get();

    // Petakan per keanggotaanId
    final absensiMap = <String, List<String>>{};
    for (final a in absensiRows) {
      absensiMap.putIfAbsent(a.keanggotaanId, () => []).add(a.status);
    }

    int totalRombelH = 0;
    int totalRombelS = 0;
    int totalRombelI = 0;
    int totalRombelA = 0;

    final siswaItems = <RekapAbsensiSiswaItem>[];

    for (final r in rows) {
      final k = r.readTable(db.keanggotaanRombel);
      final s = r.readTable(db.siswa);

      final statusList = absensiMap[k.id] ?? [];
      int h = 0, sc = 0, iz = 0, a = 0;

      for (final st in statusList) {
        if (st == 'H') {
          h++;
        } else if (st == 'S') {
          sc++;
        } else if (st == 'I') {
          iz++;
        } else if (st == 'A') {
          a++;
        }
      }

      totalRombelH += h;
      totalRombelS += sc;
      totalRombelI += iz;
      totalRombelA += a;

      final totalPertemuan = h + sc + iz + a;
      final persentase = totalPertemuan > 0
          ? double.parse(((h / totalPertemuan) * 100.0).toStringAsFixed(1))
          : 0.0;

      siswaItems.add(
        RekapAbsensiSiswaItem(
          keanggotaanId: k.id,
          siswaId: s.id,
          namaLengkap: s.namaLengkap,
          nis: s.nis,
          jenisKelamin: s.jk,
          hadir: h,
          sakit: sc,
          izin: iz,
          alpa: a,
          totalPertemuan: totalPertemuan,
          persentaseKehadiran: persentase,
          perluPerhatian: a >= 3,
        ),
      );
    }

    final totalRombelPertemuan = totalRombelH + totalRombelS + totalRombelI + totalRombelA;
    final persentaseRombel = totalRombelPertemuan > 0
        ? double.parse(((totalRombelH / totalRombelPertemuan) * 100.0).toStringAsFixed(1))
        : 0.0;

    return RekapAbsensiRombelResult(
      rombelId: rombel.id,
      rombelNama: rombel.nama,
      semesterId: semesterId,
      startDate: startDate,
      endDate: endDate,
      siswaItems: siswaItems,
      totalHadir: totalRombelH,
      totalSakit: totalRombelS,
      totalIzin: totalRombelI,
      totalAlpa: totalRombelA,
      persentaseKehadiranRombel: persentaseRombel,
    );
  }

  /// Mengambil statistik kehadiran tingkat madrasah (Dashboard Kepala Madrasah)
  Future<StatistikKehadiranMadrasah> getStatistikKehadiranMadrasah({
    required String semesterId,
  }) async {
    final rombels = await (db.select(db.rombel)
          ..where((t) => t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.tingkat), (t) => OrderingTerm.asc(t.nama)]))
        .get();

    int totalMadrasahH = 0;
    int totalMadrasahS = 0;
    int totalMadrasahI = 0;
    int totalMadrasahA = 0;

    final rombelItems = <StatistikKehadiranRombelItem>[];
    final tingkatHadirMap = <String, int>{};
    final tingkatTotalMap = <String, int>{};

    for (final r in rombels) {
      final activeKeanggotaan = await (db.select(db.keanggotaanRombel)
            ..where((t) =>
                t.rombelId.equals(r.id) &
                t.tanggalKeluar.isNull() &
                t.deleted.equals(0)))
          .get();
      final keanggotaanIds = activeKeanggotaan.map((k) => k.id).toList();

      int rombelH = 0, rombelS = 0, rombelI = 0, rombelA = 0;

      if (keanggotaanIds.isNotEmpty) {
        final absensiRows = await (db.select(db.absensi)
              ..where((t) =>
                  t.semesterId.equals(semesterId) &
                  t.keanggotaanId.isIn(keanggotaanIds) &
                  t.deleted.equals(0)))
            .get();

        for (final a in absensiRows) {
          if (a.status == 'H') {
            rombelH++;
          } else if (a.status == 'S') {
            rombelS++;
          } else if (a.status == 'I') {
            rombelI++;
          } else if (a.status == 'A') {
            rombelA++;
          }
        }
      }

      totalMadrasahH += rombelH;
      totalMadrasahS += rombelS;
      totalMadrasahI += rombelI;
      totalMadrasahA += rombelA;

      final totalRombel = rombelH + rombelS + rombelI + rombelA;
      final persentase = totalRombel > 0
          ? double.parse(((rombelH / totalRombel) * 100.0).toStringAsFixed(1))
          : 0.0;

      rombelItems.add(
        StatistikKehadiranRombelItem(
          rombelId: r.id,
          rombelNama: r.nama,
          tingkat: r.tingkat,
          totalSiswa: activeKeanggotaan.length,
          hadir: rombelH,
          sakit: rombelS,
          izin: rombelI,
          alpa: rombelA,
          persentaseKehadiran: persentase,
        ),
      );

      tingkatHadirMap[r.tingkat] = (tingkatHadirMap[r.tingkat] ?? 0) + rombelH;
      tingkatTotalMap[r.tingkat] = (tingkatTotalMap[r.tingkat] ?? 0) + totalRombel;
    }

    final totalSemua = totalMadrasahH + totalMadrasahS + totalMadrasahI + totalMadrasahA;
    final persentaseTotal = totalSemua > 0
        ? double.parse(((totalMadrasahH / totalSemua) * 100.0).toStringAsFixed(1))
        : 0.0;

    final perTingkat = <String, double>{};
    for (final entry in tingkatTotalMap.entries) {
      final t = entry.key;
      final total = entry.value;
      final hadir = tingkatHadirMap[t] ?? 0;
      perTingkat[t] = total > 0
          ? double.parse(((hadir / total) * 100.0).toStringAsFixed(1))
          : 0.0;
    }

    return StatistikKehadiranMadrasah(
      persentaseKehadiranTotal: persentaseTotal,
      totalHadir: totalMadrasahH,
      totalSakit: totalMadrasahS,
      totalIzin: totalMadrasahI,
      totalAlpa: totalMadrasahA,
      perTingkat: perTingkat,
      perRombel: rombelItems,
    );
  }
}
