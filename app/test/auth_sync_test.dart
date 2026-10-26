import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/security/secure_storage_service.dart';
import 'package:app/data/db/app_database.dart';
import 'package:app/data/db/database_seeder.dart';
import 'package:app/data/providers/database_providers.dart';
import 'package:app/data/repositories/auth_repository.dart';
import 'package:app/data/sync/dio_sync_client.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/presentation/screens/auth/login_screen.dart';
import 'package:app/presentation/screens/sync/sync_pairing_screen.dart';

/// Implementasi storage in-memory untuk testing
class TestSecureStorage implements SecureStorageInterface {
  final Map<String, String> data = {};

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<String?> read({required String key}) async {
    return data[key];
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    data.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TestSecureStorage storage;
  late Dio testDio;
  late AuthRepository authRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder.seedInitialData(db);
    storage = TestSecureStorage();
    testDio = Dio();
    authRepo = AuthRepository(
      db: db,
      storage: storage,
      dio: testDio,
      deviceId: 'test-device-001',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Checkpoint 3.1: Keystore PIN Cache & Offline Authentication Tests', () {
    test('PIN Hashing & Verifikasi Keamanan', () {
      final hash1 = SecureStorageService.hashPin('123456');
      final hash2 = SecureStorageService.hashPin('123456');
      final hashWrong = SecureStorageService.hashPin('654321');

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashWrong)));

      expect(SecureStorageService.verifyPin('123456', hash1), isTrue);
      expect(SecureStorageService.verifyPin('999999', hash1), isFalse);
    });

    test('Login Offline Awal menggunakan Akun Seeder', () async {
      // Akun guru_dahlan di SQLite lokal seeder
      final result = await authRepo.login(
        username: 'guru_dahlan',
        pin: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isOffline, isTrue);
      expect(result.session, isNotNull);
      expect(result.session!.username, equals('guru_dahlan'));
      expect(result.session!.guruId, equals('guru-001'));
      expect(result.session!.namaGuru, equals('Drs. H. Ahmad Dahlan, M.Pd.I'));
      expect(result.session!.isWaliKelas, isTrue);
      expect(result.session!.rombelWaliNama, equals('7A'));

      // Kredensial tersimpan di secure storage untuk login selanjutnya
      final cachedUser = await storage.read(key: AuthRepository.keyUsername);
      final cachedPinHash = await storage.read(key: AuthRepository.keyPinHash);
      expect(cachedUser, equals('guru_dahlan'));
      expect(cachedPinHash, isNotNull);
    });

    test('Login Offline Kedua menggunakan Hash PIN di Keystore', () async {
      // Login pertama untuk menyimpan cache
      await authRepo.login(username: 'guru_dahlan', pin: '123456');

      // Login kedua dengan PIN yang sama harus sukses via cachedPinHash
      final secondResult = await authRepo.login(
        username: 'guru_dahlan',
        pin: '123456',
      );

      expect(secondResult.isSuccess, isTrue);
      expect(secondResult.isOffline, isTrue);
      expect(secondResult.session?.username, equals('guru_dahlan'));
    });

    test('Login Gagal & Proteksi Brute-Force Lockout 5x Salah', () async {
      // Percobaan 1 salah
      var res = await authRepo.login(username: 'guru_dahlan', pin: '000000');
      expect(res.isSuccess, isFalse);
      expect(res.isLockedOut, isFalse);
      expect(res.errorMessage, contains('Sisa kesempatan: 4'));

      // Percobaan 2 salah
      res = await authRepo.login(username: 'guru_dahlan', pin: '000001');
      expect(res.errorMessage, contains('Sisa kesempatan: 3'));

      // Percobaan 3 salah
      res = await authRepo.login(username: 'guru_dahlan', pin: '000002');
      expect(res.errorMessage, contains('Sisa kesempatan: 2'));

      // Percobaan 4 salah
      res = await authRepo.login(username: 'guru_dahlan', pin: '000003');
      expect(res.errorMessage, contains('Sisa kesempatan: 1'));

      // Percobaan 5 salah: Aplikasi harus terkunci!
      res = await authRepo.login(username: 'guru_dahlan', pin: '000004');
      expect(res.isSuccess, isFalse);
      expect(res.isLockedOut, isTrue);
      expect(res.lockoutRemainingSeconds, greaterThan(0));
      expect(res.errorMessage, contains('terkunci'));

      // Percobaan 6 saat terkunci: langsung ditolak tanpa memeriksa kredensial
      final lockedRes = await authRepo.login(username: 'guru_dahlan', pin: '123456');
      expect(lockedRes.isSuccess, isFalse);
      expect(lockedRes.isLockedOut, isTrue);
    });

    test('Penyimpanan Konfigurasi Pairing Server & Logout', () async {
      await authRepo.saveServerPairing(
        url: 'http://192.168.1.150:8000',
        fingerprint: 'SHA256:12:34:56:78:90',
      );

      final pairing = await authRepo.getServerPairing();
      expect(pairing['server_url'], equals('http://192.168.1.150:8000'));
      expect(pairing['server_fingerprint'], equals('SHA256:12:34:56:78:90'));

      // Login lalu logout
      await authRepo.login(username: 'guru_dahlan', pin: '123456');
      expect(await storage.read(key: AuthRepository.keyToken), isNotNull);

      await authRepo.logout();
      expect(await storage.read(key: AuthRepository.keyToken), isNull);
      expect(await storage.read(key: AuthRepository.keyUserId), isNull);
    });
  });

  group('Checkpoint 3.2: QR Server Pairing & DioSyncClient.sync() Tests', () {
    test('DioSyncClient.sync() siklus penuh Push + Pull + Local GC', () async {
      final outbox = OutboxManager(db);
      final syncDio = Dio();

      // Tambahkan item dummy ke outbox
      final seq = await outbox.enqueue(
        tabel: 'nilai',
        recordId: 'nilai-sync-test-01',
        operasi: 'UPSERT',
        payload: {
          'id': 'nilai-sync-test-01',
          'keanggotaan_id': 'keanggotaan-7a-001',
          'mapel_id': 'mapel-arab-001',
          'semester_id': 'sem-2026-ganjil',
          'jenis_nilai_id': 'jenis-uh',
          'urutan_ke': 1,
          'nilai_angka': 88.0,
          'created_at': 1710000000000,
          'updated_at': 1710000000000,
          'deleted': 0,
          'device_id': 'test-dev',
        },
      );

      expect(await outbox.getPendingCount(), equals(1));

      // Mock respons HTTP Push dan Pull via Interceptor
      syncDio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('/sync/push')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'server_time': DateTime.now().millisecondsSinceEpoch,
                    'results': [
                      {
                        'local_seq': seq,
                        'table': 'nilai',
                        'row_id': 'nilai-sync-test-01',
                        'status': 'APPLIED',
                        'server_seq': 101,
                      }
                    ],
                  },
                ),
              );
            } else if (options.path.contains('/sync/pull')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'server_seq_max': 101,
                    'items': [],
                    'active_scope': {
                      'allowed_keanggotaan_ids': ['keanggotaan-7a-001'],
                    },
                  },
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final client = DioSyncClient(dio: syncDio, db: db, outbox: outbox);

      final syncResult = await client.sync(
        baseUrl: 'http://192.168.1.100:8000',
        token: 'test-token',
        deviceId: 'test-dev',
      );

      expect(syncResult.isSuccess, isTrue);
      expect(syncResult.pushSummary.applied, equals(1));
      expect(await outbox.getPendingCount(), equals(0));

      // Verifikasi timestamp tersimpan di sync_state
      final syncStateRow = await (db.select(db.syncState)
            ..where((t) => t.kunci.equals('last_sync_timestamp')))
          .getSingleOrNull();
      expect(syncStateRow, isNotNull);
      expect(syncStateRow!.nilai.isNotEmpty, isTrue);
    });

    testWidgets('Layar LoginScreen: input kredensial dan pemicu login', (WidgetTester tester) async {
      bool loginSuccessTriggered = false;
      bool pairingTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            secureStorageProvider.overrideWithValue(storage),
          ],
          child: MaterialApp(
            home: LoginScreen(
              onLoginSuccess: () {
                loginSuccessTriggered = true;
              },
              onOpenPairing: () {
                pairingTriggered = true;
              },
            ),
          ),
        ),
      );

      // Verifikasi komponen form login tampil
      expect(find.text('MTs Roudhotut Thowalib'), findsOneWidget);
      expect(find.text('Nama Pengguna / NIP'), findsOneWidget);
      expect(find.text('PIN Keamanan (6 Digit)'), findsOneWidget);

      // Masukkan username & PIN yang salah
      await tester.enterText(find.byType(TextField).first, 'guru_dahlan');
      await tester.enterText(find.byType(TextField).last, '999999');
      await tester.ensureVisible(find.text('Masuk Aplikasi'));
      await tester.tap(find.text('Masuk Aplikasi'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nama pengguna atau PIN salah'), findsOneWidget);
      expect(loginSuccessTriggered, isFalse);

      // Masukkan PIN yang benar
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.ensureVisible(find.text('Masuk Aplikasi'));
      await tester.tap(find.text('Masuk Aplikasi'));
      await tester.pumpAndSettle();

      expect(loginSuccessTriggered, isTrue);

      // Cek tombol pairing
      await tester.ensureVisible(find.text('Pindai QR Server Operator'));
      await tester.tap(find.text('Pindai QR Server Operator'));
      await tester.pumpAndSettle();
      expect(pairingTriggered, isTrue);
    });

    testWidgets('Layar SyncPairingScreen: dialog QR payload parser', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            secureStorageProvider.overrideWithValue(storage),
            pendingOutboxCountProvider.overrideWith((ref) => Stream.value(0)),
            lastSyncTimestampProvider.overrideWith((ref) => Stream.value(DateTime.now())),
          ],
          child: MaterialApp(
            home: SyncPairingScreen(
              pendingOutboxCount: 0,
              onTriggerSync: () {},
            ),
          ),
        ),
      );

      expect(find.text('Sinkronisasi & Sambungan Server'), findsOneWidget);
      expect(find.text('Semua Data Tersinkronisasi Penuh'), findsOneWidget);

      // Buka dialog QR Pairing
      await tester.tap(find.text('Pindai / Tempel QR Pairing Operator'));
      await tester.pumpAndSettle();

      expect(find.text('Pairing QR Server Operator'), findsOneWidget);

      // Terapkan contoh default
      await tester.tap(find.text('Contoh Default (Port 8000)'));
      await tester.pump();

      await tester.tap(find.text('Terapkan Pairing'));
      await tester.pumpAndSettle();

      // Verifikasi snackbar berhasil dan IP controller diperbarui
      expect(find.textContaining('192.168.1.100'), findsWidgets);
    });
  });
}
