import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/penilaian/input_nilai_screen.dart';
import 'presentation/screens/absensi/input_absensi_screen.dart';
import 'presentation/screens/siswa/siswa_form_screen.dart';
import 'presentation/screens/rombel/pindah_rombel_dialog.dart';
import 'presentation/screens/sync/sync_pairing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MTsApp()));
}

class MTsApp extends StatelessWidget {
  const MTsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTs Roudhotut Thowalib',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_mts.png',
              width: 34,
              height: 34,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.school,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MTs Roudhotut Thowalib',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Semester Ganjil 2026/2027',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            child: const Text(
              'Guru & Wali 7A',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Status Sinkronisasi Sticky (PRD F18 & UI Guideline 5.1)
          const SyncStatusBar(
            pendingCount: 2,
            lastSyncHours: 2,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                KelasSayaTab(),
                InputNilaiCepatTab(),
                AbsensiCepatTab(),
                PengaturanTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = idx);
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
            label: 'Kelas Saya',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note, color: AppColors.primary),
            label: 'Input Nilai',
          ),
          NavigationDestination(
            icon: Icon(Icons.how_to_reg_outlined),
            selectedIcon: Icon(Icons.how_to_reg, color: AppColors.primary),
            label: 'Absensi',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Sinkron & Status',
          ),
        ],
      ),
    );
  }
}

/// Banner Status Sinkronisasi Flat Sticky
class SyncStatusBar extends StatelessWidget {
  final int pendingCount;
  final int lastSyncHours;

  const SyncStatusBar({
    super.key,
    required this.pendingCount,
    required this.lastSyncHours,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData icon;
    String message;

    if (lastSyncHours >= 72) {
      bgColor = AppColors.dangerSoft;
      borderColor = AppColors.danger;
      textColor = AppColors.danger;
      icon = Icons.warning_amber_rounded;
      message = 'Peringatan: Belum sinkron > 72 jam! Hubungkan ke WiFi operator.';
    } else if (pendingCount > 0 || lastSyncHours >= 24) {
      bgColor = AppColors.warningSoft;
      borderColor = AppColors.warning;
      textColor = const Color(0xFF92400E);
      icon = Icons.cloud_queue_rounded;
      message = '$pendingCount perubahan belum tersinkron • Terakhir $lastSyncHours jam lalu';
    } else {
      bgColor = AppColors.primaryContainer;
      borderColor = AppColors.primary;
      textColor = AppColors.onPrimaryContainer;
      icon = Icons.check_circle_outline_rounded;
      message = 'Semua data tersinkron ke server laptop operator';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (pendingCount > 0)
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SyncPairingScreen(
                      pendingOutboxCount: pendingCount,
                      onTriggerSync: () {},
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              child: const Text('Sinkron'),
            ),
        ],
      ),
    );
  }
}

/// Tab 1: Kelas Saya
class KelasSayaTab extends StatelessWidget {
  const KelasSayaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildClassCard(
          context,
          rombel: '7A',
          mapel: 'Bahasa Arab',
          peran: 'Utama',
          isUtama: true,
          cakupanText: 'Seluruh kelas • 32 Siswa',
          progressText: 'UH 2 terisi 30/32 siswa — 94%',
          progressValue: 0.94,
        ),
        const SizedBox(height: 12),
        _buildClassCard(
          context,
          rombel: '7B',
          mapel: 'Al-Qur\'an Hadis',
          peran: 'Utama',
          isUtama: true,
          cakupanText: 'Kelompok Saya • 16 Siswa (+2 belum dikelompokkan)',
          progressText: 'Tugas 1 terisi 18/18 siswa — 100%',
          progressValue: 1.0,
        ),
        const SizedBox(height: 12),
        _buildClassCard(
          context,
          rombel: '8C',
          mapel: 'Fikih',
          peran: 'Pendamping',
          isUtama: false,
          cakupanText: 'Kelompok 2 • 15 Siswa',
          progressText: 'UH 1 terisi 12/15 siswa — 80%',
          progressValue: 0.80,
        ),
      ],
    );
  }

  Widget _buildClassCard(
    BuildContext context, {
    required String rombel,
    required String mapel,
    required String peran,
    required bool isUtama,
    required String cakupanText,
    required String progressText,
    required double progressValue,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InputNilaiScreen(rombelNama: rombel, mapelNama: mapel),
            ),
          );
        },
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rombel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mapel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUtama ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isUtama ? AppColors.secondary : AppColors.outline,
                    ),
                  ),
                  child: Text(
                    peran,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isUtama ? AppColors.onSecondaryContainer : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cakupanText,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressValue >= 1.0 ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progressText,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    ),
  );
}
}

/// Tab 2: Fast-Entry Grade Grid (PRD F10 & UI Guideline 5.3)
class InputNilaiCepatTab extends StatefulWidget {
  const InputNilaiCepatTab({super.key});

  @override
  State<InputNilaiCepatTab> createState() => _InputNilaiCepatTabState();
}

class _InputNilaiCepatTabState extends State<InputNilaiCepatTab> {
  String _selectedJenis = 'UH';
  final double _kkm = 75.0;

