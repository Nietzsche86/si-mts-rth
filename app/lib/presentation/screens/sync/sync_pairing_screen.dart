import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class SyncPairingScreen extends StatefulWidget {
  final int pendingOutboxCount;
  final VoidCallback onTriggerSync;

  const SyncPairingScreen({
    super.key,
    this.pendingOutboxCount = 0,
    required this.onTriggerSync,
  });

  @override
  State<SyncPairingScreen> createState() => _SyncPairingScreenState();
}

class _SyncPairingScreenState extends State<SyncPairingScreen> {
  final _serverIpController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '8000');
  bool _isSyncing = false;
  String? _syncStatusMessage;

  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _runSync() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = 'Mengirim antrean perubahan lokal...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _syncStatusMessage = 'Menarik pembaruan dari server operator...';
    });

    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _isSyncing = false;
      _syncStatusMessage = 'Sinkronisasi berhasil! Semua data termutakhirkan.';
    });

    widget.onTriggerSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sinkronisasi & Sambungan Server'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Outbox Pending Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.pendingOutboxCount > 0 ? const Color(0xFFFEF3C7) : AppTheme.mintSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.pendingOutboxCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.pendingOutboxCount > 0 ? Icons.outbox_rounded : Icons.cloud_done_rounded,
                    color: widget.pendingOutboxCount > 0 ? AppTheme.warmGold : AppTheme.emeraldPrimary,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pendingOutboxCount > 0
                              ? '${widget.pendingOutboxCount} Perubahan Menunggu Kirim'
                              : 'Semua Data Tersinkronisasi Penuh',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.pendingOutboxCount > 0 ? const Color(0xFF92400E) : AppTheme.emeraldPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.pendingOutboxCount > 0
                              ? 'Tersimpan aman di SQLCipher HP, siap dikirim ke laptop operator saat terhubung WiFi.'
                              : 'Terakhir disinkronkan: Hari ini',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.pendingOutboxCount > 0 ? const Color(0xFFB45309) : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pairing Configuration Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_tethering_rounded, color: AppTheme.emeraldPrimary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Konfigurasi Jaringan Server Operator',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverIpController,
                    decoration: const InputDecoration(
                      labelText: 'IP Server Lokal Operator',
                      hintText: '192.168.1.xxx',
                      prefixIcon: Icon(Icons.lan_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port Server',
                      hintText: '8000',
                      prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // QR Scan Button
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kamera siap memindai QR Code di layar laptop operator')),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Pindai QR Pairing di Layar Laptop'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.emeraldPrimary),
                      foregroundColor: AppTheme.emeraldPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sync Execution Button
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _runSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(_isSyncing ? 'Sedang Menyinkronkan...' : 'Sinkronkan Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emeraldPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            if (_syncStatusMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.sandGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  _syncStatusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
