import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/penilaian_repository.dart';
import 'kelengkapan_pengampu_screen.dart';

class RekapNilaiScreen extends ConsumerStatefulWidget {
  final String? initialRombelId;
  final String? initialMapelId;

  const RekapNilaiScreen({
    super.key,
    this.initialRombelId,
    this.initialMapelId,
  });

  @override
  ConsumerState<RekapNilaiScreen> createState() => _RekapNilaiScreenState();
}

class _RekapNilaiScreenState extends ConsumerState<RekapNilaiScreen> {
  String? _selectedRombelId;
  String? _selectedMapelId; // null = Semua Mapel
  int _viewMode = 0; // 0 = Peringkat & Nilai Akhir, 1 = Matriks K13 Lengkap
  bool _isLoading = false;
  RekapRombelResult? _rekapResult;
  List<RombelData> _rombelList = [];
  List<MapelData> _mapelList = [];

  @override
  void initState() {
    super.initState();
    _selectedRombelId = widget.initialRombelId;
    _selectedMapelId = widget.initialMapelId;
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

      final mapels = await (db.select(db.mapel)
            ..where((t) => t.aktif.equals(1) & t.deleted.equals(0))
            ..orderBy([(t) => OrderingTerm.asc(t.urutan)]))
          .get();

      if (mounted) {
        setState(() {
          _rombelList = rombels;
          _mapelList = mapels;
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
    final repo = ref.read(penilaianRepoProvider);
    final semester = ref.read(activeSemesterProvider);

    try {
      final result = await repo.getRekapNilaiRombel(
        rombelId: _selectedRombelId!,
        semesterId: semester.semesterId,
        mapelId: _selectedMapelId,
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
          SnackBar(content: Text('Gagal memuat rekap nilai: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekap Nilai & Ranking K13'),
        actions: [
          IconButton(
            tooltip: 'Cek Kelengkapan Pengampu',
            icon: const Icon(Icons.fact_check_outlined, color: AppColors.primary),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KelengkapanPengampuScreen(
                    initialRombelId: _selectedRombelId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Rombel & Mapel
          _buildFilterBar(),

          // Konten Utama
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rekapResult == null
                    ? const Center(child: Text('Pilih rombel untuk menampilkan rekap'))
                    : RefreshIndicator(
                        onRefresh: _loadRekap,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Kartu Statistik Rombel
                            _buildStatistikRombelCard(),
                            const SizedBox(height: 16),

                            // Segmented Button View Mode
                            _buildViewModeToggle(),
                            const SizedBox(height: 16),

                            // Daftar Siswa
                            if (_rekapResult!.siswaItems.isEmpty)
                              _buildEmptyPlaceholder()
                            else if (_viewMode == 0)
                              ..._rekapResult!.siswaItems.map(_buildRankingCard)
                            else
                              ..._rekapResult!.siswaItems.map(_buildMatriksK13Card),
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
    final currentMapel = _mapelList.any((m) => m.id == _selectedMapelId)
        ? _selectedMapelId
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outline, width: 1)),
      ),
      child: Row(
        children: [
          // Dropdown Rombel
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              key: ValueKey('rombel_$currentRombel'),
              isExpanded: true,
              initialValue: currentRombel,
              decoration: const InputDecoration(
                labelText: 'Rombel',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: _rombelList.map((r) {
                return DropdownMenuItem(
                  value: r.id,
                  child: Text('Kelas ${r.nama}', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedRombelId) {
                  setState(() => _selectedRombelId = val);
                  _loadRekap();
                }
              },
            ),
          ),
          const SizedBox(width: 12),

          // Dropdown Mapel
          Expanded(
            flex: 6,
            child: DropdownButtonFormField<String?>(
              key: ValueKey('mapel_$currentMapel'),
              isExpanded: true,
              initialValue: currentMapel,
              decoration: const InputDecoration(
                labelText: 'Mata Pelajaran',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Semua Mapel (Agregat)', overflow: TextOverflow.ellipsis),
                ),
                ..._mapelList.map((m) {
                  return DropdownMenuItem<String?>(
                    value: m.id,
                    child: Text(m.nama, overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedMapelId = val);
                _loadRekap();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistikRombelCard() {
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
                const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Statistik Rombel ${res.rombelNama} • ${_selectedMapelId == null ? "Semua Mapel" : (_mapelList.firstWhere((m) => m.id == _selectedMapelId).nama)}',
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
                _buildStatItem('Rata-rata', '${res.rataRataRombel}', AppColors.primary),
                _buildStatDivider(),
                _buildStatItem('Tertinggi', '${res.nilaiTertinggi}', AppColors.success),
                _buildStatDivider(),
                _buildStatItem('Terendah', '${res.nilaiTerendah}', AppColors.danger),
                _buildStatDivider(),
                _buildStatItem('Ketuntasan', '${res.persentaseKetuntasan}%', AppColors.secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.outline,
    );
  }

  Widget _buildViewModeToggle() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(
          value: 0,
          icon: Icon(Icons.emoji_events_outlined),
          label: Text('Peringkat & Nilai Akhir'),
        ),
        ButtonSegment(
          value: 1,
          icon: Icon(Icons.table_chart_outlined),
          label: Text('Matriks K13 Lengkap'),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) {
        HapticFeedback.selectionClick();
        setState(() => _viewMode = set.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Belum ada siswa aktif atau data nilai di rombel ini.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildRankingCard(RekapNilaiSiswaItem item) {
    Color rankBadgeBg;
    Color rankBadgeFg;
    IconData? rankIcon;

    if (item.ranking == 1) {
      rankBadgeBg = const Color(0xFFFEF3C7);
      rankBadgeFg = const Color(0xFFB45309);
      rankIcon = Icons.military_tech_rounded;
    } else if (item.ranking == 2) {
      rankBadgeBg = const Color(0xFFF1F5F9);
      rankBadgeFg = const Color(0xFF475569);
      rankIcon = Icons.military_tech_rounded;
    } else if (item.ranking == 3) {
      rankBadgeBg = const Color(0xFFFFEDD5);
      rankBadgeFg = const Color(0xFFC2410C);
      rankIcon = Icons.military_tech_rounded;
    } else {
      rankBadgeBg = AppColors.surfaceVariant;
      rankBadgeFg = AppColors.textSecondary;
    }

    final isTuntas = item.tuntasSemua;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Badge Ranking
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: rankBadgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: rankBadgeFg.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Center(
                child: rankIcon != null && item.ranking <= 3
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(rankIcon, size: 16, color: rankBadgeFg),
                          Text(
                            '#${item.ranking}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: rankBadgeFg,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '#${item.ranking}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: rankBadgeFg,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Info Siswa
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.namaLengkap,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'NIS: ${item.nis} • ${item.jenisKelamin == "L" ? "Laki-laki" : "Perempuan"}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTuntas ? AppColors.successSoft : AppColors.dangerSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isTuntas ? 'Tuntas KKM' : '${item.jumlahMapelRemedial} Mapel Remedial',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isTuntas ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Predikat ${item.predikat}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Nilai Akhir
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.rataRataAkhir}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: item.rataRataAkhir >= 75.0 ? AppColors.primary : AppColors.danger,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Total: ${item.totalNilai}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
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

  Widget _buildMatriksK13Card(RekapNilaiSiswaItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaLengkap,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'NIS: ${item.nis} • Peringkat #${item.ranking}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    'NA: ${item.rataRataAkhir} (${item.predikat})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onPrimaryContainer,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Rincian Nilai Mapel
            ...item.nilaiPerMapel.entries.map((entry) {
              final mapel = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        mapel.mapelNama,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'KD3: ${mapel.rataPengetahuan} (${mapel.predikatPengetahuan})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'KD4: ${mapel.rataKeterampilan} (${mapel.predikatKeterampilan})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: mapel.tuntas ? AppColors.successSoft : AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${mapel.nilaiAkhir} [${mapel.predikat}]',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: mapel.tuntas ? AppColors.success : AppColors.danger,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
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
}
