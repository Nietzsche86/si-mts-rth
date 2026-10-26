import 'package:drift/drift.dart';
import 'sync_mixin.dart';

@DataClassName('SiswaData')
class Siswa extends Table with SyncTableMixin {
  @override
  String get tableName => 'siswa';

  TextColumn get nis => text().unique()();
  TextColumn get nisn => text().nullable()();
  TextColumn get namaLengkap => text().named('nama_lengkap')();
  TextColumn get jk => text()(); // 'L' | 'P'
  TextColumn get statusAktif => text().named('status_aktif').withDefault(const Constant('aktif'))();
  IntColumn get diubahWaliKelas => integer().named('diubah_wali_kelas').withDefault(const Constant(0))();
}

@DataClassName('SiswaDetailData')
class SiswaDetail extends Table with SyncTableMixin {
  @override
  String get tableName => 'siswa_detail';

  TextColumn get siswaId => text().named('siswa_id').unique()();
  TextColumn get tempatLahir => text().named('tempat_lahir').nullable()();
  TextColumn get tanggalLahir => text().named('tanggal_lahir').nullable()();
  TextColumn get agamaKode => text().named('agama_kode').nullable()();
  IntColumn get anakKe => integer().named('anak_ke').nullable()();
  IntColumn get jumlahSaudara => integer().named('jumlah_saudara').nullable()();
  TextColumn get fotoBerkasId => text().named('foto_berkas_id').nullable()();
  TextColumn get nomorHp => text().named('nomor_hp').nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get kebutuhanKhususKode => text().named('kebutuhan_khusus_kode').nullable()();
  RealColumn get tinggiCm => real().named('tinggi_cm').nullable()();
  RealColumn get beratKg => real().named('berat_kg').nullable()();
  TextColumn get tinggalBersamaKode => text().named('tinggal_bersama_kode').nullable()();
  TextColumn get transportasiKode => text().named('transportasi_kode').nullable()();
  RealColumn get jarakKm => real().named('jarak_km').nullable()();
  IntColumn get waktuTempuhMenit => integer().named('waktu_tempuh_menit').nullable()();
  IntColumn get penerimaKip => integer().named('penerima_kip').withDefault(const Constant(0))();
  IntColumn get penerimaKps => integer().named('penerima_kps').withDefault(const Constant(0))();
  IntColumn get penerimaPkh => integer().named('penerima_pkh').withDefault(const Constant(0))();
  TextColumn get sekolahAsal => text().named('sekolah_asal').nullable()();
  TextColumn get tanggalMasuk => text().named('tanggal_masuk').nullable()();
  TextColumn get jenisPendaftaranKode => text().named('jenis_pendaftaran_kode').nullable()();
  IntColumn get diubahWaliKelas => integer().named('diubah_wali_kelas').withDefault(const Constant(0))();
  TextColumn get kolomTs => text().named('kolom_ts').withDefault(const Constant('{}'))();
}

@DataClassName('SiswaOrtuData')
class SiswaOrtu extends Table with SyncTableMixin {
  @override
  String get tableName => 'siswa_ortu';

  TextColumn get siswaId => text().named('siswa_id')();
  TextColumn get hubungan => text()(); // 'ayah' | 'ibu' | 'wali'
  TextColumn get namaLengkap => text().named('nama_lengkap')();
  TextColumn get tempatLahir => text().named('tempat_lahir').nullable()();
  TextColumn get tanggalLahir => text().named('tanggal_lahir').nullable()();
  TextColumn get statusHidupKode => text().named('status_hidup_kode').nullable()();
  IntColumn get tahunWafat => integer().named('tahun_wafat').nullable()();
  TextColumn get pekerjaanKode => text().named('pekerjaan_kode').nullable()();
  TextColumn get pendidikanKode => text().named('pendidikan_kode').nullable()();
  TextColumn get penghasilanKode => text().named('penghasilan_kode').nullable()();
  TextColumn get nomorHp => text().named('nomor_hp').nullable()();
  TextColumn get kebutuhanKhususKode => text().named('kebutuhan_khusus_kode').nullable()();
  IntColumn get diubahWaliKelas => integer().named('diubah_wali_kelas').withDefault(const Constant(0))();
  TextColumn get kolomTs => text().named('kolom_ts').withDefault(const Constant('{}'))();
}

@DataClassName('AlamatData')
class Alamat extends Table with SyncTableMixin {
  @override
  String get tableName => 'alamat';

  TextColumn get pemilikTipe => text().named('pemilik_tipe')(); // 'siswa' | 'siswa_ortu' | 'guru'
  TextColumn get pemilikId => text().named('pemilik_id')();
  TextColumn get siswaId => text().named('siswa_id').nullable()();
  TextColumn get jalan => text().nullable()();
  TextColumn get rt => text().nullable()();
  TextColumn get rw => text().nullable()();
  TextColumn get dusun => text().nullable()();
  TextColumn get desaKode => text().named('desa_kode').nullable()();
  TextColumn get desaNama => text().named('desa_nama').nullable()();
  TextColumn get kecamatanKode => text().named('kecamatan_kode').nullable()();
  TextColumn get kecamatanNama => text().named('kecamatan_nama').nullable()();
  TextColumn get kabupatenKode => text().named('kabupaten_kode').nullable()();
  TextColumn get kabupatenNama => text().named('kabupaten_nama').nullable()();
  TextColumn get provinsiKode => text().named('provinsi_kode').nullable()();
  TextColumn get provinsiNama => text().named('provinsi_nama').nullable()();
  TextColumn get kodePos => text().named('kode_pos').nullable()();
  IntColumn get diubahWaliKelas => integer().named('diubah_wali_kelas').withDefault(const Constant(0))();
  TextColumn get kolomTs => text().named('kolom_ts').withDefault(const Constant('{}'))();
}

