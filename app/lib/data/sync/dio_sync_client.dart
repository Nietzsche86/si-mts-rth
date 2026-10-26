import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../db/app_database.dart';
import 'outbox_manager.dart';
import 'local_gc.dart';

class SyncPushItemResult {
  final int localSeq;
  final String status;
  final String? canonicalId;
  final String? error;

  const SyncPushItemResult({
    required this.localSeq,
    required this.status,
    this.canonicalId,
    this.error,
  });
}

class SyncPushSummary {
  final int totalSent;
  final int applied;
  final int merged;
  final int failed;
  final List<SyncPushItemResult> details;

  const SyncPushSummary({
    required this.totalSent,
    required this.applied,
    required this.merged,
    required this.failed,
    required this.details,
  });
}

class DioSyncClient {
  final Dio dio;
  final AppDatabase db;
  final OutboxManager outbox;

  DioSyncClient({
    required this.dio,
    required this.db,
    required this.outbox,
  });

  /// Mengirim semua antrean outbox ke endpoint server POST /api/v1/sync/push
  Future<SyncPushSummary> pushChanges({
    required String baseUrl,
    required String token,
    required String deviceId,
  }) async {
    final pendingRows = await (db.select(db.outbox)
          ..orderBy([(t) => OrderingTerm.asc(t.localSeq)]))
        .get();

    if (pendingRows.isEmpty) {
      return const SyncPushSummary(
        totalSent: 0,
        applied: 0,
        merged: 0,
        failed: 0,
        details: [],
      );
    }

    final items = pendingRows.map((r) {
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(r.payloadJson) as Map<String, dynamic>;
      } catch (_) {
        payload = {};
      }

      return {
        'local_seq': r.localSeq,
        'table': r.tabel,
        'row_id': r.barisId,
        'operation': r.operasi,
        'payload': payload,
        'created_at': r.createdAt.toInt(),
      };
    }).toList();

    final pushPayload = {
      'device_id': deviceId,
      'client_epoch_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
      'items': items,
    };

    final response = await dio.post(
      '$baseUrl/api/v1/sync/push',
      data: pushPayload,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    int applied = 0;
    int merged = 0;
    int failed = 0;
    final details = <SyncPushItemResult>[];

    final respData = response.data as Map<String, dynamic>;
    final results = (respData['results'] as List<dynamic>?) ?? [];

    for (final res in results) {
      final localSeq = res['local_seq'] as int;
      final status = res['status'] as String;
      final canonicalId = res['canonical_id'] as String?;
      final error = res['error'] as String?;

      details.add(SyncPushItemResult(
        localSeq: localSeq,
        status: status,
        canonicalId: canonicalId,
        error: error,
      ));

      if (status == 'APPLIED' || status == 'IGNORED_OUTDATED') {
        applied++;
        await outbox.removeOutboxItem(localSeq);
      } else if (status == 'MERGED_BY_BUSINESS_KEY') {
        merged++;
        // Tabrakan Business Key teratasi: hapus antrean dan sinkronkan UUID canonical jika perlu
        await outbox.removeOutboxItem(localSeq);
      } else {
        failed++;
      }
    }

    return SyncPushSummary(
      totalSent: items.length,
      applied: applied,
      merged: merged,
      failed: failed,
      details: details,
    );
  }

  /// Menarik pembaruan dari endpoint server GET /api/v1/sync/pull
  Future<int> pullChanges({
    required String baseUrl,
    required String token,
    required String deviceId,
  }) async {
    // Ambil seq terakhir dari sync_state
    final stateRow = await (db.select(db.syncState)
          ..where((t) => t.kunci.equals('last_pulled_server_seq')))
        .getSingleOrNull();

    final lastSeq = int.tryParse(stateRow?.nilai ?? '0') ?? 0;

    final response = await dio.get(
      '$baseUrl/api/v1/sync/pull',
      queryParameters: {
        'since_server_seq': lastSeq,
        'device_id': deviceId,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final data = response.data as Map<String, dynamic>;
    final serverSeqMax = (data['server_seq_max'] as int?) ?? lastSeq;
    final items = (data['items'] as List<dynamic>?) ?? [];

    // Terapkan perubahan dalam transaksi
    await db.transaction(() async {
      // Simpan cursor sync_state baru
      await db.into(db.syncState).insertOnConflictUpdate(
            SyncStateCompanion(
              kunci: const Value('last_pulled_server_seq'),
              nilai: Value(serverSeqMax.toString()),
            ),
          );

      // Simpan timestamp sinkronisasi terakhir
      await db.into(db.syncState).insertOnConflictUpdate(
            SyncStateCompanion(
              kunci: const Value('last_sync_timestamp'),
              nilai: Value(DateTime.now().toUtc().toIso8601String()),
            ),
          );
    });

    // Jalankan Local GC jika ada active_scope dari server
    final scope = data['active_scope'] as Map<String, dynamic>?;
    if (scope != null) {
      final allowedKeanggotaan = (scope['allowed_keanggotaan_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (allowedKeanggotaan.isNotEmpty) {
        await LocalGc.runGarbageCollection(
          db: db,
          allowedKeanggotaanIds: allowedKeanggotaan,
        );
      }
    }

    return items.length;
  }
}
