import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/auth_repository.dart';

class SyncPairingScreen extends ConsumerStatefulWidget {
  final int pendingOutboxCount;
  final VoidCallback onTriggerSync;

  const SyncPairingScreen({
    super.key,
    this.pendingOutboxCount = 0,
    required this.onTriggerSync,
  });

  @override
  ConsumerState<SyncPairingScreen> createState() => _SyncPairingScreenState();
}

class _SyncPairingScreenState extends ConsumerState<SyncPairingScreen> {
  final _serverIpController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '8000');
  String? _fingerprint;
  bool _isSyncing = false;
  String? _syncStatusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPairing();
  }

  Future<void> _loadExistingPairing() async {
    final authRepo = ref.read(authRepoProvider);
    final pairing = await authRepo.getServerPairing();

    if (pairing.containsKey('server_url') && mounted) {
      final url = pairing['server_url']!;
      try {
        final uri = Uri.parse(url);
        if (uri.host.isNotEmpty) {
          _serverIpController.text = uri.host;
        }
        if (uri.hasPort) {
          _portController.text = uri.port.toString();
        }
      } catch (_) {}
    }

    if (pairing.containsKey('server_fingerprint') && mounted) {
      setState(() {
        _fingerprint = pairing['server_fingerprint'];
      });
    }
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    super.dispose();
  }

  String _constructBaseUrl() {
    final ip = _serverIpController.text.trim();
    final port = _portController.text.trim();
    return 'http://$ip:$port';
  }

  Future<void> _saveManualConfig() async {
    final ip = _serverIpController.text.trim();
    final port = _portController.text.trim();
    if (ip.isEmpty) return;

    final authRepo = ref.read(authRepoProvider);
    final url = 'http://$ip:$port';
    await authRepo.saveServerPairing(url: url, fingerprint: _fingerprint);

    if (mounted) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Konfigurasi server berhasil disimpan: $url'),
          backgroundColor: AppTheme.emeraldPrimary,
        ),
      );
    }
  }

  void _showQrPairingDialog() {
    final qrTextController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppTheme.emeraldPrimary),
            SizedBox(width: 8),
            Text('Pairing QR Server Operator', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arahkan kamera ke layar server operator atau tempel teks payload QR pairing di bawah ini:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qrTextController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '{"url": "http://192.168.1.100:8000", "fingerprint": "SHA256:..."}',
                labelText: 'Payload JSON QR',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Contoh Default (Port 8000)', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    qrTextController.text =
                        '{"url": "http://192.168.1.100:8000", "fingerprint": "SHA256:7B:3A:C1:90:E2"}';
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = qrTextController.text.trim();
              if (raw.isNotEmpty) {
                await _processQrPayload(raw);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Terapkan Pairing'),
          ),
        ],
      ),
    );
  }

  Future<void> _processQrPayload(String raw) async {
    String parsedUrl = raw;
    String? parsedFingerprint;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded.containsKey('url')) {
        parsedUrl = decoded['url'].toString();
      }
      if (decoded.containsKey('fingerprint')) {
        parsedFingerprint = decoded['fingerprint'].toString();
      }
    } catch (_) {
      // Input berupa teks URL biasa
    }

    try {
      final uri = Uri.parse(parsedUrl);
      if (uri.host.isNotEmpty) {
        _serverIpController.text = uri.host;
      }
      if (uri.hasPort) {
        _portController.text = uri.port.toString();
      }
    } catch (_) {}

    setState(() {
      _fingerprint = parsedFingerprint;
    });

    final authRepo = ref.read(authRepoProvider);
    await authRepo.saveServerPairing(
      url: parsedUrl,
      fingerprint: parsedFingerprint,
    );

    if (mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server operator berhasil terhubung: $parsedUrl'),
          backgroundColor: AppTheme.emeraldPrimary,
        ),
      );
    }
  }

  void _runSync() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSyncing = true;
      _syncStatusMessage = 'Menghubungkan ke server operator...';
      _isSuccess = false;
    });

    final baseUrl = _constructBaseUrl();
    final authRepo = ref.read(authRepoProvider);
    final syncClient = ref.read(syncClientProvider);
    final deviceId = ref.read(activeDeviceIdProvider);

    // Ambil auth token dari storage
    String token = await authRepo.storage.read(key: AuthRepository.keyToken) ?? 'offline-token';

    setState(() {
      _syncStatusMessage = 'Mengirim antrean perubahan lokal (outbox)...';
    });

    final result = await syncClient.sync(
      baseUrl: baseUrl,
      token: token,
      deviceId: deviceId,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      HapticFeedback.lightImpact();
      setState(() {
        _isSyncing = false;
        _isSuccess = true;
        _syncStatusMessage =
            'Sinkronisasi Berhasil!\n• ${result.pushSummary.applied} perubahan lokal terkirim\n• ${result.pulledCount} data baru ditarik dari server';
      });
      widget.onTriggerSync();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSyncing = false;
        _isSuccess = false;
        _syncStatusMessage =
            'Gagal tersambung ke server operator di $baseUrl.\nPastikan server laptop aktif dan terhubung ke WiFi yang sama.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncAsync = ref.watch(lastSyncTimestampProvider);
    final lastSyncTime = lastSyncAsync.asData?.value;
    String lastSyncText = 'Belum pernah disinkronkan';
    if (lastSyncTime != null) {
      final diff = DateTime.now().difference(lastSyncTime);
      if (diff.inMinutes < 60) {
        lastSyncText = '${diff.inMinutes} menit yang lalu';
      } else if (diff.inHours < 24) {
        lastSyncText = '${diff.inHours} jam yang lalu';
      } else {
        lastSyncText = DateFormat('dd MMM yyyy, HH:mm').format(lastSyncTime.toLocal());
      }
    }

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
                            color: widget.pendingOutboxCount > 0
                                ? const Color(0xFF92400E)
                                : AppTheme.emeraldPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.pendingOutboxCount > 0
                              ? 'Tersimpan aman di SQLCipher HP, siap dikirim ke laptop operator saat terhubung WiFi.'
                              : 'Terakhir disinkronkan: $lastSyncText',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.pendingOutboxCount > 0
                                ? const Color(0xFFB45309)
                                : const Color(0xFF047857),
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
                    onChanged: (_) => _saveManualConfig(),
                    decoration: const InputDecoration(
                      labelText: 'IP Server Lokal Operator',
                      hintText: '192.168.1.xxx',
                      prefixIcon: Icon(Icons.lan_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _portController,
                    onChanged: (_) => _saveManualConfig(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port Server',
                      hintText: '8000',
                      prefixIcon: Icon(Icons.numbers_outlined, size: 20),
                    ),
                  ),
                  if (_fingerprint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Sertifikat TLS Fingerprint: $_fingerprint',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // QR Scan Button
                  OutlinedButton.icon(
                    onPressed: _showQrPairingDialog,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Pindai / Tempel QR Pairing Operator'),
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
                  color: _isSuccess ? AppTheme.mintSurface : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline,
                      color: _isSuccess ? AppTheme.emeraldPrimary : const Color(0xFFDC2626),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _syncStatusMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _isSuccess ? AppTheme.emeraldPrimary : const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
