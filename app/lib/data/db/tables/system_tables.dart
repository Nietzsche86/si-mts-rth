import 'package:drift/drift.dart';
import 'sync_mixin.dart';

@DataClassName('MadrasahData')
class Madrasah extends Table with SyncTableMixin {
  @override
  String get tableName => 'madrasah';

  TextColumn get nama => text()();
  TextColumn get npsn => text().nullable()();
  TextColumn get nsm => text().nullable()();
  TextColumn get alamat => text().nullable()();
  TextColumn get kepalaGuruId => text().named('kepala_guru_id').nullable()();
  TextColumn get logoBerkasId => text().named('logo_berkas_id').nullable()();
  TextColumn get semesterAktifId => text().named('semester_aktif_id').nullable()();
}

@DataClassName('UserData')
class User extends Table with SyncTableMixin {
  @override
  String get tableName => 'user';

  TextColumn get guruId => text().named('guru_id').nullable()();
  TextColumn get username => text().unique()();
  IntColumn get aktif => integer().withDefault(const Constant(1))();
}

@DataClassName('UserRoleData')
class UserRole extends Table with SyncTableMixin {
  @override
  String get tableName => 'user_role';

  TextColumn get userId => text().named('user_id')();
  TextColumn get role => text()(); // 'admin' | 'kepala'
}

@DataClassName('RefItemData')
class RefItem extends Table with SyncTableMixin {
  @override
  String get tableName => 'ref_item';

  TextColumn get kategori => text()();
  TextColumn get kode => text()();
  TextColumn get nama => text()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  IntColumn get aktif => integer().withDefault(const Constant(1))();
}

@DataClassName('RefWilayahData')
class RefWilayah extends Table with SyncTableMixin {
  @override
  String get tableName => 'ref_wilayah';

  TextColumn get kode => text()();
  TextColumn get nama => text()();
  TextColumn get tingkat => text()(); // 'prov' | 'kab' | 'kec' | 'desa'
  TextColumn get indukKode => text().named('induk_kode').nullable()();
}

// =============================================================================
// Tabel Khusus HP (Tidak disinkronkan langsung sebagai tabel domain)
// =============================================================================

@DataClassName('OutboxData')
class Outbox extends Table {
  @override
  String get tableName => 'outbox';

  IntColumn get localSeq => integer().autoIncrement().named('local_seq')();
  TextColumn get tabel => text()();
  TextColumn get barisId => text().named('baris_id')();
  TextColumn get operasi => text()(); // 'UPSERT' | 'DELETE'
  TextColumn get payloadJson => text().named('payload_json')();
  Int64Column get createdAt => int64().named('created_at')();
  IntColumn get percobaan => integer().withDefault(const Constant(0))();
  TextColumn get errorTerakhir => text().named('error_terakhir').nullable()();
}

@DataClassName('SyncStateData')
class SyncState extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn get kunci => text()();
  TextColumn get nilai => text()();

  @override
  Set<Column> get primaryKey => {kunci};
}

@DataClassName('BerkasAntreanData')
class BerkasAntrean extends Table {
  @override
  String get tableName => 'berkas_antrean';

  TextColumn get berkasId => text().named('berkas_id')();
  TextColumn get jenisPemilik => text().named('jenis_pemilik')(); // 'siswa' | 'guru'
  TextColumn get jalurLokal => text().named('jalur_lokal')();
  TextColumn get arah => text()(); // 'UPLOAD' | 'DOWNLOAD'
  TextColumn get status => text()(); // 'PENDING' | 'IN_PROGRESS' | 'DONE' | 'FAILED'
  RealColumn get progres => real().withDefault(const Constant(0.0))();
  TextColumn get errorTerakhir => text().named('error_terakhir').nullable()();

  @override
  Set<Column> get primaryKey => {berkasId};
}
