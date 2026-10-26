import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/berkas_util.dart';
import '../db/app_database.dart';
import '../sync/outbox_manager.dart';

class BerkasRepository {
  final AppDatabase db;
  final OutboxManager outbox;
  final _uuid = const Uuid();

  BerkasRepository({required this.db, required this.outbox});

  /// Mengambil seluruh berkas aktif milik siswa tertentu
  Future<List<SiswaBerkasData>> getBerkasForSiswa(String siswaId) async {
    final query = db.select(db.siswaBerkas)
      ..where((b) => b.siswaId.equals(siswaId) & b.deleted.equals(0))
      ..orderBy([(b) => OrderingTerm.desc(b.createdAt)]);
    return await query.get();
  }

  /// Menyimpan berkas baru ke database lokal dan mendaftarkannya ke antrean upload & outbox
  Future<SiswaBerkasData> simpanBerkasSiswa({
    required String siswaId,
    required String jenisBerkasKode,
    required String namaTampil,
    required Uint8List bytes,
    String? diunggahOlehUserId,
    String deviceId = 'hp-klien',
  }) async {
    final validation = BerkasUtil.validateBerkas(bytes, namaTampil);
    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage ?? 'Berkas tidak valid');
    }

    final berkasId = _uuid.v4();
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final nowBig = BigInt.from(nowMs);
    final sha256Checksum = validation.sha256Checksum;
    final mime = validation.mimeType.mimeString;

    final berkasData = SiswaBerkasData(
      id: berkasId,
      siswaId: siswaId,
      jenisBerkasKode: jenisBerkasKode,
      namaTampil: namaTampil,
      mimeType: mime,
      ukuranByte: bytes.length,
      sha256Plain: sha256Checksum,
      serverPathEnc: '$berkasId.enc',
      statusUnggah: 'PENDING',
      diunggahOlehUserId: diunggahOlehUserId,
      createdAt: nowBig,
      updatedAt: nowBig,
      deleted: 0,
      deviceId: deviceId,
      serverSeq: null,
    );

    await db.transaction(() async {
      // 1. Simpan metadata ke tabel siswa_berkas
      await db.into(db.siswaBerkas).insert(
        SiswaBerkasCompanion.insert(
          id: berkasId,
          siswaId: siswaId,
          jenisBerkasKode: jenisBerkasKode,
          namaTampil: namaTampil,
          mimeType: mime,
          ukuranByte: bytes.length,
          sha256Plain: sha256Checksum,
          serverPathEnc: Value('$berkasId.enc'),
          statusUnggah: const Value('PENDING'),
          diunggahOlehUserId: Value(diunggahOlehUserId),
          createdAt: nowBig,
          updatedAt: nowBig,
          deleted: const Value(0),
          deviceId: deviceId,
        ),
      );

      // 2. Daftarkan ke tabel berkas_antrean (PRD 9.2A)
      await db.into(db.berkasAntrean).insertOnConflictUpdate(
        BerkasAntreanCompanion.insert(
          berkasId: berkasId,
          jenisPemilik: 'siswa',
          jalurLokal: 'sandboxed://$berkasId',
          arah: 'UPLOAD',
          status: 'PENDING',
          progres: const Value(0.0),
        ),
      );

      // 3. Daftarkan ke outbox sync engine (Tingkat 5)
      await outbox.enqueueUpsert(
        table: 'siswa_berkas',
        barisId: berkasId,
        payload: {
          'id': berkasId,
          'siswa_id': siswaId,
          'jenis_berkas_kode': jenisBerkasKode,
          'nama_tampil': namaTampil,
          'mime_type': mime,
          'ukuran_byte': bytes.length,
          'sha256_plain': sha256Checksum,
          'server_path_enc': '$berkasId.enc',
          'status_unggah': 'PENDING',
          'diunggah_oleh_user_id': diunggahOlehUserId,
          'created_at': nowMs,
          'updated_at': nowMs,
          'deleted': 0,
          'device_id': deviceId,
        },
      );
    });

    return berkasData;
  }

  /// Menghapus berkas siswa (soft delete)
  Future<void> hapusBerkasSiswa(String berkasId, {String deviceId = 'hp-klien'}) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final nowBig = BigInt.from(nowMs);

    await db.transaction(() async {
      await (db.update(db.siswaBerkas)..where((b) => b.id.equals(berkasId))).write(
        SiswaBerkasCompanion(
          deleted: const Value(1),
          updatedAt: Value(nowBig),
        ),
      );

      await outbox.enqueueDelete(
        table: 'siswa_berkas',
        barisId: berkasId,
        payload: {
          'id': berkasId,
          'deleted': 1,
          'updated_at': nowMs,
          'device_id': deviceId,
        },
      );
    });
  }

  /// Mencatat pembukaan berkas ke audit log (PRD F5: 'pembukaan tercatat')
  Future<void> logBukaBerkas({
    required String berkasId,
    required String namaBerkas,
    required String userId,
    String deviceId = 'hp-klien',
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
        'tabel': 'siswa_berkas',
        'record_id': berkasId,
        'aksi': 'BUKA_BERKAS',
        'keterangan': 'Membuka dokumen/foto berkas sandboxed: $namaBerkas',
      },
    );
  }

  /// Mengambil daftar antrean berkas
  Future<List<BerkasAntreanData>> getAntreanBerkas() async {
    return await db.select(db.berkasAntrean).get();
  }

  /// Memperbarui progres antrean berkas
  Future<void> updateStatusAntrean(
    String berkasId,
    String status, {
    double progres = 0.0,
    String? errorTerakhir,
  }) async {
    await (db.update(db.berkasAntrean)..where((b) => b.berkasId.equals(berkasId))).write(
      BerkasAntreanCompanion(
        status: Value(status),
        progres: Value(progres),
        errorTerakhir: Value(errorTerakhir),
      ),
    );
  }
}
