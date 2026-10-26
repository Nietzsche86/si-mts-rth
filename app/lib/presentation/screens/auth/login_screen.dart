import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onOpenPairing;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onOpenPairing,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialLockoutAndCachedUser();
  }

  Future<void> _checkInitialLockoutAndCachedUser() async {
    final authRepo = ref.read(authRepoProvider);
    final remainingSec = await authRepo.getRemainingLockoutSeconds();
    if (remainingSec > 0 && mounted) {
      _startLockoutCountdown(remainingSec);
    }

    final cachedUsername = await authRepo.storage.read(key: 'auth_username');
    if (cachedUsername != null && cachedUsername.isNotEmpty && mounted) {
      setState(() {
        _usernameController.text = cachedUsername;
      });
    }
  }

  void _startLockoutCountdown(int seconds) {
    setState(() {
      _lockoutSeconds = seconds;
      final minutes = (seconds / 60).ceil();
      _errorMessage =
          'Akun terkunci karena 5x percobaan gagal. Coba lagi dalam $minutes menit ($seconds detik).';
    });

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSeconds > 1) {
          _lockoutSeconds--;
          final minutes = (_lockoutSeconds / 60).ceil();
          _errorMessage =
              'Akun terkunci karena 5x percobaan gagal. Coba lagi dalam $minutes menit ($_lockoutSeconds detik).';
        } else {
          _lockoutSeconds = 0;
          _errorMessage = null;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();

    if (username.isEmpty || pin.length < 6) {
      setState(() {
        _errorMessage = 'Masukkan nama pengguna dan 6 digit PIN';
      });
      return;
    }

    if (_lockoutSeconds > 0) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepoProvider);
    final result = await authRepo.login(username: username, pin: pin);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess && result.session != null) {
      HapticFeedback.lightImpact();
      ref.read(currentUserProvider.notifier).state = result.session!;
      ref.read(isAuthenticatedProvider.notifier).state = true;
      widget.onLoginSuccess();
    } else if (result.isLockedOut) {
      HapticFeedback.heavyImpact();
      _startLockoutCountdown(result.lockoutRemainingSeconds);
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = result.errorMessage ?? 'Gagal masuk aplikasi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _lockoutSeconds > 0;

    return Scaffold(
      backgroundColor: AppTheme.sandGrey,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Madrasah Emblem / Brand Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Icon(
                      Icons.mosque_outlined,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header Texts
                  const Text(
                    'MTs Roudhotut Thowalib',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Aplikasi Manajemen Nilai & Siswa Terpadu',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Offline-First Badge Pill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 13, color: AppTheme.emeraldPrimary),
                          SizedBox(width: 5),
                          Text(
                            'Offline-Ready • Keystore',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.emeraldPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Card Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLocked ? Icons.lock_clock_rounded : Icons.error_outline,
                                  size: 20,
                                  color: const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF991B1B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Username Field
                        const Text(
                          'Nama Pengguna / NIP',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _usernameController,
                          enabled: !isLocked && !_isLoading,
                          decoration: const InputDecoration(
                            hintText: 'Contoh: guru_dahlan',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PIN Field
                        const Text(
                          'PIN Keamanan (6 Digit)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _pinController,
                          enabled: !isLocked && !_isLoading,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          style: const TextStyle(letterSpacing: 8, fontSize: 18, fontWeight: FontWeight.w700),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            hintText: '••••••',
                            counterText: '',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Tombol Masuk
                        ElevatedButton(
                          onPressed: (_isLoading || isLocked) ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(isLocked ? 'Terkunci ($_lockoutSeconds detik)' : 'Masuk Aplikasi'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol Pairing QR
                  OutlinedButton.icon(
                    onPressed: widget.onOpenPairing,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                    label: const Text('Pindai QR Server Operator'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.emeraldPrimary),
                      foregroundColor: AppTheme.emeraldPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
