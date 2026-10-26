import 'package:drift/drift.dart';

/// Mixin untuk kolom wajib di semua tabel yang disinkronkan sesuai CLAUDE.md & PRD Bagian 9.1:
/// - id (TEXT PRIMARY KEY — UUID v4)
/// - created_at (INTEGER NOT NULL — epoch ms UTC)
/// - updated_at (INTEGER NOT NULL — epoch ms UTC)
/// - deleted (INTEGER NOT NULL DEFAULT 0 — soft delete 0/1)
/// - device_id (TEXT NOT NULL)
/// - server_seq (INTEGER — diisi monotonik oleh server; NULL saat masih di outbox)
mixin SyncTableMixin on Table {
  TextColumn get id => text()();
  Int64Column get createdAt => int64().named('created_at')();
  Int64Column get updatedAt => int64().named('updated_at')();
  IntColumn get deleted => integer().named('deleted').withDefault(const Constant(0))();
  TextColumn get deviceId => text().named('device_id')();
  IntColumn get serverSeq => integer().named('server_seq').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
