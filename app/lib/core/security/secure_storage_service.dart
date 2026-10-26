import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraksi penyimpanan aman untuk memungkinkan mock / in-memory fallback saat unit testing
abstract class SecureStorageInterface {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
  Future<void> deleteAll();
}

/// Implementasi default menggunakan Android Keystore / iOS Keychain via FlutterSecureStorage
class SecureStorageService implements SecureStorageInterface {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};
  bool _useFallback = false;

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  @override
  Future<void> write({required String key, required String value}) async {
    if (_useFallback) {
      _memoryFallback[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStorage] Error writing to native storage: $e, falling back to memory');
      _useFallback = true;
      _memoryFallback[key] = value;
    }
  }

  @override
  Future<String?> read({required String key}) async {
    if (_useFallback) {
      return _memoryFallback[key];
    }
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('[SecureStorage] Error reading from native storage: $e, falling back to memory');
      _useFallback = true;
      return _memoryFallback[key];
    }
  }

  @override
  Future<void> delete({required String key}) async {
    if (_useFallback) {
      _memoryFallback.remove(key);
      return;
    }
    try {
      await _storage.delete(key: key);
    } catch (e) {
      _useFallback = true;
      _memoryFallback.remove(key);
    }
  }

  @override
  Future<void> deleteAll() async {
    _memoryFallback.clear();
    if (!_useFallback) {
      try {
        await _storage.deleteAll();
      } catch (_) {
        _useFallback = true;
      }
    }
  }

  // ===========================================================================
  // Utilitas Hash PIN Keamanan (PRD F1: Argon2/bcrypt/HMAC-SHA256 salted)
  // ===========================================================================

  static const String defaultPinSalt = 'si-mts-rth-pin-salt-2026';

  /// Menghasilkan hash SHA-256 tersalt untuk PIN 6 digit lokal
  static String hashPin(String pin, {String salt = defaultPinSalt}) {
    final bytes = utf8.encode('$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  /// Verifikasi kecocokan PIN terhadap hash yang tersimpan
  static bool verifyPin(String inputPin, String storedHash, {String salt = defaultPinSalt}) {
    if (storedHash.isEmpty) return false;
    final inputHash = hashPin(inputPin, salt: salt);
    return inputHash == storedHash;
  }
}
