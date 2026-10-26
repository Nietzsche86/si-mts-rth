import 'dart:convert';
import 'package:drift/drift.dart';
import '../db/app_database.dart';

class OutboxManager {
  final AppDatabase db;

  OutboxManager(this.db);

  /// Menambahkan entri perubahan lokal ke antrean outbox
  Future<int> enqueueUpsert({
    required String table,
    required String barisId,
    required Map<String, dynamic> payload,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return await db.into(db.outbox).insert(
      OutboxCompanion.insert(
        tabel: table,
        barisId: barisId,
        operasi: 'UPSERT',
        payloadJson: jsonEncode(payload),
        createdAt: BigInt.from(nowMs),
        percobaan: const Value(0),
      ),
    );
  }

  /// Menambahkan operasi soft-delete ke antrean outbox
  Future<int> enqueueDelete({
    required String table,
    required String barisId,
    required Map<String, dynamic> payload,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return await db.into(db.outbox).insert(
      OutboxCompanion.insert(
        tabel: table,
        barisId: barisId,
        operasi: 'DELETE',
        payloadJson: jsonEncode(payload),
        createdAt: BigInt.from(nowMs),
        percobaan: const Value(0),
      ),
    );
  }

  /// Menghitung jumlah antrean outbox yang belum tersinkron
  Future<int> enqueue({
    required String tabel,
    required String recordId,
    required String operasi,
    Map<String, dynamic> payload = const {},
  }) async {
    if (operasi == 'DELETE') {
      return enqueueDelete(table: tabel, barisId: recordId, payload: payload);
    }
    return enqueueUpsert(table: tabel, barisId: recordId, payload: payload);
  }

  /// Menghitung jumlah antrean outbox yang belum tersinkron
  Future<int> getPendingCount() async {
    final countExp = db.outbox.localSeq.count();
    final query = db.selectOnly(db.outbox)..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }

  /// Menghapus item outbox setelah berhasil diterapkan di server
  Future<int> removeOutboxItem(int localSeq) async {
    return await (db.delete(db.outbox)..where((tbl) => tbl.localSeq.equals(localSeq))).go();
  }
}
