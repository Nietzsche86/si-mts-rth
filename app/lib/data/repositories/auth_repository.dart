import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/security/secure_storage_service.dart';
import '../db/app_database.dart';
import '../providers/database_providers.dart';

/// Hasil proses login autentikasi online/offline
class LoginResult {
  final bool isSuccess;
  final CurrentUserSession? session;
  final String? token;
  final bool isOffline;
  final bool isLockedOut;
  final int lockoutRemainingSeconds;
  final String? errorMessage;

  const LoginResult({
    required this.isSuccess,
    this.session,
    this.token,
    this.isOffline = false,
    this.isLockedOut = false,
    this.lockoutRemainingSeconds = 0,
    this.errorMessage,
  });

  factory LoginResult.success({
    required CurrentUserSession session,
    String? token,
    bool isOffline = false,
  }) =>
      LoginResult(
        isSuccess: true,
        session: session,
        token: token,
        isOffline: isOffline,
      );

  factory LoginResult.lockedOut({
    required int remainingSeconds,
    String? message,
  }) {
    final minutes = (remainingSeconds / 60).ceil();
    return LoginResult(
      isSuccess: false,
      isLockedOut: true,
      lockoutRemainingSeconds: remainingSeconds,
      errorMessage: message ??
          'Akun terkunci karena 5x percobaan gagal. Coba lagi dalam $minutes menit.',
    );
  }

  factory LoginResult.failure(String message) => LoginResult(
        isSuccess: false,
        errorMessage: message,
      );
}

/// Repositori Autentikasi Offline-First dengan Penyimpanan Kredensial Terenkripsi di Android Keystore
class AuthRepository {
  final AppDatabase db;
  final SecureStorageInterface storage;
  final Dio dio;
  final String deviceId;

  static const String keyToken = 'auth_token';
  static const String keyUserId = 'auth_user_id';
  static const String keyUsername = 'auth_username';
  static const String keyGuruId = 'auth_guru_id';
  static const String keyRoles = 'auth_roles';
  static const String keyPinHash = 'auth_pin_hash';
  static const String keyFailedAttempts = 'auth_failed_attempts';
  static const String keyLockedUntil = 'auth_locked_until';

  AuthRepository({
    required this.db,
    required this.storage,
    required this.dio,
    this.deviceId = 'mobile-dev-001',
  });