@DataClassName('SiswaSensitifData')
class SiswaSensitif extends Table with SyncTableMixin {
  @override
  String get tableName => 'siswa_sensitif';

  TextColumn get siswaId => text().named('siswa_id').unique()();
  TextColumn get noKkEnc => text().named('no_kk_enc').nullable()();
  TextColumn get nikSiswaEnc => text().named('nik_siswa_enc').nullable()();
  TextColumn get nikAyahEnc => text().named('nik_ayah_enc').nullable()();
  TextColumn get nikIbuEnc => text().named('nik_ibu_enc').nullable()();
  TextColumn get nikWaliEnc => text().named('nik_wali_enc').nullable()();
  TextColumn get noKipEnc => text().named('no_kip_enc').nullable()();
  TextColumn get noKpsEnc => text().named('no_kps_enc').nullable()();
  TextColumn get noPkhEnc => text().named('no_pkh_enc').nullable()();
}

@DataClassName('SiswaBerkasData')
class SiswaBerkas extends Table with SyncTableMixin {
  @override
  String get tableName => 'siswa_berkas';

  TextColumn get siswaId => text().named('siswa_id')();
  TextColumn get jenisBerkasKode => text().named('jenis_berkas_kode')();
  TextColumn get namaTampil => text().named('nama_tampil')();
  TextColumn get mimeType => text().named('mime_type')();
  IntColumn get ukuranByte => integer().named('ukuran_byte')();
  TextColumn get sha256Plain => text().named('sha256_plain')();
  TextColumn get serverPathEnc => text().named('server_path_enc').nullable()();
  TextColumn get statusUnggah => text().named('status_unggah').withDefault(const Constant('SELESAI'))();
  TextColumn get diunggahOlehUserId => text().named('diunggah_oleh_user_id').nullable()();
}

@DataClassName('GuruData')
class Guru extends Table with SyncTableMixin {
  @override
  String get tableName => 'guru';

  TextColumn get nip => text().nullable()();
  TextColumn get namaLengkap => text().named('nama_lengkap')();
  TextColumn get jk => text()(); // 'L' | 'P'
  TextColumn get statusKepegawaianKode => text().named('status_kepegawaian_kode').nullable()();
  IntColumn get aktif => integer().withDefault(const Constant(1))();
}

@DataClassName('GuruDetailData')
class GuruDetail extends Table with SyncTableMixin {
  @override
  String get tableName => 'guru_detail';

  TextColumn get guruId => text().named('guru_id').unique()();
  TextColumn get nuptk => text().nullable()();
  TextColumn get tempatLahir => text().named('tempat_lahir').nullable()();
  TextColumn get tanggalLahir => text().named('tanggal_lahir').nullable()();
  TextColumn get agamaKode => text().named('agama_kode').nullable()();
  TextColumn get nomorHp => text().named('nomor_hp').nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get fotoBerkasId => text().named('foto_berkas_id').nullable()();
  TextColumn get pendidikanKode => text().named('pendidikan_kode').nullable()();
  TextColumn get jurusan => text().nullable()();
  TextColumn get perguruanTinggi => text().named('perguruan_tinggi').nullable()();
  IntColumn get tahunLulus => integer().named('tahun_lulus').nullable()();
  TextColumn get tmtGuru => text().named('tmt_guru').nullable()();
  TextColumn get golonganKode => text().named('golongan_kode').nullable()();
  IntColumn get sertifikasi => integer().withDefault(const Constant(0))();
  TextColumn get kolomTs => text().named('kolom_ts').withDefault(const Constant('{}'))();
}

@DataClassName('GuruSensitifData')
class GuruSensitif extends Table with SyncTableMixin {
  @override
  String get tableName => 'guru_sensitif';

  TextColumn get guruId => text().named('guru_id').unique()();
  TextColumn get nikEnc => text().named('nik_enc').nullable()();
}

@DataClassName('GuruBerkasData')
class GuruBerkas extends Table with SyncTableMixin {
  @override
  String get tableName => 'guru_berkas';

  TextColumn get guruId => text().named('guru_id')();
  TextColumn get jenisBerkasKode => text().named('jenis_berkas_kode')();
  TextColumn get namaTampil => text().named('nama_tampil')();
  TextColumn get mimeType => text().named('mime_type')();
  IntColumn get ukuranByte => integer().named('ukuran_byte')();
  TextColumn get sha256Plain => text().named('sha256_plain')();
  TextColumn get serverPathEnc => text().named('server_path_enc').nullable()();
  TextColumn get statusUnggah => text().named('status_unggah').withDefault(const Constant('SELESAI'))();
}
