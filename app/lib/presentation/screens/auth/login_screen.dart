import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onOpenPairing;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onOpenPairing,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Simulasi verifikasi lokal cepat
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _isLoading = false;
    });

    HapticFeedback.lightImpact();
    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.mintSurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.emeraldPrimary),
                            SizedBox(width: 6),
                            Text(
                              'Offline-Ready • SQLCipher Terenkripsi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.emeraldPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
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
                          decoration: const InputDecoration(
                            hintText: 'Contoh: ahmad_faiz',
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
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Masuk Aplikasi'),
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