  /// Login online pertama kali atau fallback verifikasi offline dengan proteksi 5x gagal
  Future<LoginResult> login({
    required String username,
    required String pin,
    String? overrideServerUrl,
  }) async {
    final cleanUsername = username.trim();
    final cleanPin = pin.trim();

    if (cleanUsername.isEmpty || cleanPin.length < 6) {
      return LoginResult.failure('Nama pengguna dan 6 digit PIN wajib diisi');
    }

    // 1. Periksa apakah perangkat sedang dalam masa hukuman lockout (5x salah)
    final now = DateTime.now().millisecondsSinceEpoch;
    final lockedUntilStr = await storage.read(key: keyLockedUntil);
    if (lockedUntilStr != null) {
      final lockedUntil = int.tryParse(lockedUntilStr) ?? 0;
      if (lockedUntil > now) {
        final remainingSec = ((lockedUntil - now) / 1000).ceil();
        return LoginResult.lockedOut(remainingSeconds: remainingSec);
      } else {
        // Masa lockout telah selesai: reset percobaan gagal
        await storage.delete(key: keyLockedUntil);
        await storage.write(key: keyFailedAttempts, value: '0');
      }
    }

    // 2. Dapatkan URL server dari parameter atau dari tabel sync_state
    String? serverUrl = overrideServerUrl;
    if (serverUrl == null || serverUrl.isEmpty) {
      final serverUrlRow = await (db.select(db.syncState)
            ..where((t) => t.kunci.equals('server_url')))
          .getSingleOrNull();
      serverUrl = serverUrlRow?.nilai;
    }

    // 3. Coba Login Online ke Server FastAPI jika URL tersedia
    if (serverUrl != null && serverUrl.isNotEmpty) {
      try {
        final response = await dio.post(
          '${serverUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1/auth/login',
          data: {
            'username': cleanUsername,
            'pin': cleanPin,
            'device_id': deviceId,
            'nama_perangkat': 'Android MTs App',
            'versi_app': '1.0.0',
          },
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final token = data['access_token'] as String;
          final userId = data['user_id'] as String;
          final guruId = data['guru_id'] as String?;
          final roles = (data['roles'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              ['guru'];

          // Reset status kegagalan login
          await _resetLockout();

          // Simpan token JWT dan PIN Hash ke Android Keystore
          await _cacheCredentials(
            token: token,
            userId: userId,
            username: cleanUsername,
            guruId: guruId,
            roles: roles,
            pin: cleanPin,
          );

          final session = await _buildSession(
            userId: userId,
            username: cleanUsername,
            roles: roles,
            guruId: guruId,
          );

          return LoginResult.success(
            session: session,
            token: token,
            isOffline: false,
          );
        }
      } on DioException catch (e) {
        if (e.response != null && e.response?.statusCode == 400) {
          final resData = e.response?.data;
          if (resData is Map && resData.containsKey('detail')) {
            return LoginResult.failure(resData['detail'].toString());
          }
        }
        debugPrint(
            '[AuthRepository] Gagal login online (${e.message}), beralih ke verifikasi offline...');
      } catch (e) {
        debugPrint('[AuthRepository] Error tak terduga online: $e');
      }
    }

    // 4. Fallback Verifikasi Offline
    return await _verifyOffline(
      username: cleanUsername,
      pin: cleanPin,
    );
  }

  /// Verifikasi PIN lokal di HP terhadap hash yang tersimpan di Keystore
  Future<LoginResult> _verifyOffline({
    required String username,
    required String pin,
  }) async {
    final cachedUsername = await storage.read(key: keyUsername);
    final cachedPinHash = await storage.read(key: keyPinHash);

    bool pinValid = false;
    String? userId;
    String? guruId;
    List<String> roles = ['guru'];

    if (cachedUsername != null &&
        cachedUsername.toLowerCase() == username.toLowerCase() &&
        cachedPinHash != null) {
      // Akun sudah pernah login online sebelumnya
      pinValid = SecureStorageService.verifyPin(pin, cachedPinHash);
      userId = await storage.read(key: keyUserId);
      guruId = await storage.read(key: keyGuruId);
      final rolesJson = await storage.read(key: keyRoles);
      if (rolesJson != null) {
        try {
          roles = (jsonDecode(rolesJson) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    } else {
      // Fallback ke tabel user lokal SQLite jika belum pernah login online
      final localUser = await (db.select(db.user)
            ..where((u) => u.username.equals(username)))
          .getSingleOrNull();

      if (localUser != null) {
        if (localUser.aktif == 0) {
          return LoginResult.failure('Akun dinonaktifkan oleh administrator');
        }
        // Default initial offline PIN: 123456
        if (pin == '123456') {
          pinValid = true;
          userId = localUser.id;
          guruId = localUser.guruId;

          final userRoles = await (db.select(db.userRole)
                ..where((r) => r.userId.equals(localUser.id)))
              .get();
          if (userRoles.isNotEmpty) {
            roles = userRoles.map((r) => r.role).toList();
          }

          // Otomatis simpan ke secure storage untuk sesi selanjutnya
          await _cacheCredentials(
            token: 'offline-token-${localUser.id}',
            userId: localUser.id,
            username: localUser.username,
            guruId: localUser.guruId,
            roles: roles,
            pin: pin,
          );
        }
      }
    }

    if (pinValid && userId != null) {
      await _resetLockout();
      final token = await storage.read(key: keyToken);
      final session = await _buildSession(
        userId: userId,
        username: username,
        roles: roles,
        guruId: guruId,
      );
      return LoginResult.success(
        session: session,
        token: token,
        isOffline: true,
      );
    } else {
      return await _handleFailedAttempt();
    }
  }

  /// Menangani percobaan PIN yang salah dan mengunci setelah 5x gagal
  Future<LoginResult> _handleFailedAttempt() async {
    final attemptsStr = await storage.read(key: keyFailedAttempts);
    final attempts = (int.tryParse(attemptsStr ?? '0') ?? 0) + 1;
    await storage.write(key: keyFailedAttempts, value: attempts.toString());

    if (attempts >= 5) {
      const lockoutDurationMs = 15 * 60 * 1000; // 15 menit
      final lockedUntil = DateTime.now().millisecondsSinceEpoch + lockoutDurationMs;
      await storage.write(key: keyLockedUntil, value: lockedUntil.toString());
      return LoginResult.lockedOut(
        remainingSeconds: 15 * 60,
        message: 'PIN salah 5 kali berturut-turut. Aplikasi terkunci selama 15 menit.',
      );
    } else {
      final sisa = 5 - attempts;
      return LoginResult.failure(
        'Nama pengguna atau PIN salah. Sisa kesempatan: $sisa kali.',
      );
    }
  }

  /// Reset status lockout dan jumlah gagal login
  Future<void> _resetLockout() async {
    await storage.write(key: keyFailedAttempts, value: '0');
    await storage.delete(key: keyLockedUntil);
  }

  /// Menyimpan kredensial ke penyimpanan aman terenkripsi Keystore
  Future<void> _cacheCredentials({
    required String token,
    required String userId,
    required String username,
    String? guruId,
    required List<String> roles,
    required String pin,
  }) async {
    await storage.write(key: keyToken, value: token);
    await storage.write(key: keyUserId, value: userId);
    await storage.write(key: keyUsername, value: username);
    if (guruId != null) {
      await storage.write(key: keyGuruId, value: guruId);
    }
    await storage.write(key: keyRoles, value: jsonEncode(roles));
    final pinHash = SecureStorageService.hashPin(pin);
    await storage.write(key: keyPinHash, value: pinHash);
  }

  /// Membangun objek CurrentUserSession dari data guru dan rombel SQLite
  Future<CurrentUserSession> _buildSession({
    required String userId,
    required String username,
    required List<String> roles,
    String? guruId,
  }) async {
    String namaGuru = username;
    String? rombelWaliId;
    String rombelWaliNama = '';

    if (guruId != null) {
      final guruRow = await (db.select(db.guru)
            ..where((g) => g.id.equals(guruId)))
          .getSingleOrNull();
      if (guruRow != null) {
        namaGuru = guruRow.namaLengkap;
      }

      // Periksa apakah guru adalah Wali Kelas di salah satu rombel aktif
      final rombelRow = await (db.select(db.rombel)
            ..where((r) => r.waliGuruId.equals(guruId) & r.deleted.equals(0)))
          .getSingleOrNull();
      if (rombelRow != null) {
        rombelWaliId = rombelRow.id;
        rombelWaliNama = rombelRow.nama;
      }
    }

    final primaryRole = roles.contains('admin')
        ? 'admin'
        : (roles.contains('kepala') ? 'kepala' : 'guru');

    return CurrentUserSession(
      userId: userId,
      username: username,
      role: primaryRole,
      guruId: guruId,
      namaGuru: namaGuru,
      rombelWaliId: rombelWaliId,
      rombelWaliNama: rombelWaliNama,
    );
  }

  /// Memeriksa apakah ada sesi login aktif
  Future<CurrentUserSession?> getCachedSession() async {
    final userId = await storage.read(key: keyUserId);
    final username = await storage.read(key: keyUsername);
    if (userId == null || username == null) return null;

    final guruId = await storage.read(key: keyGuruId);
    final rolesJson = await storage.read(key: keyRoles);
    List<String> roles = ['guru'];
    if (rolesJson != null) {
      try {
        roles = (jsonDecode(rolesJson) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      } catch (_) {}
    }

    return await _buildSession(
      userId: userId,
      username: username,
      roles: roles,
      guruId: guruId,
    );
  }

  /// Mendapatkan sisa detik masa lockout jika sedang terkunci
  Future<int> getRemainingLockoutSeconds() async {
    final lockedUntilStr = await storage.read(key: keyLockedUntil);
    if (lockedUntilStr == null) return 0;
    final lockedUntil = int.tryParse(lockedUntilStr) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lockedUntil <= now) {
      await storage.delete(key: keyLockedUntil);
      await storage.write(key: keyFailedAttempts, value: '0');
      return 0;
    }
    return ((lockedUntil - now) / 1000).ceil();
  }

  /// Menyimpan konfigurasi pairing server (URL & TLS fingerprint) ke sync_state
  Future<void> saveServerPairing({
    required String url,
    String? fingerprint,
  }) async {
    final cleanUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await db.into(db.syncState).insertOnConflictUpdate(
          SyncStateCompanion(
            kunci: const Value('server_url'),
            nilai: Value(cleanUrl),
          ),
        );

    if (fingerprint != null && fingerprint.isNotEmpty) {
      await db.into(db.syncState).insertOnConflictUpdate(
            SyncStateCompanion(
              kunci: const Value('server_fingerprint'),
              nilai: Value(fingerprint.trim()),
            ),
          );
    }
  }

  /// Mengambil data pairing server saat ini
  Future<Map<String, String>> getServerPairing() async {
    final rows = await (db.select(db.syncState)
          ..where((t) =>
              t.kunci.equals('server_url') | t.kunci.equals('server_fingerprint')))
        .get();

    final result = <String, String>{};
    for (final row in rows) {
      result[row.kunci] = row.nilai;
    }
    return result;
  }

  /// Logout: hapus token dan user aktif dari sesi
  Future<void> logout() async {
    await storage.delete(key: keyToken);
    await storage.delete(key: keyUserId);
  }
}
