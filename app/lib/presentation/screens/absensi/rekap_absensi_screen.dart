import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/absensi_repository.dart';

class RekapAbsensiScreen extends ConsumerStatefulWidget {
  final String? initialRombelId;

  const RekapAbsensiScreen({
    super.key,
    this.initialRombelId,
  });

  @override
  ConsumerState<RekapAbsensiScreen> createState() => _RekapAbsensiScreenState();
}

class _RekapAbsensiScreenState extends ConsumerState<RekapAbsensiScreen> {
  String? _selectedRombelId;
  int _periodeMode = 0; // 0 = Bulan Ini, 1 = Semester Penuh, 2 = Rentang Kustom
  DateTimeRange? _customDateRange;
  bool _isLoading = false;
  RekapAbsensiRombelResult? _rekapResult;
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
          if (_selectedRombelId == null && rombels.isNotEmpty) {
            _selectedRombelId = rombels.first.id;
          }
        });
      }

      await _loadRekap();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRekap() async {
    if (_selectedRombelId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(absensiRepoProvider);
    final semester = ref.read(activeSemesterProvider);

    DateTime? startDate;
    DateTime? endDate;

    final now = DateTime.now();
    if (_periodeMode == 0) {
      // Bulan ini
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0);
    } else if (_periodeMode == 1) {
      // Semester penuh (biarkan null agar query mencakup seluruh semester)
      startDate = null;
      endDate = null;
    } else if (_periodeMode == 2 && _customDateRange != null) {
      startDate = _customDateRange!.start;
      endDate = _customDateRange!.end;
    }

    try {
      final result = await repo.getRekapAbsensiPeriodik(
        rombelId: _selectedRombelId!,
        semesterId: semester.semesterId,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) {
        setState(() {
          _rekapResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat rekap absensi: $e')),
        );
      }
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _periodeMode = 2;
      });
      _loadRekap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Absensi Siswa'),
      ),
      body: Column(
        children: [
          // Filter Rombel & Periode
          _buildFilterBar(),

          // Konten Utama
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rekapResult == null
                    ? const Center(child: Text('Pilih rombel untuk menampilkan rekap absensi'))
                    : RefreshIndicator(
                        onRefresh: _loadRekap,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Kartu Ringkasan Akumulasi Rombel
                            _buildStatistikAbsensiCard(),
                            const SizedBox(height: 16),

                            // Header Kolom & Jumlah Siswa
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Daftar Kehadiran (${_rekapResult!.siswaItems.length} Siswa)',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Text(
                                  '[H]   [S]   [I]   [A]   %',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // List Siswa
                            if (_rekapResult!.siswaItems.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Text(
                                    'Belum ada siswa aktif di rombel ini.',
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            else
                              ..._rekapResult!.siswaItems.map(_buildSiswaAbsensiCard),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final currentRombel = _rombelList.any((r) => r.id == _selectedRombelId)
        ? _selectedRombelId
        : (_rombelList.isNotEmpty ? _rombelList.first.id : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: Column(
        children: [
          // Dropdown Rombel
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: currentRombel,
            decoration: const InputDecoration(
              labelText: 'Pilih Rombel',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
            ),
            items: _rombelList.map((r) {
              return DropdownMenuItem(
                value: r.id,
                child: Text('Kelas ${r.nama}'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null && val != _selectedRombelId) {
                setState(() => _selectedRombelId = val);
                _loadRekap();
              }
            },
          ),
          const SizedBox(height: 10),

          // Segmented Button Periode
          Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: [
                    const ButtonSegment(
                      value: 0,
                      label: Text('Bulan Ini'),
                    ),
                    const ButtonSegment(
                      value: 1,
                      label: Text('1 Semester'),
                    ),
                    ButtonSegment(
                      value: 2,
                      label: Text(_customDateRange == null ? 'Rentang...' : 'Kustom'),
                    ),
                  ],
                  selected: {_periodeMode},
                  onSelectionChanged: (set) {
                    HapticFeedback.selectionClick();
                    final selected = set.first;
                    if (selected == 2) {
                      _pickCustomRange();
                    } else {
                      setState(() => _periodeMode = selected);
                      _loadRekap();
                    }
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistikAbsensiCard() {
    final res = _rekapResult!;
    return Card(
      color: AppColors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.primary, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Akumulasi Rombel ${res.rombelNama} • ${_periodeMode == 0 ? "Bulan Ini" : (_periodeMode == 1 ? "Semester Penuh" : "Periode Kustom")}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatPill('Hadir (H)', '${res.totalHadir}', AppColors.success, AppColors.successSoft),
                const SizedBox(width: 6),
                _buildStatPill('Sakit (S)', '${res.totalSakit}', AppColors.info, AppColors.infoSoft),
                const SizedBox(width: 6),
                _buildStatPill('Izin (I)', '${res.totalIzin}', AppColors.warning, AppColors.warningSoft),
                const SizedBox(width: 6),
                _buildStatPill('Alpa (A)', '${res.totalAlpa}', AppColors.danger, AppColors.dangerSoft),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tingkat Kehadiran Rombel:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  '${res.persentaseKehadiranRombel}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSiswaAbsensiCard(RekapAbsensiSiswaItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar / Icon Siswa
            CircleAvatar(
              radius: 18,
              backgroundColor: item.perluPerhatian ? AppColors.dangerSoft : AppColors.surfaceVariant,
              child: Icon(
                item.jenisKelamin == 'L' ? Icons.face : Icons.face_3,
                size: 20,
                color: item.perluPerhatian ? AppColors.danger : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),

            // Nama & NIS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaLengkap,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'NIS: ${item.nis}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      if (item.perluPerhatian) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.dangerSoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Alpa Tinggi!',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Indikator H S I A
            Row(
              children: [
                _buildCountBox('${item.hadir}', AppColors.successSoft, AppColors.success),
                const SizedBox(width: 4),
                _buildCountBox('${item.sakit}', AppColors.infoSoft, AppColors.info),
                const SizedBox(width: 4),
                _buildCountBox('${item.izin}', AppColors.warningSoft, AppColors.warning),
                const SizedBox(width: 4),
                _buildCountBox('${item.alpa}', item.alpa > 0 ? AppColors.dangerSoft : AppColors.surfaceVariant, item.alpa > 0 ? AppColors.danger : AppColors.textHint),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${item.persentaseKehadiran}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: item.persentaseKehadiran >= 90.0 ? AppColors.success : (item.persentaseKehadiran >= 75.0 ? AppColors.primary : AppColors.danger),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBox(String val, Color bg, Color fg) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          val,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
