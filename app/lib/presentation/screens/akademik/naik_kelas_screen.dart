import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';
import '../../../data/repositories/rombel_repository.dart';

class NaikKelasScreen extends ConsumerStatefulWidget {
  const NaikKelasScreen({super.key});

  @override
  ConsumerState<NaikKelasScreen> createState() => _NaikKelasScreenState();
}

class _NaikKelasScreenState extends ConsumerState<NaikKelasScreen> {
  String? _selectedRombelAsalId;
  String? _selectedRombelTujuanDefaultId;
  late String _tanggalMutasi;

  List<RombelData> _daftarRombel = [];
  List<SiswaData> _daftarSiswa = [];
  final Map<String, String> _statusSiswa = {}; // siswaId -> 'naik_kelas' | 'tinggal_kelas' | 'lulus'
  final Map<String, String?> _targetRombelSiswa = {}; // siswaId -> rombelId
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tanggalMutasi = now.toIso8601String().substring(0, 10);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final rombelRepo = ref.read(rombelRepoProvider);
    final activeSemester = ref.read(activeSemesterProvider);

    final rombels = await rombelRepo.getRombelByTahunAjaran(activeSemester.tahunAjaranId);
    if (mounted) {
      setState(() {
        _daftarRombel = rombels;
        if (rombels.isNotEmpty) {
          _selectedRombelAsalId = rombels.first.id;
          _selectedRombelTujuanDefaultId = rombels.length > 1 ? rombels[1].id : rombels.first.id;
        }
      });
      if (_selectedRombelAsalId != null) {
        await _loadSiswaForRombel(_selectedRombelAsalId!);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSiswaForRombel(String rombelId) async {
    setState(() => _isLoading = true);
    final rombelRepo = ref.read(rombelRepoProvider);
    final siswaList = await rombelRepo.getSiswaInRombel(rombelId);

    if (mounted) {
      setState(() {
        _daftarSiswa = siswaList;
        _statusSiswa.clear();
        _targetRombelSiswa.clear();
        for (final s in siswaList) {
          _statusSiswa[s.id] = 'naik_kelas';
          _targetRombelSiswa[s.id] = _selectedRombelTujuanDefaultId;
        }
        _isLoading = false;
      });
    }
  }

  void _tandaiSemua(String status) {
    HapticFeedback.lightImpact();
    setState(() {
      for (final s in _daftarSiswa) {
        _statusSiswa[s.id] = status;
        if (status == 'naik_kelas') {
          _targetRombelSiswa[s.id] = _selectedRombelTujuanDefaultId;
        } else if (status == 'tinggal_kelas') {
          _targetRombelSiswa[s.id] = _selectedRombelAsalId;
        } else {
          _targetRombelSiswa[s.id] = null;
        }
      }
    });
  }

  Future<void> _eksekusiMutasi() async {
    if (_selectedRombelAsalId == null || _daftarSiswa.isEmpty) return;

    final naikCount = _statusSiswa.values.where((v) => v == 'naik_kelas').length;
    final tinggalCount = _statusSiswa.values.where((v) => v == 'tinggal_kelas').length;
    final lulusCount = _statusSiswa.values.where((v) => v == 'lulus').length;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Mutasi Massal'),
        content: Text(
          'Anda akan memproses mutasi ${_daftarSiswa.length} siswa:\n\n'
          '• Naik Kelas: $naikCount siswa\n'
          '• Tinggal Kelas: $tinggalCount siswa\n'
          '• Lulus: $lulusCount siswa\n\n'
          'Perubahan akan disimpan ke database SQLite lokal dan diantrekan ke outbox sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Ya, Proses Sekarang'),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    setState(() => _isProcessing = true);
    final rombelRepo = ref.read(rombelRepoProvider);

    try {
      final items = _daftarSiswa.map((s) {
        final status = _statusSiswa[s.id] ?? 'naik_kelas';
        return NaikKelasItemInput(
          siswaId: s.id,
          status: status,
          rombelTujuanId: _targetRombelSiswa[s.id],
          catatan: 'Kenaikan kelas massal tanggal $_tanggalMutasi',
        );
      }).toList();

      final count = await rombelRepo.naikKelasMassal(
        rombelAsalId: _selectedRombelAsalId!,
        items: items,
        tanggal: _tanggalMutasi,
        deviceId: 'mobile-dev-001',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Berhasil memproses mutasi $count siswa ke database dan outbox!'),
            backgroundColor: AppColors.primary,
          ),
        );
        await _loadSiswaForRombel(_selectedRombelAsalId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses mutasi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final naikCount = _statusSiswa.values.where((v) => v == 'naik_kelas').length;
    final tinggalCount = _statusSiswa.values.where((v) => v == 'tinggal_kelas').length;
    final lulusCount = _statusSiswa.values.where((v) => v == 'lulus').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Naik Kelas Massal & Kelulusan'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter & Selector Card
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedRombelAsalId,
                              decoration: const InputDecoration(
                                labelText: 'Rombel Asal',
                                prefixIcon: Icon(Icons.meeting_room_outlined),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: _daftarRombel.map((r) {
                                return DropdownMenuItem(
                                  value: r.id,
                                  child: Text('Kelas ${r.nama}', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null && val != _selectedRombelAsalId) {
                                  setState(() => _selectedRombelAsalId = val);
                                  _loadSiswaForRombel(val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedRombelTujuanDefaultId,
                              decoration: const InputDecoration(
                                labelText: 'Tujuan Default',
                                prefixIcon: Icon(Icons.arrow_forward_rounded),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: _daftarRombel.map((r) {
                                return DropdownMenuItem(
                                  value: r.id,
                                  child: Text('Kelas ${r.nama}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRombelTujuanDefaultId = val;
                                    for (final s in _daftarSiswa) {
                                      if (_statusSiswa[s.id] == 'naik_kelas') {
                                        _targetRombelSiswa[s.id] = val;
                                      }
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _tandaiSemua('naik_kelas'),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.primary),
                              label: const Text('Semua Naik'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _tandaiSemua('tinggal_kelas'),
                              icon: const Icon(Icons.repeat_rounded, size: 18, color: AppColors.warning),
                              label: const Text('Semua Tinggal'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.warning),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _tandaiSemua('lulus'),
                              icon: const Icon(Icons.school_rounded, size: 18, color: AppColors.secondary),
                              label: const Text('Semua Lulus'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.secondary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Student List
                Expanded(
                  child: _daftarSiswa.isEmpty
                      ? const Center(
                          child: Text(
                            'Tidak ada siswa aktif di rombel ini',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _daftarSiswa.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final siswa = _daftarSiswa[idx];
                            final currentStatus = _statusSiswa[siswa.id] ?? 'naik_kelas';
                            final currentTargetRombel = _targetRombelSiswa[siswa.id];

                            return Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppColors.outline),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceVariant,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${idx + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              fontFeatures: [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                siswa.namaLengkap,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                'NIS: ${siswa.nis} • JK: ${siswa.jk}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Status Segmented Controls
                                    Row(
                                      children: [
                                        _buildStatusPill(
                                          siswaId: siswa.id,
                                          label: 'Naik Kelas',
                                          statusKey: 'naik_kelas',
                                          isSelected: currentStatus == 'naik_kelas',
                                          activeColor: AppColors.primary,
                                          activeBg: AppColors.primaryContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusPill(
                                          siswaId: siswa.id,
                                          label: 'Tinggal',
                                          statusKey: 'tinggal_kelas',
                                          isSelected: currentStatus == 'tinggal_kelas',
                                          activeColor: AppColors.warning,
                                          activeBg: AppColors.warningSoft,
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusPill(
                                          siswaId: siswa.id,
                                          label: 'Lulus',
                                          statusKey: 'lulus',
                                          isSelected: currentStatus == 'lulus',
                                          activeColor: AppColors.secondary,
                                          activeBg: AppColors.secondaryContainer,
                                        ),
                                      ],
                                    ),
                                    if (currentStatus != 'lulus') ...[
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          const Text(
                                            'Tujuan: ',
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppColors.outline),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: currentTargetRombel,
                                                  isDense: true,
                                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                                                  items: _daftarRombel.map((r) {
                                                    return DropdownMenuItem(
                                                      value: r.id,
                                                      child: Text('Kelas ${r.nama}'),
                                                    );
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setState(() => _targetRombelSiswa[siswa.id] = val);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Bottom Summary Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.outline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total: ${_daftarSiswa.length} Siswa',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            Text(
                              'Naik: $naikCount • Tinggal: $tinggalCount • Lulus: $lulusCount',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isProcessing || _daftarSiswa.isEmpty ? null : _eksekusiMutasi,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Proses Mutasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusPill({
    required String siswaId,
    required String label,
    required String statusKey,
    required bool isSelected,
    required Color activeColor,
    required Color activeBg,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _statusSiswa[siswaId] = statusKey;
            if (statusKey == 'naik_kelas') {
              _targetRombelSiswa[siswaId] = _selectedRombelTujuanDefaultId;
            } else if (statusKey == 'tinggal_kelas') {
              _targetRombelSiswa[siswaId] = _selectedRombelAsalId;
            } else {
              _targetRombelSiswa[siswaId] = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeBg : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.outline,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
