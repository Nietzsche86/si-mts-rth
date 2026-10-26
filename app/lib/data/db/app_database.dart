import 'package:drift/drift.dart';
import 'tables/system_tables.dart';
import 'tables/academic_tables.dart';
import 'tables/entity_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  // Master & Sistem
  Madrasah, User, UserRole, RefItem, RefWilayah,
  Outbox, SyncState, BerkasAntrean,
  // Akademik
  TahunAjaran, Semester, Mapel, Rombel, Pengampu, PengampuSiswa,
  KeanggotaanRombel, RiwayatStatusSiswa, JenisNilai, BobotNilai,
  PengaturanKkm, Nilai, Absensi,
  // Entitas
  Siswa, SiswaDetail, SiswaOrtu, Alamat, SiswaSensitif, SiswaBerkas,
  Guru, GuruDetail, GuruSensitif, GuruBerkas,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      
      // Eksekusi 5 Partial Unique Index wajib sesuai CLAUDE.md & PRD Bagian 9.3:
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_keanggotaan_terbuka_unik
        ON keanggotaan_rombel(siswa_id)
        WHERE tanggal_keluar IS NULL AND deleted = 0;
      ''');
      
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_utama_aktif
        ON pengampu(mapel_id, rombel_id, semester_id)
        WHERE peran = 'utama' AND tanggal_selesai IS NULL AND deleted = 0;
      ''');
      
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_pengampu_guru_aktif
        ON pengampu(guru_id, mapel_id, rombel_id, semester_id)
        WHERE tanggal_selesai IS NULL AND deleted = 0;
      ''');
      
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_nilai_bisnis_unik
        ON nilai(keanggotaan_id, mapel_id, semester_id, jenis_nilai_id, urutan_ke)
        WHERE deleted = 0;
      ''');
      
      await customStatement('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_absensi_bisnis_unik
        ON absensi(keanggotaan_id, tanggal)
        WHERE deleted = 0;
      ''');

      // Indeks Performa Tambahan
      await customStatement('CREATE INDEX IF NOT EXISTS idx_siswa_nis ON siswa(nis);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_keanggotaan_siswa_rombel ON keanggotaan_rombel(siswa_id, rombel_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_nilai_keanggotaan_sem ON nilai(keanggotaan_id, semester_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_nilai_mapel_sem ON nilai(mapel_id, semester_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_pengampu_guru_sem ON pengampu(guru_id, semester_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_pengampu_siswa_keanggotaan ON pengampu_siswa(keanggotaan_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_rombel_wali ON rombel(wali_guru_id);');
      await customStatement('CREATE INDEX IF NOT EXISTS idx_alamat_siswa_id ON alamat(siswa_id);');
    },
  );
}