  final List<Map<String, dynamic>> _siswaList = [
    {
      'no': 1,
      'nis': '202607001',
      'nama': 'Ahmad Fauzi Ridwan',
      'nilai': '85',
      'sumber': null,
    },
    {
      'no': 2,
      'nis': '202607002',
      'nama': 'Bilqis Nur Azizah',
      'nilai': '70', // di bawah KKM
      'sumber': null,
    },
    {
      'no': 3,
      'nis': '202607003',
      'nama': 'Dian Muhammad Irfan',
      'nilai': '92',
      'sumber': 'Bawaan rombel asal (7A)',
    },
    {
      'no': 4,
      'nis': '202607004',
      'nama': 'Farah Nabila Putri',
      'nilai': '',
      'sumber': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header Sticky: ChoiceChips Jenis Nilai & Info KKM
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['TGS', 'UH', 'PAS', 'PAT', 'PRY', 'PRT', 'UK'].map((jenis) {
                      final isSelected = _selectedJenis == jenis;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(jenis),
                          selected: isSelected,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedJenis = jenis);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'KKM: ${_kkm.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        // Fast-Entry List Siswa
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _siswaList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final siswa = _siswaList[index];
              final nilaiVal = double.tryParse(siswa['nilai'] ?? '');
              final isUnderKkm = nilaiVal != null && nilaiVal < _kkm;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        '${siswa['no']}.',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SiswaFormScreen(
                                  namaLengkap: siswa['nama'],
                                  nis: siswa['nis'],
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                siswa['nama'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    'NIS: ${siswa['nis']}',
                                    style: AppTheme.tabularNumberStyle.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  if (siswa['sumber'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        siswa['sumber'],
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Pindah Rombel',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PindahRombelDialog(
                              siswaNama: siswa['nama'],
                              rombelAsalNama: '7A',
                              daftarRombelTujuan: const ['7B', '7C', '8A'],
                              onConfirm: (tujuan, bawa) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${siswa['nama']} dipindahkan ke $tujuan (Bawa nilai: $bawa)')),
                                );
                              },
                            ),
                          );
                        },
                      ),
                      // Input Nilai Cepat Rata Tengah Tabular Figures
                      SizedBox(
                        width: 72,
                        height: 44,
                        child: TextFormField(
                          initialValue: siswa['nilai'],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          textInputAction: TextInputAction.next,
                          style: AppTheme.tabularNumberStyle.copyWith(
                            fontSize: 16,
                            color: isUnderKkm ? AppColors.danger : AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            fillColor: isUnderKkm ? AppColors.dangerSoft : AppColors.surface,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isUnderKkm ? AppColors.danger : AppColors.outline,
                                width: isUnderKkm ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              siswa['nilai'] = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tab 3: One-Tap Attendance (PRD F13 & UI Guideline 5.4)
class AbsensiCepatTab extends StatefulWidget {
  const AbsensiCepatTab({super.key});

  @override
  State<AbsensiCepatTab> createState() => _AbsensiCepatTabState();
}

class _AbsensiCepatTabState extends State<AbsensiCepatTab> {
  final List<Map<String, dynamic>> _absensiList = [
    {'nama': 'Ahmad Fauzi Ridwan', 'status': 'H'},
    {'nama': 'Bilqis Nur Azizah', 'status': 'S'},
    {'nama': 'Dian Muhammad Irfan', 'status': 'H'},
    {'nama': 'Farah Nabila Putri', 'status': 'I'},
    {'nama': 'Genta Pratama', 'status': 'A'},
  ];

  void _setAllHadir() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final item in _absensiList) {
        item['status'] = 'H';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Absensi Rombel 7A • Hari Ini',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.fullscreen_rounded, size: 22, color: AppColors.primary),
                    tooltip: 'Buka Layar Presensi Penuh',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InputAbsensiScreen(rombelNama: '7A'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _setAllHadir,
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Semua Hadir (H)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _absensiList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = _absensiList[idx];
              final status = item['status'];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['nama'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Segmented Pill [ H ] [ S ] [ I ] [ A ]
                      Row(
                        children: ['H', 'S', 'I', 'A'].map((pill) {
                          final isSelected = status == pill;
                          Color pillColor = AppColors.surfaceVariant;
                          Color textColor = AppColors.textSecondary;

                          if (isSelected) {
                            switch (pill) {
                              case 'H':
                                pillColor = AppColors.primary;
                                textColor = Colors.white;
                                break;
                              case 'S':
                                pillColor = AppColors.info;
                                textColor = Colors.white;
                                break;
                              case 'I':
                                pillColor = AppColors.warning;
                                textColor = Colors.white;
                                break;
                              case 'A':
                                pillColor = AppColors.danger;
                                textColor = Colors.white;
                                break;
                            }
                          }

                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => item['status'] = pill);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: pillColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? Colors.transparent : AppColors.outline,
                                  ),
                                ),
                                child: Text(
                                  pill,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tab 4: Pengaturan & Status Perangkat
class PengaturanTab extends StatelessWidget {
  const PengaturanTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Koneksi Server Operator WiFi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: 'http://192.168.1.100:8000',
                  decoration: const InputDecoration(
                    labelText: 'Alamat Server Operator',
                    prefixIcon: Icon(Icons.wifi),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Membuka kamera scan QR Server...')),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Pairing Server'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informasi Perangkat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('Device ID: d8a1-4b2c-9910', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('Versi Aplikasi: v1.5.0-offline', style: TextStyle(fontSize: 13)),
                SizedBox(height: 4),
                Text('Database: Drift SQLite + SQLCipher AES-256', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
