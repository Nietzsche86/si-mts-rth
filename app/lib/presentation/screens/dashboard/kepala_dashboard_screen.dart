import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/absensi_repository.dart';
import '../../../data/repositories/penilaian_repository.dart';
import '../penilaian/rekap_nilai_screen.dart';
import '../absensi/rekap_absensi_screen.dart';

class KepalaDashboardScreen extends ConsumerStatefulWidget {
  const KepalaDashboardScreen({super.key});

  @override
  ConsumerState<KepalaDashboardScreen> createState() => _KepalaDashboardScreenState();
}

class _KepalaDashboardScreenState extends ConsumerState<KepalaDashboardScreen> {
  bool _isLoading = true;
  StatistikKehadiranMadrasah? _statKehadiran;
  List<MapelKetuntasanSummary> _statKetuntasan = [];
  int _totalSiswaAktif = 0;
  int _totalRombelAktif = 0;
  String? _selectedTingkat; // null = Semua Tingkat

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardData());
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final db = ref.read(appDatabaseProvider);
    final semester = ref.read(activeSemesterProvider);
    final absensiRepo = ref.read(absensiRepoProvider);
    final penilaianRepo = ref.read(penilaianRepoProvider);

    try {
      // 1. Hitung total siswa & rombel
      final allSiswa = await (db.select(db.siswa)..where((t) => t.deleted.equals(0))).get();
      final allRombels = await (db.select(db.rombel)..where((t) => t.deleted.equals(0))).get();

      // 2. Statistik Kehadiran
      final statKehadiran = await absensiRepo.getStatistikKehadiranMadrasah(
        semesterId: semester.semesterId,
      );

      // 3. Ketuntasan Belajar per Mapel
      final statKetuntasan = await penilaianRepo.getRingkasanKetuntasanPerMapel(
        semesterId: semester.semesterId,
        tingkat: _selectedTingkat,
      );

      if (mounted) {
        setState(() {
          _totalSiswaAktif = allSiswa.length;
          _totalRombelAktif = allRombels.length;
          _statKehadiran = statKehadiran;
          _statKetuntasan = statKetuntasan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat dashboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(activeSemesterProvider);

    // Hitung rata-rata ketuntasan madrasah
    double rataKetuntasanMadrasah = 0.0;
    if (_statKetuntasan.isNotEmpty) {
      final totalP = _statKetuntasan.fold<double>(0.0, (acc, item) => acc + item.persentaseKetuntasan);
      rataKetuntasanMadrasah = double.parse((totalP / _statKetuntasan.length).toStringAsFixed(1));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kepala Madrasah'),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadDashboardData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Info Madrasah
                  _buildMadrasahHeader(semester),
                  const SizedBox(height: 16),

                  // 4 Kartu KPI Eksekutif
                  _buildKpiGrid(rataKetuntasanMadrasah),
                  const SizedBox(height: 16),

                  // Aksi Pintasan Cepat
                  _buildQuickActionButtons(),
                  const SizedBox(height: 20),

                  // Ringkasan Kehadiran per Tingkat & Rombel
                  _buildSectionTitle(
                    title: 'Statistik Kehadiran Siswa',
                    subtitle: 'Agregat kehadiran semester aktif (${semester.semesterNama})',
                    icon: Icons.how_to_reg_rounded,
                  ),
                  const SizedBox(height: 10),
                  _buildKehadiranSection(),
                  const SizedBox(height: 24),

                  // Ringkasan Ketuntasan Belajar Terhadap KKM
                  _buildSectionTitle(
                    title: 'Persentase Ketuntasan Belajar (KKM)',
                    subtitle: 'Capaian nilai siswa terhadap KKM per mata pelajaran',
                    icon: Icons.auto_graph_rounded,
                  ),
                  const SizedBox(height: 8),
                  _buildTingkatFilterChips(),
                  const SizedBox(height: 10),
                  _buildKetuntasanMapelSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildMadrasahHeader(ActiveSemesterInfo semester) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MTs Roudhotut Thowalib',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tahun Ajaran ${semester.tahunAjaranNama} • Semester ${semester.semesterNama}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(double rataKetuntasan) {
    final kehadiranTotal = _statKehadiran?.persentaseKehadiranTotal ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _buildKpiCard(
                title: 'Rata Kehadiran',
                value: '$kehadiranTotal%',
                subtitle: 'Semester Aktif',
                icon: Icons.verified_user_rounded,
                color: kehadiranTotal >= 90 ? AppColors.primary : AppColors.warning,
                bgColor: AppColors.primaryContainer,
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Total Siswa',
                value: '$_totalSiswaAktif',
                subtitle: 'Siswa Aktif',
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                bgColor: AppColors.surface,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildKpiCard(
                title: 'Ketuntasan KKM',
                value: '$rataKetuntasan%',
                subtitle: 'Rata-rata Mapel',
                icon: Icons.grade_rounded,
                color: rataKetuntasan >= 85 ? AppColors.success : AppColors.secondary,
                bgColor: AppColors.secondaryContainer,
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Total Rombel',
                value: '$_totalRombelAktif',
                subtitle: 'Kelas 7, 8, 9',
                icon: Icons.meeting_room_rounded,
                color: AppColors.secondary,
                bgColor: AppColors.surface,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            Icon(icon, color: color.withValues(alpha: 0.8), size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapNilaiScreen()),
              );
            },
            icon: const Icon(Icons.table_chart_rounded, size: 18),
            label: const Text('Rekap Nilai'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapAbsensiScreen()),
              );
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
            label: const Text('Rekap Absensi'),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildKehadiranSection() {
    final stat = _statKehadiran;
    if (stat == null || stat.perRombel.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Belum ada data kehadiran pada semester ini.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Breakdown per tingkat
            if (stat.perTingkat.isNotEmpty) ...[
              Row(
                children: stat.perTingkat.entries.map((e) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text('Kelas ${e.key}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            '${e.value}%',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
            ],

            // Breakdown per rombel
            ...stat.perRombel.map((r) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          r.rombelNama,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onPrimaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${r.totalSiswa} Siswa',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              Text(
                                'H: ${r.hadir} • S: ${r.sakit} • I: ${r.izin} • A: ${r.alpa}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (r.persentaseKehadiran / 100.0).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                r.persentaseKehadiran >= 90.0 ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${r.persentaseKehadiran}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTingkatFilterChips() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Semua Tingkat'),
          selected: _selectedTingkat == null,
          onSelected: (_) {
            setState(() => _selectedTingkat = null);
            _loadDashboardData();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Kelas 7'),
          selected: _selectedTingkat == '7',
          onSelected: (_) {
            setState(() => _selectedTingkat = '7');
            _loadDashboardData();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Kelas 8'),
          selected: _selectedTingkat == '8',
          onSelected: (_) {
            setState(() => _selectedTingkat = '8');
            _loadDashboardData();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Kelas 9'),
          selected: _selectedTingkat == '9',
          onSelected: (_) {
            setState(() => _selectedTingkat = '9');
            _loadDashboardData();
          },
        ),
      ],
    );
  }

  Widget _buildKetuntasanMapelSection() {
    if (_statKetuntasan.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Belum ada data nilai mata pelajaran yang terisi.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _statKetuntasan.map((mapel) {
            Color barColor;
            if (mapel.persentaseKetuntasan >= 85.0) {
              barColor = AppColors.success;
            } else if (mapel.persentaseKetuntasan >= 70.0) {
              barColor = AppColors.warning;
            } else {
              barColor = AppColors.danger;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mapel.mapelNama,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'KKM: ${mapel.kkm}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${mapel.persentaseKetuntasan}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: barColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (mapel.persentaseKetuntasan / 100.0).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tuntas: ${mapel.jumlahTuntas} • Remedial: ${mapel.jumlahRemedial} (dari ${mapel.totalSiswa} siswa)',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Rata-rata: ${mapel.rataRataMapel}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
