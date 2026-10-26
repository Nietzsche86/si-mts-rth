import 'package:drift/drift.dart';
import 'sync_mixin.dart';

@DataClassName('TahunAjaranData')
class TahunAjaran extends Table with SyncTableMixin {
  @override
  String get tableName => 'tahun_ajaran';

  TextColumn get nama => text()(); // "2026/2027"
  TextColumn get tanggalMulai => text().named('tanggal_mulai')();
  TextColumn get tanggalSelesai => text().named('tanggal_selesai')();
  IntColumn get aktif => integer().withDefault(const Constant(0))();
}

@DataClassName('SemesterData')
class Semester extends Table with SyncTableMixin {
  @override
  String get tableName => 'semester';

  TextColumn get tahunAjaranId => text().named('tahun_ajaran_id')();
  TextColumn get jenis => text()(); // 'ganjil' | 'genap'
  TextColumn get tanggalMulai => text().named('tanggal_mulai')();
  TextColumn get tanggalSelesai => text().named('tanggal_selesai')();
  IntColumn get dikunci => integer().withDefault(const Constant(0))();
}

@DataClassName('MapelData')
class Mapel extends Table with SyncTableMixin {
  @override
  String get tableName => 'mapel';

  TextColumn get kode => text().unique()();
  TextColumn get nama => text()();
  TextColumn get kelompok => text()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  IntColumn get aktif => integer().withDefault(const Constant(1))();
}

@DataClassName('RombelData')
class Rombel extends Table with SyncTableMixin {
  @override
  String get tableName => 'rombel';

  TextColumn get tahunAjaranId => text().named('tahun_ajaran_id')();
  TextColumn get nama => text()(); // "7A", "8B"
  TextColumn get tingkat => text()(); // '7' | '8' | '9'
  TextColumn get waliGuruId => text().named('wali_guru_id').nullable()();
}

@DataClassName('PengampuData')
class Pengampu extends Table with SyncTableMixin {
  @override
  String get tableName => 'pengampu';

  TextColumn get guruId => text().named('guru_id')();
  TextColumn get mapelId => text().named('mapel_id')();
  TextColumn get rombelId => text().named('rombel_id')();
  TextColumn get semesterId => text().named('semester_id')();
  TextColumn get cakupan => text().withDefault(const Constant('seluruh'))(); // 'seluruh' | 'sebagian'
  TextColumn get peran => text().withDefault(const Constant('utama'))(); // 'utama' | 'pendamping'
  TextColumn get tanggalMulai => text().named('tanggal_mulai')();
  TextColumn get tanggalSelesai => text().named('tanggal_selesai').nullable()();
}

@DataClassName('PengampuSiswaData')
class PengampuSiswa extends Table with SyncTableMixin {
  @override
  String get tableName => 'pengampu_siswa';

  TextColumn get pengampuId => text().named('pengampu_id')();
  TextColumn get keanggotaanId => text().named('keanggotaan_id')();
}

@DataClassName('KeanggotaanRombelData')
class KeanggotaanRombel extends Table with SyncTableMixin {
  @override
  String get tableName => 'keanggotaan_rombel';

  TextColumn get siswaId => text().named('siswa_id')();
  TextColumn get rombelId => text().named('rombel_id')();
  TextColumn get tanggalMasuk => text().named('tanggal_masuk')();
  TextColumn get tanggalKeluar => text().named('tanggal_keluar').nullable()();
  TextColumn get alasanKeluar => text().named('alasan_keluar').nullable()();
  TextColumn get sumberKeanggotaanId => text().named('sumber_keanggotaan_id').nullable()();
}

@DataClassName('RiwayatStatusSiswaData')
class RiwayatStatusSiswa extends Table with SyncTableMixin {
  @override
  String get tableName => 'riwayat_status_siswa';

  TextColumn get siswaId => text().named('siswa_id')();
  TextColumn get tanggal => text()();
  TextColumn get jenisStatus => text().named('jenis_status')();
  TextColumn get rombelAsalId => text().named('rombel_asal_id').nullable()();
  TextColumn get rombelTujuanId => text().named('rombel_tujuan_id').nullable()();
  TextColumn get sekolahTujuan => text().named('sekolah_tujuan').nullable()();
  TextColumn get nomorSurat => text().named('nomor_surat').nullable()();
  TextColumn get catatan => text().nullable()();
  TextColumn get membatalkanId => text().named('membatalkan_id').nullable()();
}

@DataClassName('JenisNilaiData')
class JenisNilai extends Table with SyncTableMixin {
  @override
  String get tableName => 'jenis_nilai';

  TextColumn get kategori => text()(); // 'pengetahuan' | 'keterampilan'
  TextColumn get kode => text().unique()(); // 'TGS', 'UH', 'PAS', 'PAT', 'PRY', 'PRT', 'UK'
  TextColumn get nama => text()();
  IntColumn get urutan => integer().withDefault(const Constant(0))();
  IntColumn get aktif => integer().withDefault(const Constant(1))();
}

@DataClassName('BobotNilaiData')
class BobotNilai extends Table with SyncTableMixin {
  @override
  String get tableName => 'bobot_nilai';

  TextColumn get semesterId => text().named('semester_id')();
  TextColumn get mapelId => text().named('mapel_id').nullable()();
  TextColumn get jenisNilaiId => text().named('jenis_nilai_id')();
  RealColumn get bobot => real().withDefault(const Constant(1.0))();
}

@DataClassName('PengaturanKkmData')
class PengaturanKkm extends Table with SyncTableMixin {
  @override
  String get tableName => 'pengaturan_kkm';

  TextColumn get semesterId => text().named('semester_id')();
  TextColumn get mapelId => text().named('mapel_id').nullable()();
  TextColumn get tingkat => text().nullable()();
  RealColumn get kkm => real().withDefault(const Constant(75.0))();
}

@DataClassName('NilaiData')
class Nilai extends Table with SyncTableMixin {
  @override
  String get tableName => 'nilai';

  TextColumn get keanggotaanId => text().named('keanggotaan_id')();
  TextColumn get mapelId => text().named('mapel_id')();
  TextColumn get semesterId => text().named('semester_id')();
  TextColumn get jenisNilaiId => text().named('jenis_nilai_id')();
  IntColumn get urutanKe => integer().named('urutan_ke').withDefault(const Constant(1))();
  RealColumn get nilai => real()();
  TextColumn get tanggal => text()();
  TextColumn get keterangan => text().nullable()();
  TextColumn get sumberNilaiId => text().named('sumber_nilai_id').nullable()();
  TextColumn get diinputOlehGuruId => text().named('diinput_oleh_guru_id')();
}

@DataClassName('AbsensiData')
class Absensi extends Table with SyncTableMixin {
  @override
  String get tableName => 'absensi';

  TextColumn get keanggotaanId => text().named('keanggotaan_id')();
  TextColumn get semesterId => text().named('semester_id')();
  TextColumn get tanggal => text()();
  TextColumn get status => text()(); // 'H' | 'S' | 'I' | 'A'
  TextColumn get keterangan => text().nullable()();
  TextColumn get diinputOlehUserId => text().named('diinput_oleh_user_id')();
}
