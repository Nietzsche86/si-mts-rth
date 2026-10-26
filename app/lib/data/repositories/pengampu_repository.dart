import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

enum ModePembagianKelompok { ganjilGenap, rata }

enum JenisAnomaliPengampu {
  mapelTanpaUtama,
  siswaFallback,
  siswaTumpangTindih,
  guruNonaktif,
}

class AnomaliPengampu {
  final JenisAnomaliPengampu jenis;
  final String judul;
  final String deskripsi;
  final String tingkatKeparahan; // 'kritis' | 'peringatan'
  final String? rombelId;
  final String? rombelNama;
  final String? mapelId;
  final String? mapelNama;
  final String? guruId;
  final String? guruNama;
  final int? jumlahSiswa;
  final List<String> daftarSiswa;
  final List<String> pengampuIds;

  const AnomaliPengampu({
    required this.jenis,
    required this.judul,
    required this.deskripsi,
    required this.tingkatKeparahan,
    this.rombelId,
    this.rombelNama,
    this.mapelId,
    this.mapelNama,
    this.guruId,
    this.guruNama,
    this.jumlahSiswa,
    this.daftarSiswa = const [],
    this.pengampuIds = const [],
  });
}

class PengampuSummaryItem {
  final String pengampuId;
  final String rombelId;
  final String rombelNama;
  final String mapelId;
  final String mapelNama;
  final String peran; // 'utama' | 'pendamping'
  final bool isUtama;
  final String cakupan; // 'seluruh' | 'sebagian'
  final int totalSiswa;
  final int belumDikelompokkanCount;
  final String cakupanText;
  final String progressText;
  final double progressValue;

