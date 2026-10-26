import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';

class InputAbsensiScreen extends ConsumerStatefulWidget {
  final String rombelId;
  final String rombelNama;
  final String semesterId;

  const InputAbsensiScreen({
    super.key,
    this.rombelId = 'rombel-7a',
    required this.rombelNama,
    this.semesterId = 'sem-2026-ganjil',
  });

  @override
  ConsumerState<InputAbsensiScreen> createState() => _InputAbsensiScreenState();
}

class _AbsensiStudentState {
  final String keanggotaanId;
  final String siswaId;
  final String nis;
  final String nama;
  String? status; // 'H', 'S', 'I', 'A'

  _AbsensiStudentState({
    required this.keanggotaanId,
    required this.siswaId,
    required this.nis,
    required this.nama,
    this.status,
  });
}

class _InputAbsensiScreenState extends ConsumerState<InputAbsensiScreen> {
  DateTime _selectedDate = DateTime.now();
  List<_AbsensiStudentState> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(absensiRepoProvider);
      final rawList = await repo.getAbsensiByTanggal(
        rombelId: widget.rombelId,
        semesterId: widget.semesterId,
        tanggal: _selectedDate,
      );

      _students = rawList
          .map((item) => _AbsensiStudentState(
                keanggotaanId: item.keanggotaanId,
                siswaId: item.siswaId,
                nis: item.nis,
                nama: item.namaLengkap,
                status: item.status,
              ))
          .toList();
    } catch (e) {
      debugPrint('[InputAbsensi] Error loading absensi: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setStatus(int index, String status) async {
    final student = _students[index];
    final prevStatus = student.status;

    setState(() {
      student.status = status;
    });
    HapticFeedback.lightImpact();

    try {
      final repo = ref.read(absensiRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.setStatusAbsensi(
        keanggotaanId: student.keanggotaanId,
        semesterId: widget.semesterId,
        tanggal: _selectedDate,
        status: status,
        userId: user.userId,
        deviceId: deviceId,
      );
    } catch (e) {
      debugPrint('[InputAbsensi] Error setting status: $e');
      if (mounted) {
        setState(() {
          student.status = prevStatus;
        });
      }
    }
  }

  Future<void> _setSemuaHadir() async {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final s in _students) {
        s.status = 'H';
      }
    });

    try {
      final repo = ref.read(absensiRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.setSemuaHadir(
        rombelId: widget.rombelId,
        semesterId: widget.semesterId,
        tanggal: _selectedDate,
        userId: user.userId,
        deviceId: deviceId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua siswa ditandai Hadir (H) dan disimpan ke database'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[InputAbsensi] Error setting all hadir: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Presensi • ${widget.rombelNama}'),
        actions: [
          IconButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
                _loadData();
              }
            },
            icon: const Icon(Icons.calendar_today_outlined),
            tooltip: 'Pilih Tanggal',
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Bar: Set Semua Hadir
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text('Satu ketuk per baris siswa', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _setSemuaHadir,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Set Semua Hadir (H)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Presensi List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada siswa aktif di rombel ini',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                        itemBuilder: (context, index) {
                          final student = _students[index];

                          return Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // No
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),

                                // Nama & NIS
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.nama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      Text(
                                        student.nis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Segmented Pills [H] [S] [I] [A]
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPill(index, 'H', student.status == 'H', const Color(0xFF10B981), 'Hadir'),
                                    const SizedBox(width: 4),
                                    _buildPill(index, 'S', student.status == 'S', const Color(0xFFF59E0B), 'Sakit'),
                                    const SizedBox(width: 4),
                                    _buildPill(index, 'I', student.status == 'I', const Color(0xFF3B82F6), 'Izin'),
                                    const SizedBox(width: 4),
                                    _buildPill(index, 'A', student.status == 'A', const Color(0xFFEF4444), 'Alpa'),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(int index, String code, bool isSelected, Color activeColor, String label) {
    return InkWell(
      onTap: () => _setStatus(index, code),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.borderSubtle,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            code,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
