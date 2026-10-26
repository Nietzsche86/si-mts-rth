import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

class NaikKelasItemInput {
  final String siswaId;
  final String status; // 'naik_kelas' | 'tinggal_kelas' | 'lulus'
  final String? rombelTujuanId;
  final String? catatan;

  const NaikKelasItemInput({
    required this.siswaId,
    required this.status,
    this.rombelTujuanId,
    this.catatan,
  });
}

class RombelRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  RombelRepository(this.db, this.outbox);

  /// Mengambil semua rombel aktif dalam tahun ajaran tertentu
  Future<List<RombelData>> getRombelByTahunAjaran(String tahunAjaranId) async {
    return (db.select(db.rombel)
          ..where((t) => t.tahunAjaranId.equals(tahunAjaranId) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm.asc(t.tingkat), (t) => OrderingTerm.asc(t.nama)]))
        .get();
  }

  /// Mengambil daftar siswa aktif di suatu rombel
  Future<List<SiswaData>> getSiswaInRombel(String rombelId) async {
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

  /// Pindah Rombel Transaksional dengan opsi "Bawa Nilai"
  /// Sesuai PRD F7 & F8:
  /// - Tutup keanggotaan rombel lama (tanggal_keluar = now).
  /// - Buka keanggotaan di rombel tujuan (sumber_keanggotaan_id merujuk ID lama).
  /// - Jika bawaNilai = true: duplikasi nilai dengan sumber_nilai_id terhubung.
  /// - Catat riwayat_status_siswa & antrekan outbox.
  Future<String> pindahRombel({
    required String siswaId,
    required String rombelLamaId,
    required String rombelBaruId,
    required String semesterId,
    required bool bawaNilai,
    required String guruId,
    required String deviceId,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now();
      final nowStr = now.toIso8601String().substring(0, 10);
      final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

      // 1. Cari keanggotaan lama yang aktif
      final keanggotaanLama = await (db.select(db.keanggotaanRombel)
            ..where((t) =>
                t.siswaId.equals(siswaId) &
                t.rombelId.equals(rombelLamaId) &
                t.tanggalKeluar.isNull() &
                t.deleted.equals(0)))
          .getSingleOrNull();

      if (keanggotaanLama == null) {
        throw StateError('Keanggotaan aktif siswa di rombel lama tidak ditemukan');
      }

      // 2. Tutup keanggotaan lama
      await (db.update(db.keanggotaanRombel)..where((t) => t.id.equals(keanggotaanLama.id))).write(
        KeanggotaanRombelCompanion(
          tanggalKeluar: Value(nowStr),
          updatedAt: Value(nowEpoch),
          deviceId: Value(deviceId),
        ),
      );
      await outbox.enqueue(tabel: 'keanggotaan_rombel', recordId: keanggotaanLama.id, operasi: 'UPDATE');

      // 3. Buat keanggotaan baru
      final newKeanggotaanId = _uuid.v4();
      final keanggotaanBaru = KeanggotaanRombelCompanion.insert(
        id: newKeanggotaanId,
        siswaId: siswaId,
        rombelId: rombelBaruId,
        tanggalMasuk: nowStr,
        sumberKeanggotaanId: Value(keanggotaanLama.id),
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.keanggotaanRombel).insert(keanggotaanBaru);
      await outbox.enqueue(tabel: 'keanggotaan_rombel', recordId: newKeanggotaanId, operasi: 'INSERT');

      // 4. Jika "Bawa Nilai" aktif, salin nilai lama ke rombel baru dengan sumber_nilai_id
      if (bawaNilai) {
        final daftarNilaiLama = await (db.select(db.nilai)
              ..where((t) => t.keanggotaanId.equals(keanggotaanLama.id) & t.deleted.equals(0)))
            .get();

        for (final nl in daftarNilaiLama) {
          final newNilaiId = _uuid.v4();
          final nilaiBaru = NilaiCompanion.insert(
            id: newNilaiId,
            keanggotaanId: newKeanggotaanId,
            mapelId: nl.mapelId,
            semesterId: nl.semesterId,
            jenisNilaiId: nl.jenisNilaiId,
            urutanKe: Value(nl.urutanKe),
            nilai: nl.nilai,
            tanggal: nl.tanggal,
            keterangan: Value(nl.keterangan),
            sumberNilaiId: Value(nl.id), // Terhubung ke sumber nilai asli
            diinputOlehGuruId: guruId,
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          );
          await db.into(db.nilai).insert(nilaiBaru);
          await outbox.enqueue(tabel: 'nilai', recordId: newNilaiId, operasi: 'INSERT');
        }
      }

      // 5. Catat riwayat_status_siswa
      final riwayatId = _uuid.v4();
      final riwayat = RiwayatStatusSiswaCompanion.insert(
        id: riwayatId,
        siswaId: siswaId,
        tanggal: nowStr,
        jenisStatus: 'MUTASI_ROMBEL',
        rombelAsalId: Value(rombelLamaId),
        rombelTujuanId: Value(rombelBaruId),
        catatan: Value('Pindah rombel dari $rombelLamaId ke $rombelBaruId (Bawa nilai: $bawaNilai)'),
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.riwayatStatusSiswa).insert(riwayat);
      await outbox.enqueue(tabel: 'riwayat_status_siswa', recordId: riwayatId, operasi: 'INSERT');

      return newKeanggotaanId;
    });
  }

  /// Mutasi Massal Naik Kelas / Tinggal Kelas / Kelulusan (PRD F7)
  /// - Menutup keanggotaan rombel lama untuk setiap siswa
  /// - Membuka keanggotaan rombel baru bagi yang naik/tinggal kelas
  /// - Mencatat riwayat perubahan status di tabel riwayat_status_siswa
  /// - Mendaftarkan semua mutasi ke tabel antrean outbox secara atomik
  Future<int> naikKelasMassal({
    required String rombelAsalId,
    required List<NaikKelasItemInput> items,
    required String tanggal,
    required String deviceId,
    String? catatanGlobal,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now();
      final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);
      int processedCount = 0;

      for (final item in items) {
        // 1. Cari keanggotaan aktif siswa di rombel asal
        final keanggotaanLama = await (db.select(db.keanggotaanRombel)
              ..where((t) =>
                  t.siswaId.equals(item.siswaId) &
                  t.rombelId.equals(rombelAsalId) &
                  t.tanggalKeluar.isNull() &
                  t.deleted.equals(0)))
            .getSingleOrNull();

        if (keanggotaanLama == null) continue;

        // 2. Tutup keanggotaan lama
        await (db.update(db.keanggotaanRombel)..where((t) => t.id.equals(keanggotaanLama.id))).write(
          KeanggotaanRombelCompanion(
            tanggalKeluar: Value(tanggal),
            alasanKeluar: Value(item.status),
            updatedAt: Value(nowEpoch),
            deviceId: Value(deviceId),
          ),
        );
        await outbox.enqueue(tabel: 'keanggotaan_rombel', recordId: keanggotaanLama.id, operasi: 'UPDATE');

        // 3. Jika naik kelas atau tinggal kelas dengan rombel tujuan, buat keanggotaan baru
        if ((item.status == 'naik_kelas' || item.status == 'tinggal_kelas') && item.rombelTujuanId != null) {
          final newKeanggotaanId = _uuid.v4();
          final keanggotaanBaru = KeanggotaanRombelCompanion.insert(
            id: newKeanggotaanId,
            siswaId: item.siswaId,
            rombelId: item.rombelTujuanId!,
            tanggalMasuk: tanggal,
            sumberKeanggotaanId: Value(keanggotaanLama.id),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          );
          await db.into(db.keanggotaanRombel).insert(keanggotaanBaru);
          await outbox.enqueue(tabel: 'keanggotaan_rombel', recordId: newKeanggotaanId, operasi: 'INSERT');
        }

        // 4. Catat riwayat status siswa
        final riwayatId = _uuid.v4();
        final riwayat = RiwayatStatusSiswaCompanion.insert(
          id: riwayatId,
          siswaId: item.siswaId,
          tanggal: tanggal,
          jenisStatus: item.status,
          rombelAsalId: Value(rombelAsalId),
          rombelTujuanId: Value(item.rombelTujuanId),
          catatan: Value(item.catatan ?? catatanGlobal ?? 'Mutasi massal (${item.status})'),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        );
        await db.into(db.riwayatStatusSiswa).insert(riwayat);
        await outbox.enqueue(tabel: 'riwayat_status_siswa', recordId: riwayatId, operasi: 'INSERT');

        processedCount++;
      }

      return processedCount;
    });
  }

  /// Pergantian Tahun Ajaran Baru & Semester (PRD F8)
  /// - Nonaktifkan tahun ajaran lama dan kunci semester lama
  /// - Buat tahun ajaran baru & semester baru
  /// - Salin rombel & pengampu ke SQLite lokal + outbox secara atomik
  Future<Map<String, dynamic>> pergantianTahun({
    required String tahunAjaranLamaId,
    required String namaTahunBaru,
    required String jenisSemesterBaru, // 'ganjil' | 'genap'
    required String tanggalMulai,
    required String tanggalSelesai,
    required bool salinRombel,
    required bool salinPengampu,
    required bool kunciSemesterLama,
    required String deviceId,
  }) async {
    return db.transaction(() async {
      final now = DateTime.now();
      final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

      // 1. Nonaktifkan tahun ajaran lama
      await (db.update(db.tahunAjaran)..where((t) => t.id.equals(tahunAjaranLamaId))).write(
        TahunAjaranCompanion(
          aktif: const Value(0),
          updatedAt: Value(nowEpoch),
          deviceId: Value(deviceId),
        ),
      );
      await outbox.enqueue(tabel: 'tahun_ajaran', recordId: tahunAjaranLamaId, operasi: 'UPDATE');

      // 2. Kunci semester lama jika diminta
      final semestersLama = await (db.select(db.semester)
            ..where((t) => t.tahunAjaranId.equals(tahunAjaranLamaId) & t.deleted.equals(0)))
          .get();

      if (kunciSemesterLama) {
        for (final sem in semestersLama) {
          await (db.update(db.semester)..where((t) => t.id.equals(sem.id))).write(
            SemesterCompanion(
              dikunci: const Value(1),
              updatedAt: Value(nowEpoch),
              deviceId: Value(deviceId),
            ),
          );
          await outbox.enqueue(tabel: 'semester', recordId: sem.id, operasi: 'UPDATE');
        }
      }

      // 3. Buat Tahun Ajaran baru
      final newTahunId = _uuid.v4();
      final newTahun = TahunAjaranCompanion.insert(
        id: newTahunId,
        nama: namaTahunBaru,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        aktif: const Value(1),
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.tahunAjaran).insert(newTahun);
      await outbox.enqueue(tabel: 'tahun_ajaran', recordId: newTahunId, operasi: 'INSERT');

      // 4. Buat Semester baru
      final newSemId = _uuid.v4();
      final newSem = SemesterCompanion.insert(
        id: newSemId,
        tahunAjaranId: newTahunId,
        jenis: jenisSemesterBaru,
        tanggalMulai: tanggalMulai,
        tanggalSelesai: tanggalSelesai,
        dikunci: const Value(0),
        deviceId: deviceId,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
      );
      await db.into(db.semester).insert(newSem);
      await outbox.enqueue(tabel: 'semester', recordId: newSemId, operasi: 'INSERT');

      // Perbarui semester_aktif_id di tabel madrasah
      final madrasah = await (db.select(db.madrasah)..limit(1)).getSingleOrNull();
      if (madrasah != null) {
        await (db.update(db.madrasah)..where((t) => t.id.equals(madrasah.id))).write(
          MadrasahCompanion(
            semesterAktifId: Value(newSemId),
            updatedAt: Value(nowEpoch),
            deviceId: Value(deviceId),
          ),
        );
        await outbox.enqueue(tabel: 'madrasah', recordId: madrasah.id, operasi: 'UPDATE');
      }

      // 5. Salin rombel
      final rombelMap = <String, String>{};
      int rombelCopied = 0;
      if (salinRombel) {
        final oldRombels = await (db.select(db.rombel)
              ..where((t) => t.tahunAjaranId.equals(tahunAjaranLamaId) & t.deleted.equals(0)))
            .get();

        for (final r in oldRombels) {
          final newRId = _uuid.v4();
          final newRombel = RombelCompanion.insert(
            id: newRId,
            tahunAjaranId: newTahunId,
            nama: r.nama,
            tingkat: r.tingkat,
            waliGuruId: Value(r.waliGuruId),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          );
          await db.into(db.rombel).insert(newRombel);
          await outbox.enqueue(tabel: 'rombel', recordId: newRId, operasi: 'INSERT');
          rombelMap[r.id] = newRId;
          rombelCopied++;
        }
      }

      // 6. Salin pengampu
      int pengampuCopied = 0;
      if (salinPengampu) {
        final oldSemIds = semestersLama.map((s) => s.id).toList();
        if (oldSemIds.isNotEmpty) {
          final oldPengampus = await (db.select(db.pengampu)
                ..where((t) =>
                    t.semesterId.isIn(oldSemIds) &
                    t.tanggalSelesai.isNull() &
                    t.deleted.equals(0)))
              .get();

          for (final p in oldPengampus) {
            final targetRombelId = rombelMap[p.rombelId] ?? p.rombelId;
            final newPId = _uuid.v4();
            final newPengampu = PengampuCompanion.insert(
              id: newPId,
              guruId: p.guruId,
              mapelId: p.mapelId,
              rombelId: targetRombelId,
              semesterId: newSemId,
              cakupan: Value(p.cakupan),
              peran: Value(p.peran),
              tanggalMulai: tanggalMulai,
              deviceId: deviceId,
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            );
            await db.into(db.pengampu).insert(newPengampu);
            await outbox.enqueue(tabel: 'pengampu', recordId: newPId, operasi: 'INSERT');
            pengampuCopied++;
          }
        }
      }

      return {
        'tahunAjaranId': newTahunId,
        'semesterId': newSemId,
        'rombelCopied': rombelCopied,
        'pengampuCopied': pengampuCopied,
      };
    });
  }
}