  const PengampuSummaryItem({
    required this.pengampuId,
    required this.rombelId,
    required this.rombelNama,
    required this.mapelId,
    required this.mapelNama,
    required this.peran,
    required this.isUtama,
    required this.cakupan,
    required this.totalSiswa,
    this.belumDikelompokkanCount = 0,
    required this.cakupanText,
    required this.progressText,
    required this.progressValue,
  });
}

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

      // Hapus alokasi lama untuk kelompok pengampu ini
      await (db.delete(db.pengampuSiswa)..where((t) => t.pengampuId.isIn(pengampuIds))).go();

      for (int i = 0; i < keanggotaanList.length; i++) {
        final k = keanggotaanList[i];
        final String targetPengampuId;

        if (mode == ModePembagianKelompok.ganjilGenap) {
          final groupIndex = i % pengampuIds.length;
          targetPengampuId = pengampuIds[groupIndex];
        } else {
          // Mode Rata
          final chunkSize = (keanggotaanList.length / pengampuIds.length).ceil();
          final groupIndex = (i ~/ (chunkSize > 0 ? chunkSize : 1)).clamp(0, pengampuIds.length - 1);
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

  /// Menyimpan pemetaan kelompok siswa manual atau kustom
  Future<void> simpanPembagianKelompok({
    required String rombelId,
    required String mapelId,
    required String semesterId,
    required Map<String, List<String>> pengampuToKeanggotaanMap,
    required String deviceId,
  }) async {
    final allPengampus = await (db.select(db.pengampu)
          ..where((t) =>
              t.rombelId.equals(rombelId) &
              t.mapelId.equals(mapelId) &
              t.semesterId.equals(semesterId) &
              t.tanggalSelesai.isNull() &
              t.deleted.equals(0)))
        .get();
    final pengampuIds = allPengampus.map((p) => p.id).toList();

    await db.transaction(() async {
      final now = DateTime.now();
      final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

      // Hapus alokasi lama
      await (db.delete(db.pengampuSiswa)..where((t) => t.pengampuId.isIn(pengampuIds))).go();

      // Masukkan pemetaan baru
      for (final entry in pengampuToKeanggotaanMap.entries) {
        final targetPengampuId = entry.key;
        for (final kId in entry.value) {
          final psId = _uuid.v4();
          final item = PengampuSiswaCompanion.insert(
            id: psId,
            pengampuId: targetPengampuId,
            keanggotaanId: kId,
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          );
          await db.into(db.pengampuSiswa).insert(item);
          await outbox.enqueue(tabel: 'pengampu_siswa', recordId: psId, operasi: 'INSERT');
        }
      }
    });
  }

  /// Mendeteksi 4 Anomali Penugasan Pengampu Sesuai PRD F9 (106–111)
  /// 1. Mapel di rombel aktif tanpa Guru Utama
  /// 2. Siswa aktif belum terpetakan di mapel sebagian (fallback Guru Utama)
  /// 3. Siswa terdaftar ganda di >1 guru pada mapel sebagian (tumpang tindih)
  /// 4. Guru nonaktif yang masih ditugaskan di pengampu aktif
  Future<List<AnomaliPengampu>> deteksiAnomaliPengampu({required String semesterId}) async {
    final sem = await (db.select(db.semester)..where((t) => t.id.equals(semesterId))).getSingleOrNull();
    if (sem == null) return [];

    final rombels = await (db.select(db.rombel)
          ..where((t) => t.tahunAjaranId.equals(sem.tahunAjaranId) & t.deleted.equals(0)))
        .get();
    final mapels = await (db.select(db.mapel)
          ..where((t) => t.aktif.equals(1) & t.deleted.equals(0)))
        .get();
    final pengampus = await (db.select(db.pengampu)
          ..where((t) =>
              t.semesterId.equals(semesterId) &
              t.tanggalSelesai.isNull() &
              t.deleted.equals(0)))
        .get();
    final gurus = await (db.select(db.guru)..where((t) => t.deleted.equals(0))).get();

    final guruMap = {for (final g in gurus) g.id: g};
    final rombelMap = {for (final r in rombels) r.id: r};
    final mapelMap = {for (final m in mapels) m.id: m};

    final anomalies = <AnomaliPengampu>[];

    // Anomali 1: Mapel di rombel aktif yang belum punya pengampu utama
    for (final r in rombels) {
      for (final m in mapels) {
        final pUtama = pengampus.where(
          (p) => p.rombelId == r.id && p.mapelId == m.id && p.peran == 'utama',
        );
        if (pUtama.isEmpty) {
          anomalies.add(
            AnomaliPengampu(
              jenis: JenisAnomaliPengampu.mapelTanpaUtama,
              judul: 'Mapel ${m.nama} di ${r.nama} Belum Memiliki Guru Utama',
              deskripsi: 'Setiap mata pelajaran wajib memiliki tepat satu Guru Utama aktif untuk menjamin tanggung jawab penilaian.',
              tingkatKeparahan: 'kritis',
              rombelId: r.id,
              rombelNama: r.nama,
              mapelId: m.id,
              mapelNama: m.nama,
            ),
          );
        }
      }
    }

    // Anomali 4: Guru nonaktif yang masih tercatat di pengampu aktif
    for (final p in pengampus) {
      final guru = guruMap[p.guruId];
      if (guru != null && guru.aktif == 0) {
        final rNama = rombelMap[p.rombelId]?.nama ?? p.rombelId;
        final mNama = mapelMap[p.mapelId]?.nama ?? p.mapelId;
        anomalies.add(
          AnomaliPengampu(
            jenis: JenisAnomaliPengampu.guruNonaktif,
            judul: 'Guru Nonaktif Ditugaskan: ${guru.namaLengkap}',
            deskripsi: 'Guru berstatus nonaktif masih tercatat mengajar mapel $mNama di rombel $rNama.',
            tingkatKeparahan: 'kritis',
            rombelId: p.rombelId,
            rombelNama: rNama,
            mapelId: p.mapelId,
            mapelNama: mNama,
            guruId: guru.id,
            guruNama: guru.namaLengkap,
            pengampuIds: [p.id],
          ),
        );
      }
    }

    // Anomali 2 & 3: Kelompok Siswa (Fallback & Tumpang Tindih)
    // Kelompokkan pengampu berdasarkan (rombelId, mapelId)
    final groupedPengampu = <String, List<PengampuData>>{};
    for (final p in pengampus) {
      final key = '${p.rombelId}_${p.mapelId}';
      groupedPengampu.putIfAbsent(key, () => []).add(p);
    }

    for (final entry in groupedPengampu.entries) {
      final group = entry.value;
      final hasSebagian = group.any((p) => p.cakupan == 'sebagian');
      if (!hasSebagian) continue;

      final rombelId = group.first.rombelId;
      final mapelId = group.first.mapelId;
      final rNama = rombelMap[rombelId]?.nama ?? rombelId;
      final mNama = mapelMap[mapelId]?.nama ?? mapelId;
      final groupPengampuIds = group.map((p) => p.id).toList();

      final keanggotaanAktif = await (db.select(db.keanggotaanRombel)
            ..where((t) =>
                t.rombelId.equals(rombelId) &
                t.tanggalKeluar.isNull() &
                t.deleted.equals(0)))
          .get();

      final psRows = await (db.select(db.pengampuSiswa)
            ..where((t) => t.pengampuId.isIn(groupPengampuIds) & t.deleted.equals(0)))
          .get();

      final keanggotaanToTeachers = <String, List<String>>{};
      for (final ps in psRows) {
        keanggotaanToTeachers.putIfAbsent(ps.keanggotaanId, () => []).add(ps.pengampuId);
      }

      // Anomali 2: Siswa Fallback (belum masuk pengampu_siswa)
      final unassigned = keanggotaanAktif.where((k) => !keanggotaanToTeachers.containsKey(k.id)).toList();
      if (unassigned.isNotEmpty) {
        anomalies.add(
          AnomaliPengampu(
            jenis: JenisAnomaliPengampu.siswaFallback,
            judul: '${unassigned.length} Siswa di $rNama ($mNama) Belum Memiliki Kelompok',
            deskripsi: 'Siswa belum terdaftar pada kelompok guru mana pun dan sementara dialihkan ke Guru Utama.',
            tingkatKeparahan: 'peringatan',
            rombelId: rombelId,
            rombelNama: rNama,
            mapelId: mapelId,
            mapelNama: mNama,
            jumlahSiswa: unassigned.length,
            pengampuIds: groupPengampuIds,
          ),
        );
      }

      // Anomali 3: Siswa Tumpang Tindih (terdaftar di >1 guru untuk mapel yang sama)
      final overlapping = keanggotaanToTeachers.entries.where((e) => e.value.length > 1).toList();
      if (overlapping.isNotEmpty) {
        anomalies.add(
          AnomaliPengampu(
            jenis: JenisAnomaliPengampu.siswaTumpangTindih,
            judul: 'Tumpang Tindih: ${overlapping.length} Siswa Terdaftar di >1 Guru',
            deskripsi: 'Terdapat siswa yang didaftarkan ke lebih dari satu kelompok guru untuk mapel $mNama di rombel $rNama.',
            tingkatKeparahan: 'peringatan',
            rombelId: rombelId,
            rombelNama: rNama,
            mapelId: mapelId,
            mapelNama: mNama,
            jumlahSiswa: overlapping.length,
            pengampuIds: groupPengampuIds,
          ),
        );
      }
    }

    return anomalies;
  }

  /// Mengambil daftar pengampu aktif untuk seorang guru pada semester aktif beserta ringkasan progres
  Future<List<PengampuSummaryItem>> getPengampuSummaryForGuru({
    required String guruId,
    required String semesterId,
  }) async {
    // 1. Ambil semua pengampu aktif untuk guru
    final query = db.select(db.pengampu).join([
      innerJoin(db.rombel, db.rombel.id.equalsExp(db.pengampu.rombelId)),
      innerJoin(db.mapel, db.mapel.id.equalsExp(db.pengampu.mapelId)),
    ])
      ..where(
        db.pengampu.guruId.equals(guruId) &
            db.pengampu.semesterId.equals(semesterId) &
            db.pengampu.tanggalSelesai.isNull() &
            db.pengampu.deleted.equals(0) &
            db.rombel.deleted.equals(0) &
            db.mapel.deleted.equals(0),
      )
      ..orderBy([OrderingTerm.asc(db.rombel.nama), OrderingTerm.asc(db.mapel.nama)]);

    final rows = await query.get();
    final result = <PengampuSummaryItem>[];

    for (final r in rows) {
      final p = r.readTable(db.pengampu);
      final rombel = r.readTable(db.rombel);
      final mapel = r.readTable(db.mapel);

      final isUtama = p.peran == 'utama';
      final siswaList = await getSiswaForPengampu(
        pengampuId: p.id,
        rombelId: p.rombelId,
        semesterId: semesterId,
      );
      final totalSiswa = siswaList.length;

      // Hitung unassigned fallback count jika Guru Utama & cakupan sebagian
      int belumDikelompokkanCount = 0;
      if (isUtama && p.cakupan == 'sebagian') {
        final allKeanggotaan = await (db.select(db.keanggotaanRombel)
              ..where((t) =>
                  t.rombelId.equals(p.rombelId) &
                  t.tanggalKeluar.isNull() &
                  t.deleted.equals(0)))
            .get();

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

        final groupedKeanggotaan = (await (db.select(db.pengampuSiswa)
                  ..where((t) => t.pengampuId.isIn(allPengampuIds) & t.deleted.equals(0)))
                .get())
            .map((ps) => ps.keanggotaanId)
            .toSet();

        belumDikelompokkanCount = allKeanggotaan.where((k) => !groupedKeanggotaan.contains(k.id)).length;
      }

      // Cakupan text
      String cakupanText;
      if (p.cakupan == 'seluruh') {
        cakupanText = 'Seluruh kelas • $totalSiswa Siswa';
      } else {
        if (isUtama && belumDikelompokkanCount > 0) {
          final kelompokSaya = totalSiswa - belumDikelompokkanCount;
          cakupanText = 'Kelompok Saya • $kelompokSaya Siswa (+$belumDikelompokkanCount belum dikelompokkan)';
        } else {
          cakupanText = 'Kelompok Khusus • $totalSiswa Siswa';
        }
      }

      // Progress entri nilai
      final siswaIds = siswaList.map((s) => s.id).toSet();
      int terisiCount = 0;

      if (siswaIds.isNotEmpty) {
        final keanggotaanAktif = await (db.select(db.keanggotaanRombel)
              ..where((t) =>
                  t.rombelId.equals(p.rombelId) &
                  t.siswaId.isIn(siswaIds) &
                  t.tanggalKeluar.isNull() &
                  t.deleted.equals(0)))
            .get();
        final keanggotaanIds = keanggotaanAktif.map((k) => k.id).toList();

        if (keanggotaanIds.isNotEmpty) {
          final nilaiRows = await (db.select(db.nilai)
                ..where((t) =>
                    t.mapelId.equals(p.mapelId) &
                    t.semesterId.equals(semesterId) &
                    t.keanggotaanId.isIn(keanggotaanIds) &
                    t.deleted.equals(0)))
              .get();
          final siswaDenganNilai = nilaiRows.map((n) => n.keanggotaanId).toSet();
          terisiCount = siswaDenganNilai.length;
        }
      }

      final progressVal = totalSiswa > 0 ? (terisiCount / totalSiswa).clamp(0.0, 1.0) : 0.0;
      final progressPercent = (progressVal * 100).toInt();
      final progressText = totalSiswa > 0
          ? 'Nilai terisi $terisiCount/$totalSiswa siswa — $progressPercent%'
          : 'Belum ada siswa';

      result.add(
        PengampuSummaryItem(
          pengampuId: p.id,
          rombelId: rombel.id,
          rombelNama: rombel.nama,
          mapelId: mapel.id,
          mapelNama: mapel.nama,
          peran: p.peran,
          isUtama: isUtama,
          cakupan: p.cakupan,
          totalSiswa: totalSiswa,
          belumDikelompokkanCount: belumDikelompokkanCount,
          cakupanText: cakupanText,
          progressText: progressText,
          progressValue: progressVal,
        ),
      );
    }

    return result;
  }
}
