import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/emis_csv_helper.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

class EmisImportResult {
  final bool success;
  final int importedCount;
  final int skippedCount;
  final String message;

  EmisImportResult({
    required this.success,
    required this.importedCount,
    required this.skippedCount,
    required this.message,
  });
}

class EmisRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  EmisRepository({required this.db, required this.outbox});

  /// Mengekspor data siswa aktif di suatu rombel ke format CSV standar EMIS
  Future<String> exportRombelToCsv(
    String rombelId, {
    bool maskSensitif = true,
  }) async {
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
    final List<List<String>> csvData = [];

    for (int idx = 0; idx < rows.length; idx++) {
      final s = rows[idx].readTable(db.siswa);

      // Ambil detail
      final detail = await (db.select(db.siswaDetail)
            ..where((d) => d.siswaId.equals(s.id) & d.deleted.equals(0)))
          .getSingleOrNull();

      // Ambil ortu
      final ortuList = await (db.select(db.siswaOrtu)
            ..where((o) => o.siswaId.equals(s.id) & o.deleted.equals(0)))
          .get();
      final ibu = ortuList.where((o) => o.hubungan == 'ibu').firstOrNull;
      final ayah = ortuList.where((o) => o.hubungan == 'ayah').firstOrNull;

      // Ambil alamat
      final alamat = await (db.select(db.alamat)
            ..where((a) => a.pemilikId.equals(s.id) & a.deleted.equals(0)))
          .getSingleOrNull();

      // Ambil data sensitif
      final sensitif = await (db.select(db.siswaSensitif)
            ..where((sn) => sn.siswaId.equals(s.id) & sn.deleted.equals(0)))
          .getSingleOrNull();

      String nikVal = sensitif?.nikSiswaEnc ?? '';
      String kkVal = sensitif?.noKkEnc ?? '';

      if (maskSensitif) {
        if (nikVal.length >= 8) {
          nikVal = '${nikVal.substring(0, 4)}••••••••${nikVal.substring(nikVal.length - 4)}';
        } else if (nikVal.isNotEmpty) {
          nikVal = '••••••••';
        }
        if (kkVal.length >= 8) {
          kkVal = '${kkVal.substring(0, 4)}••••••••${kkVal.substring(kkVal.length - 4)}';
        } else if (kkVal.isNotEmpty) {
          kkVal = '••••••••';
        }
      }

      csvData.add([
        (idx + 1).toString(),
        nikVal,
        kkVal,
        s.nis,
        s.nisn ?? '',
        s.namaLengkap,
        s.jk,
        detail?.tempatLahir ?? '',
        detail?.tanggalLahir ?? '',
        ibu?.namaLengkap ?? '',
        ayah?.namaLengkap ?? '',
        alamat?.jalan ?? '',
        alamat?.desaNama ?? '',
        alamat?.kecamatanNama ?? '',
        alamat?.kabupatenNama ?? '',
        alamat?.provinsiNama ?? '',
      ]);
    }

    return EmisCsvHelper.generateExportCsv(csvData);
  }

  /// Menjalankan pratinjau dan validasi offline CSV EMIS terhadap database lokal
  Future<EmisImportPreviewResult> previewCsv(String csvContent) async {
    final existingSiswa = await (db.select(db.siswa)..where((s) => s.deleted.equals(0))).get();
    final existingNisSet = existingSiswa.map((s) => s.nis).toSet();
    return EmisCsvHelper.validateAndPreviewCsv(csvContent, existingNisSet: existingNisSet);
  }

  /// Mengimpor data siswa dari CSV EMIS ke SQLite lokal dan mendaftarkannya ke outbox
  Future<EmisImportResult> commitImportOffline({
    required List<EmisImportRowData> validRows,
    required String rombelId,
    required String tanggalMasuk,
    String? userId,
    String deviceId = 'hp-klien',
  }) async {
    int imported = 0;
    int skipped = 0;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final nowBig = BigInt.from(nowMs);

    await db.transaction(() async {
      for (final item in validRows) {
        if (!item.isValid) {
          skipped++;
          continue;
        }

        // Cek duplikat NIS di database
        final exists = await (db.select(db.siswa)
              ..where((s) => s.nis.equals(item.nis) & s.deleted.equals(0)))
            .getSingleOrNull();

        if (exists != null) {
          skipped++;
          continue;
        }

        final siswaId = _uuid.v4();

        // 1. Siswa Inti (Tingkat 3)
        await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: siswaId,
            nis: item.nis,
            nisn: Value(item.nisn.isNotEmpty ? item.nisn : null),
            namaLengkap: item.namaLengkap,
            jk: item.jk,
            statusAktif: const Value('aktif'),
            diubahWaliKelas: const Value(0),
            createdAt: nowBig,
            updatedAt: nowBig,
            deleted: const Value(0),
            deviceId: deviceId,
          ),
        );

        await outbox.enqueueUpsert(
          table: 'siswa',
          barisId: siswaId,
          payload: {
            'id': siswaId,
            'nis': item.nis,
            'nisn': item.nisn.isNotEmpty ? item.nisn : null,
            'nama_lengkap': item.namaLengkap,
            'jk': item.jk,
            'status_aktif': 'aktif',
            'diubah_wali_kelas': 0,
            'created_at': nowMs,
            'updated_at': nowMs,
            'deleted': 0,
            'device_id': deviceId,
          },
        );

        // 2. Siswa Detail (Tingkat 3)
        final detailId = _uuid.v4();
        await db.into(db.siswaDetail).insert(
          SiswaDetailCompanion.insert(
            id: detailId,
            siswaId: siswaId,
            tempatLahir: Value(item.tempatLahir.isNotEmpty ? item.tempatLahir : null),
            tanggalLahir: Value(item.tanggalLahir.isNotEmpty ? item.tanggalLahir : null),
            tanggalMasuk: Value(tanggalMasuk),
            createdAt: nowBig,
            updatedAt: nowBig,
            deleted: const Value(0),
            deviceId: deviceId,
          ),
        );

        await outbox.enqueueUpsert(
          table: 'siswa_detail',
          barisId: detailId,
          payload: {
            'id': detailId,
            'siswa_id': siswaId,
            'tempat_lahir': item.tempatLahir.isNotEmpty ? item.tempatLahir : null,
            'tanggal_lahir': item.tanggalLahir.isNotEmpty ? item.tanggalLahir : null,
            'tanggal_masuk': tanggalMasuk,
            'created_at': nowMs,
            'updated_at': nowMs,
            'deleted': 0,
            'device_id': deviceId,
            'kolom_ts': '{}',
          },
        );

        // 3. Siswa Ortu (Ibu & Ayah)
        if (item.namaIbu.isNotEmpty) {
          final ibuId = _uuid.v4();
          await db.into(db.siswaOrtu).insert(
            SiswaOrtuCompanion.insert(
              id: ibuId,
              siswaId: siswaId,
              hubungan: 'ibu',
              namaLengkap: item.namaIbu,
              createdAt: nowBig,
              updatedAt: nowBig,
              deleted: const Value(0),
              deviceId: deviceId,
            ),
          );

          await outbox.enqueueUpsert(
            table: 'siswa_ortu',
            barisId: ibuId,
            payload: {
              'id': ibuId,
              'siswa_id': siswaId,
              'hubungan': 'ibu',
              'nama_lengkap': item.namaIbu,
              'created_at': nowMs,
              'updated_at': nowMs,
              'deleted': 0,
              'device_id': deviceId,
              'kolom_ts': '{}',
            },
          );
        }

        if (item.namaAyah.isNotEmpty) {
          final ayahId = _uuid.v4();
          await db.into(db.siswaOrtu).insert(
            SiswaOrtuCompanion.insert(
              id: ayahId,
              siswaId: siswaId,
              hubungan: 'ayah',
              namaLengkap: item.namaAyah,
              createdAt: nowBig,
              updatedAt: nowBig,
              deleted: const Value(0),
              deviceId: deviceId,
            ),
          );

          await outbox.enqueueUpsert(
            table: 'siswa_ortu',
            barisId: ayahId,
            payload: {
              'id': ayahId,
              'siswa_id': siswaId,
              'hubungan': 'ayah',
              'nama_lengkap': item.namaAyah,
              'created_at': nowMs,
              'updated_at': nowMs,
              'deleted': 0,
              'device_id': deviceId,
              'kolom_ts': '{}',
            },
          );
        }

        // 4. Alamat (Tingkat 3)
        if (item.jalan.isNotEmpty || item.desaNama.isNotEmpty || item.kecamatanNama.isNotEmpty) {
          final alamatId = _uuid.v4();
          await db.into(db.alamat).insert(
            AlamatCompanion.insert(
              id: alamatId,
              pemilikTipe: 'siswa',
              pemilikId: siswaId,
              siswaId: Value(siswaId),
              jalan: Value(item.jalan.isNotEmpty ? item.jalan : null),
              desaNama: Value(item.desaNama.isNotEmpty ? item.desaNama : null),
              kecamatanNama: Value(item.kecamatanNama.isNotEmpty ? item.kecamatanNama : null),
              kabupatenNama: Value(item.kabupatenNama.isNotEmpty ? item.kabupatenNama : null),
              provinsiNama: Value(item.provinsiNama.isNotEmpty ? item.provinsiNama : null),
              createdAt: nowBig,
              updatedAt: nowBig,
              deleted: const Value(0),
              deviceId: deviceId,
            ),
          );

          await outbox.enqueueUpsert(
            table: 'alamat',
            barisId: alamatId,
            payload: {
              'id': alamatId,
              'pemilik_tipe': 'siswa',
              'pemilik_id': siswaId,
              'siswa_id': siswaId,
              'jalan': item.jalan.isNotEmpty ? item.jalan : null,
              'desa_nama': item.desaNama.isNotEmpty ? item.desaNama : null,
              'kecamatan_nama': item.kecamatanNama.isNotEmpty ? item.kecamatanNama : null,
              'kabupaten_nama': item.kabupatenNama.isNotEmpty ? item.kabupatenNama : null,
              'provinsi_nama': item.provinsiNama.isNotEmpty ? item.provinsiNama : null,
              'created_at': nowMs,
              'updated_at': nowMs,
              'deleted': 0,
              'device_id': deviceId,
              'kolom_ts': '{}',
            },
          );
        }

        // 5. Siswa Sensitif (Tingkat 3)
        if (item.nik.isNotEmpty || item.noKk.isNotEmpty) {
          final sensitifId = _uuid.v4();
          await db.into(db.siswaSensitif).insert(
            SiswaSensitifCompanion.insert(
              id: sensitifId,
              siswaId: siswaId,
              nikSiswaEnc: Value(item.nik.isNotEmpty ? item.nik : null),
              noKkEnc: Value(item.noKk.isNotEmpty ? item.noKk : null),
              createdAt: nowBig,
              updatedAt: nowBig,
              deleted: const Value(0),
              deviceId: deviceId,
            ),
          );

          await outbox.enqueueUpsert(
            table: 'siswa_sensitif',
            barisId: sensitifId,
            payload: {
              'id': sensitifId,
              'siswa_id': siswaId,
              'nik_siswa_enc': item.nik.isNotEmpty ? item.nik : null,
              'no_kk_enc': item.noKk.isNotEmpty ? item.noKk : null,
              'created_at': nowMs,
              'updated_at': nowMs,
              'deleted': 0,
              'device_id': deviceId,
            },
          );
        }

        // 6. Keanggotaan Rombel (Tingkat 4)
        final keanggotaanId = _uuid.v4();
        await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: keanggotaanId,
            siswaId: siswaId,
            rombelId: rombelId,
            tanggalMasuk: tanggalMasuk,
            createdAt: nowBig,
            updatedAt: nowBig,
            deleted: const Value(0),
            deviceId: deviceId,
          ),
        );

        await outbox.enqueueUpsert(
          table: 'keanggotaan_rombel',
          barisId: keanggotaanId,
          payload: {
            'id': keanggotaanId,
            'siswa_id': siswaId,
            'rombel_id': rombelId,
            'tanggal_masuk': tanggalMasuk,
            'created_at': nowMs,
            'updated_at': nowMs,
            'deleted': 0,
            'device_id': deviceId,
          },
        );

        // 7. Riwayat Status Siswa (Tingkat 4)
        final riwayatId = _uuid.v4();
        await db.into(db.riwayatStatusSiswa).insert(
          RiwayatStatusSiswaCompanion.insert(
            id: riwayatId,
            siswaId: siswaId,
            tanggal: tanggalMasuk,
            jenisStatus: 'masuk_baru',
            rombelTujuanId: Value(rombelId),
            catatan: const Value('Impor EMIS Offline'),
            createdAt: nowBig,
            updatedAt: nowBig,
            deleted: const Value(0),
            deviceId: deviceId,
          ),
        );

        await outbox.enqueueUpsert(
          table: 'riwayat_status_siswa',
          barisId: riwayatId,
          payload: {
            'id': riwayatId,
            'siswa_id': siswaId,
            'tanggal': tanggalMasuk,
            'jenis_status': 'masuk_baru',
            'rombel_tujuan_id': rombelId,
            'catatan': 'Impor EMIS Offline',
            'created_at': nowMs,
            'updated_at': nowMs,
            'deleted': 0,
            'device_id': deviceId,
          },
        );

        imported++;
      }

      // Catat audit log
      final auditLogId = _uuid.v4();
      await outbox.enqueue(
        tabel: 'audit_log',
        recordId: auditLogId,
        operasi: 'INSERT',
        payload: {
          'id': auditLogId,
          'waktu': nowMs,
          'user_id': userId,
          'device_id': deviceId,
          'tabel': 'siswa',
          'record_id': rombelId,
          'aksi': 'IMPOR_EMIS_OFFLINE',
          'keterangan': 'Impor EMIS lokal: $imported siswa berhasil dimasukkan ke rombel tujuan',
        },
      );
    });

    return EmisImportResult(
      success: true,
      importedCount: imported,
      skippedCount: skipped,
      message: 'Berhasil mengimpor $imported siswa ($skipped dilewati)',
    );
  }
}
