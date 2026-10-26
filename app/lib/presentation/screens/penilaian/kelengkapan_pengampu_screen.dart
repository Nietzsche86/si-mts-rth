import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/penilaian_repository.dart';

class KelengkapanPengampuScreen extends ConsumerStatefulWidget {
  final String? initialRombelId;

  const KelengkapanPengampuScreen({
    super.key,
    this.initialRombelId,
  });

  @override
  ConsumerState<KelengkapanPengampuScreen> createState() => _KelengkapanPengampuScreenState();
}

class _KelengkapanPengampuScreenState extends ConsumerState<KelengkapanPengampuScreen> {
  String? _selectedRombelId;
  bool _isLoading = false;
  List<ProgresPengampuItem> _items = [];
  List<RombelData> _rombelList = [];

  @override
  void initState() {
    super.initState();
    _selectedRombelId = widget.initialRombelId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    final db = ref.read(appDatabaseProvider);

    try {
      final rombels = await (db.select(db.rombel)
            ..where((t) => t.deleted.equals(0))
            ..orderBy([(t) => OrderingTerm.asc(t.nama)]))
          .get();

      if (mounted) {
        setState(() {
          _rombelList = rombels;
        });
      }

      await _loadProgres();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProgres() async {
    setState(() => _isLoading = true);
    final repo = ref.read(penilaianRepoProvider);
    final semester = ref.read(activeSemesterProvider);

    try {
      final list = await repo.getProgresKelengkapanPengampu(
        semesterId: semester.semesterId,
        rombelId: _selectedRombelId,
      );

      if (mounted) {
        setState(() {
          _items = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat progres pengampu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lengkapCount = _items.where((i) => i.statusKelengkapan == 'Lengkap').length;
    final berjalanCount = _items.where((i) => i.statusKelengkapan == 'Sedang Berjalan').length;
    final belumCount = _items.where((i) => i.statusKelengkapan == 'Belum Mengisi').length;

    final currentSelectedRombel =
        _rombelList.any((r) => r.id == _selectedRombelId) ? _selectedRombelId : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progres Kelengkapan Nilai Pengampu'),
      ),
      body: Column(
        children: [
          // Filter Rombel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
            ),
            child: DropdownButtonFormField<String?>(
              key: ValueKey('filter_rombel_$currentSelectedRombel'),
              isExpanded: true,
              initialValue: currentSelectedRombel,
              decoration: const InputDecoration(
                labelText: 'Filter Rombel',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua Rombel (Seluruh Madrasah)'),
                ),
                ..._rombelList.map((r) {
                  return DropdownMenuItem<String?>(
                    value: r.id,
                    child: Text('Kelas ${r.nama}'),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedRombelId = val);
                _loadProgres();
              },
            ),
          ),

          // Konten Utama
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadProgres,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Kartu Ringkasan
                        Card(
                          color: AppColors.surfaceVariant,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                _buildSummaryItem('Lengkap', lengkapCount, AppColors.success),
                                _buildSummaryDivider(),
                                _buildSummaryItem('Sedang Berjalan', berjalanCount, AppColors.warning),
                                _buildSummaryDivider(),
                                _buildSummaryItem('Belum Mengisi', belumCount, AppColors.danger),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_items.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Tidak ada pengampu aktif di kriteria ini.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._items.map(_buildPengampuCard),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.outline,
    );
  }

  Widget _buildPengampuCard(ProgresPengampuItem item) {
    Color statusBg;
    Color statusFg;
    if (item.statusKelengkapan == 'Lengkap') {
      statusBg = AppColors.successSoft;
      statusFg = AppColors.success;
    } else if (item.statusKelengkapan == 'Sedang Berjalan') {
      statusBg = AppColors.warningSoft;
      statusFg = AppColors.warning;
    } else {
      statusBg = AppColors.dangerSoft;
      statusFg = AppColors.danger;
    }

    final isUtama = item.peran == 'utama';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    'Kelas ${item.rombelNama}',
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.statusKelengkapan,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.guruNama,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUtama ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isUtama ? AppColors.secondary : AppColors.outline,
                    ),
                  ),
                  child: Text(
                    isUtama ? 'Guru Utama' : 'Pendamping',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isUtama ? AppColors.onSecondaryContainer : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.cakupan == 'seluruh'
                      ? 'Seluruh Kelas (${item.totalSiswaTarget} Siswa)'
                      : 'Kelompok Khusus (${item.totalSiswaTarget} Siswa)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.totalSiswaTarget > 0
                          ? (item.jumlahSiswaTernilai / item.totalSiswaTarget).clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        item.persentaseKelengkapan >= 100.0 ? AppColors.success : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${item.persentaseKelengkapan}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.jumlahSiswaTernilai} dari ${item.totalSiswaTarget} siswa telah memiliki entri nilai',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),

            if (item.rincianJenisNilai.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.rincianJenisNilai.entries.map((entry) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.key}: ${entry.value} nilai',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
