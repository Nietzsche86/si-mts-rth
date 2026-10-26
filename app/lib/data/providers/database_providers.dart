import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';
import '../db/database_seeder.dart';
import '../sync/outbox_manager.dart';
import '../repositories/siswa_repository.dart';
import '../repositories/penilaian_repository.dart';
import '../repositories/absensi_repository.dart';
import '../repositories/rombel_repository.dart';
import '../repositories/pengampu_repository.dart';

/// Membuka koneksi database SQLite fisik atau in-memory fallback
LazyDatabase openDatabaseConnection() {
  return LazyDatabase(() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'madrasah.sqlite'));
      return NativeDatabase.createInBackground(file);
    } catch (e) {
      // Fallback ke in-memory jika path_provider tidak tersedia (misal saat testing)
      debugPrint('[Database] Fallback to NativeDatabase.memory due to: $e');
      return NativeDatabase.memory();
    }
  });
}

/// Provider Database Tunggal (Singleton)
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openDatabaseConnection());
  // Jalankan seeder data awal secara asynchronous
  DatabaseSeeder.seedInitialData(db);
  ref.onDispose(() => db.close());
  return db;
});

/// Provider Outbox Manager
final outboxManagerProvider = Provider<OutboxManager>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OutboxManager(db);
});

/// Provider Repositori Siswa
final siswaRepoProvider = Provider<SiswaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxManagerProvider);
  return SiswaRepository(db, outbox);
});

/// Provider Repositori Penilaian
final penilaianRepoProvider = Provider<PenilaianRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxManagerProvider);
  return PenilaianRepository(db, outbox);
});

/// Provider Repositori Absensi
final absensiRepoProvider = Provider<AbsensiRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxManagerProvider);
  return AbsensiRepository(db, outbox);
});

/// Provider Repositori Rombel
final rombelRepoProvider = Provider<RombelRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxManagerProvider);
  return RombelRepository(db, outbox);
});

/// Provider Repositori Pengampu
final pengampuRepoProvider = Provider<PengampuRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final outbox = ref.watch(outboxManagerProvider);
  return PengampuRepository(db, outbox);
});

/// Device ID perangkat
final activeDeviceIdProvider = Provider<String>((ref) => 'mobile-dev-001');

/// Model Sesi Pengguna Aktif
class CurrentUserSession {
  final String userId;
  final String username;
  final String role; // 'admin' | 'guru' | 'kepala'
  final String? guruId;
  final String namaGuru;
  final String? rombelWaliId;
  final String rombelWaliNama;

  const CurrentUserSession({
    required this.userId,
    required this.username,
    required this.role,
    this.guruId,
    required this.namaGuru,
    this.rombelWaliId,
    this.rombelWaliNama = '',
  });

  bool get isWaliKelas => rombelWaliId != null && rombelWaliId!.isNotEmpty;
  bool get isAdmin => role == 'admin';
}

/// Provider Pengguna Aktif (Default: Guru Dahlan, Wali Kelas 7A)
final currentUserProvider = StateProvider<CurrentUserSession>((ref) {
  return const CurrentUserSession(
    userId: 'user-002',
    username: 'guru_dahlan',
    role: 'guru',
    guruId: 'guru-001',
    namaGuru: 'Drs. H. Ahmad Dahlan, M.Pd.I',
    rombelWaliId: 'rombel-7a',
    rombelWaliNama: '7A',
  );
});

/// Model Info Semester Aktif
class ActiveSemesterInfo {
  final String semesterId;
  final String tahunAjaranId;
  final String tahunAjaranNama; // "2026/2027"
  final String semesterNama; // "Ganjil"
  final bool dikunci;

  const ActiveSemesterInfo({
    required this.semesterId,
    required this.tahunAjaranId,
    required this.tahunAjaranNama,
    required this.semesterNama,
    this.dikunci = false,
  });
}

/// Provider Semester Aktif
final activeSemesterProvider = StateProvider<ActiveSemesterInfo>((ref) {
  return const ActiveSemesterInfo(
    semesterId: 'sem-2026-ganjil',
    tahunAjaranId: 'ta-2026-2027',
    tahunAjaranNama: '2026/2027',
    semesterNama: 'Semester Ganjil',
    dikunci: false,
  );
});

/// Stream jumlah antrean outbox pending secara reaktif
final pendingOutboxCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final countExp = db.outbox.localSeq.count();
  final query = db.selectOnly(db.outbox)..addColumns([countExp]);
  return query.watchSingle().map((row) => row.read(countExp) ?? 0);
});

/// Provider Ringkasan Kelas Saya (Beranda)
final kelasSayaSummaryProvider = FutureProvider.autoDispose<List<PengampuSummaryItem>>((ref) async {
  final pengampuRepo = ref.watch(pengampuRepoProvider);
  final user = ref.watch(currentUserProvider);
  final semester = ref.watch(activeSemesterProvider);

  if (user.guruId == null) return [];
  return await pengampuRepo.getPengampuSummaryForGuru(
    guruId: user.guruId!,
    semesterId: semester.semesterId,
  );
});
