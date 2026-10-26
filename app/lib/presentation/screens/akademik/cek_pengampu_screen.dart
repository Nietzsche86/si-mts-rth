import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/pengampu_repository.dart';
import 'pembagian_kelompok_dialog.dart';

class CekPengampuScreen extends ConsumerStatefulWidget {
  const CekPengampuScreen({super.key});

  @override
  ConsumerState<CekPengampuScreen> createState() => _CekPengampuScreenState();
}

class _CekPengampuScreenState extends ConsumerState<CekPengampuScreen> {
  bool _isLoading = true;
  List<AnomaliPengampu> _anomalies = [];
  String _filter = 'semua'; // 'semua' | 'kritis' | 'peringatan'

  @override
  void initState() {
    super.initState();
    _loadAnomalies();
  }

  Future<void> _loadAnomalies() async {
    setState(() => _isLoading = true);
    final activeSemester = ref.read(activeSemesterProvider);
    final repo = ref.read(pengampuRepoProvider);
    final list = await repo.deteksiAnomaliPengampu(semesterId: activeSemester.semesterId);
    if (mounted) {
      setState(() {
        _anomalies = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSemester = ref.read(activeSemesterProvider);
    final kritisCount = _anomalies.where((a) => a.tingkatKeparahan == 'kritis').length;
    final peringatanCount = _anomalies.where((a) => a.tingkatKeparahan == 'peringatan').length;

    final filteredList = _anomalies.where((a) {
      if (_filter == 'kritis') return a.tingkatKeparahan == 'kritis';
      if (_filter == 'peringatan') return a.tingkatKeparahan == 'peringatan';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cek Pengampu & Deteksi Anomali'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Periksa Ulang',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAnomalies();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Tabs Bar
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'Semua (${_anomalies.length})',
                        filterKey: 'semua',
                        count: _anomalies.length,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Kritis ($kritisCount)',
                        filterKey: 'kritis',
                        count: kritisCount,
                        color: AppColors.danger,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Peringatan ($peringatanCount)',
                        filterKey: 'peringatan',
                        count: peringatanCount,
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Anomaly List or Empty State
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primary,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Penugasan Pengampu Sempurna!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tidak ditemukan anomali penugasan pada semester aktif.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final anomali = filteredList[idx];
                            final isKritis = anomali.tingkatKeparahan == 'kritis';

                            return Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isKritis ? AppColors.danger : AppColors.warning,
                                  width: 1.2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isKritis ? AppColors.dangerSoft : AppColors.warningSoft,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            isKritis
                                                ? (anomali.jenis == JenisAnomaliPengampu.guruNonaktif
                                                    ? Icons.person_off_rounded
                                                    : Icons.error_outline_rounded)
                                                : Icons.warning_amber_rounded,
                                            color: isKritis ? AppColors.danger : AppColors.warning,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isKritis ? AppColors.dangerSoft : AppColors.warningSoft,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isKritis ? 'KRITIS' : 'PERINGATAN',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: isKritis ? AppColors.danger : AppColors.warning,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                anomali.judul,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      anomali.deskripsi,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    if (anomali.jenis == JenisAnomaliPengampu.siswaFallback ||
                                        anomali.jenis == JenisAnomaliPengampu.siswaTumpangTindih) ...[
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            HapticFeedback.lightImpact();
                                            if (anomali.rombelId != null &&
                                                anomali.mapelId != null) {
                                              final updated = await Navigator.push<bool>(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => PembagianKelompokDialog(
                                                    rombelId: anomali.rombelId!,
                                                    rombelNama: anomali.rombelNama ?? '',
                                                    mapelId: anomali.mapelId!,
                                                    mapelNama: anomali.mapelNama ?? '',
                                                    semesterId: activeSemester.semesterId,
                                                  ),
                                                ),
                                              );
                                              if (updated == true) {
                                                _loadAnomalies();
                                              }
                                            }
                                          },
                                          icon: const Icon(Icons.group_work_rounded, size: 16),
                                          label: const Text('Atur Pembagian Kelompok'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String filterKey,
    required int count,
    required Color color,
  }) {
    final isSelected = _filter == filterKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = filterKey);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? color : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : AppColors.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
