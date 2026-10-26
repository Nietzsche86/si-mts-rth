import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/providers/database_providers.dart';
import 'data/repositories/penilaian_repository.dart';
import 'data/repositories/absensi_repository.dart';
import 'data/repositories/pengampu_repository.dart';
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

class MainHomeScreen extends ConsumerStatefulWidget {
  const MainHomeScreen({super.key});

  @override
  ConsumerState<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends ConsumerState<MainHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final semester = ref.watch(activeSemesterProvider);
    final pendingOutbox = ref.watch(pendingOutboxCountProvider).asData?.value ?? 0;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MTs Roudhotut Thowalib',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${semester.semesterNama} ${semester.tahunAjaranNama}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            child: Text(
              user.isAdmin
                  ? 'Admin'
                  : (user.isWaliKelas ? 'Guru & Wali ${user.rombelWaliNama}' : 'Guru Mapel'),
              style: const TextStyle(
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
          // Banner Status Sinkronisasi Sticky Reaktif
          SyncStatusBar(
            pendingCount: pendingOutbox,
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

/// Tab 1: Kelas Saya (Terkoneksi langsung ke PengampuRepository Drift DB)
class KelasSayaTab extends ConsumerWidget {
  const KelasSayaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(kelasSayaSummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Gagal memuat daftar kelas: $err', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(kelasSayaSummaryProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Belum ada penugasan pengampu untuk akun ini di semester aktif.',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(kelasSayaSummaryProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildClassCard(context, item);
            },
          ),
        );
      },
    );
  }

  Widget _buildClassCard(BuildContext context, PengampuSummaryItem item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InputNilaiScreen(
                rombelId: item.rombelId,
                rombelNama: item.rombelNama,
                mapelId: item.mapelId,
                mapelNama: item.mapelNama,
              ),
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
                      item.rombelNama,
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
                      item.mapelNama,
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
                      color: item.isUtama ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isUtama ? AppColors.secondary : AppColors.outline,
                      ),
                    ),
                    child: Text(
                      item.isUtama ? 'Utama' : 'Pendamping',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.isUtama ? AppColors.onSecondaryContainer : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.cakupanText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progressValue,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.progressValue >= 1.0 ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.progressText,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab 2: Fast-Entry Grade Grid (Terkoneksi langsung ke PenilaianRepository SQLite)
class InputNilaiCepatTab extends ConsumerStatefulWidget {
  const InputNilaiCepatTab({super.key});

  @override
  ConsumerState<InputNilaiCepatTab> createState() => _InputNilaiCepatTabState();
}

class _InputNilaiCepatTabState extends ConsumerState<InputNilaiCepatTab> {
  String _selectedJenis = 'UH';
  final int _urutanKe = 1;
  final double _kkm = 75.0;

  List<SiswaNilaiItem> _siswaItems = [];
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNilaiData();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadNilaiData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(penilaianRepoProvider);
      final list = await repo.getSiswaNilaiList(
        rombelId: 'rombel-7a',
        mapelId: 'mapel-arab',
        semesterId: 'sem-2026-ganjil',
        jenisNilaiId: _selectedJenis,
        urutanKe: _urutanKe,
      );

      for (final s in list) {
        if (!_controllers.containsKey(s.keanggotaanId)) {
          final val = s.nilaiAngka;
          _controllers[s.keanggotaanId] = TextEditingController(
            text: val != null
                ? (val % 1 == 0 ? val.toInt().toString() : val.toString())
                : '',
          );
        } else {
          final val = s.nilaiAngka;
          _controllers[s.keanggotaanId]!.text = val != null
              ? (val % 1 == 0 ? val.toInt().toString() : val.toString())
              : '';
        }
      }

      _siswaItems = list;
    } catch (e) {
      debugPrint('[InputNilaiCepat] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _simpanNilai(SiswaNilaiItem siswa, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final val = double.tryParse(trimmed);
    if (val == null) return;

    if (val < 0 || val > 100) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nilai harus di antara 0 dan 100'),
            backgroundColor: Color(0xFFDC2626),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      final repo = ref.read(penilaianRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.simpanNilai(
        keanggotaanId: siswa.keanggotaanId,
        mapelId: 'mapel-arab',
        semesterId: 'sem-2026-ganjil',
        jenisNilaiId: _selectedJenis,
        urutanKe: _urutanKe,
        nilaiAngka: val,
        guruId: user.guruId ?? 'guru-001',
        deviceId: deviceId,
      );

      HapticFeedback.lightImpact();
      ref.invalidate(kelasSayaSummaryProvider);
    } catch (e) {
      debugPrint('[InputNilaiCepat] Error saving nilai: $e');
    }
  }

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
                            if (_selectedJenis != jenis) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedJenis = jenis);
                              _loadNilaiData();
                            }
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
        const Divider(height: 1),
        // Fast-Entry List Siswa
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _siswaItems.isEmpty
                  ? const Center(child: Text('Tidak ada siswa aktif'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _siswaItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final siswa = _siswaItems[index];
                        final ctrl = _controllers[siswa.keanggotaanId]!;
                        final nilaiVal = double.tryParse(ctrl.text.trim());
                        final isUnderKkm = nilaiVal != null && nilaiVal < _kkm;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  '${index + 1}.',
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
                                            siswaId: siswa.siswaId,
                                            namaLengkap: siswa.namaLengkap,
                                            nis: siswa.nis,
                                          ),
                                        ),
                                      ).then((_) => _loadNilaiData());
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          siswa.namaLengkap,
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
                                              'NIS: ${siswa.nis}',
                                              style: AppTheme.tabularNumberStyle.copyWith(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            if (siswa.isBawaanRombelAsal) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryContainer,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Bawaan rombel asal',
                                                  style: TextStyle(
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
                                        siswaNama: siswa.namaLengkap,
                                        rombelAsalNama: '7A',
                                        daftarRombelTujuan: const ['7B', '8A', '9A'],
                                        onConfirm: (tujuan, bawa) async {
                                          try {
                                            final rombelRepo = ref.read(rombelRepoProvider);
                                            final user = ref.read(currentUserProvider);
                                            final deviceId = ref.read(activeDeviceIdProvider);
                                            final targetRombelId = 'rombel-${tujuan.toLowerCase()}';

                                            await rombelRepo.pindahRombel(
                                              siswaId: siswa.siswaId,
                                              rombelLamaId: 'rombel-7a',
                                              rombelBaruId: targetRombelId,
                                              semesterId: 'sem-2026-ganjil',
                                              bawaNilai: bawa,
                                              guruId: user.guruId ?? 'guru-001',
                                              deviceId: deviceId,
                                            );

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('${siswa.namaLengkap} dipindahkan ke $tujuan')),
                                              );
                                              _loadNilaiData();
                                              ref.invalidate(kelasSayaSummaryProvider);
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Gagal pindah rombel: $e')),
                                              );
                                            }
                                          }
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
                                    controller: ctrl,
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
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: isUnderKkm ? AppColors.danger : AppColors.primary,
                                          width: 2.0,
                                        ),
                                      ),
                                    ),
                                    onFieldSubmitted: (val) => _simpanNilai(siswa, val),
                                    onChanged: (val) {
                                      setState(() {});
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

/// Tab 3: One-Tap Attendance (Terkoneksi langsung ke AbsensiRepository Drift DB)
class AbsensiCepatTab extends ConsumerStatefulWidget {
  const AbsensiCepatTab({super.key});

  @override
  ConsumerState<AbsensiCepatTab> createState() => _AbsensiCepatTabState();
}

class _AbsensiCepatTabState extends ConsumerState<AbsensiCepatTab> {
  final DateTime _today = DateTime.now();
  List<SiswaAbsensiItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAbsensiData();
    });
  }

  Future<void> _loadAbsensiData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(absensiRepoProvider);
      final list = await repo.getAbsensiByTanggal(
        rombelId: 'rombel-7a',
        semesterId: 'sem-2026-ganjil',
        tanggal: _today,
      );
      _items = list;
    } catch (e) {
      debugPrint('[AbsensiCepatTab] Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setAllHadir() async {
    HapticFeedback.lightImpact();
    try {
      final repo = ref.read(absensiRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.setSemuaHadir(
        rombelId: 'rombel-7a',
        semesterId: 'sem-2026-ganjil',
        tanggal: _today,
        userId: user.userId,
        deviceId: deviceId,
      );

      _loadAbsensiData();
    } catch (e) {
      debugPrint('[AbsensiCepatTab] Error setting all hadir: $e');
    }
  }

  Future<void> _setStatus(SiswaAbsensiItem item, String status) async {
    HapticFeedback.lightImpact();
    try {
      final repo = ref.read(absensiRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.setStatusAbsensi(
        keanggotaanId: item.keanggotaanId,
        semesterId: 'sem-2026-ganjil',
        tanggal: _today,
        status: status,
        userId: user.userId,
        deviceId: deviceId,
      );

      _loadAbsensiData();
    } catch (e) {
      debugPrint('[AbsensiCepatTab] Error setting status: $e');
    }
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
                      ).then((_) => _loadAbsensiData());
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
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('Tidak ada siswa aktif di rombel ini'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = _items[idx];
                        final status = item.status;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.namaLengkap,
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
                                        onTap: () => _setStatus(item, pill),
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
                Text('Device ID: mobile-dev-001', style: TextStyle(fontSize: 13)),
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
