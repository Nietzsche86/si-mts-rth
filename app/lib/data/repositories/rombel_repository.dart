import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

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
}
