import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class InputAbsensiScreen extends StatefulWidget {
  final String rombelNama;

  const InputAbsensiScreen({
    super.key,
    required this.rombelNama,
  });

  @override
  State<InputAbsensiScreen> createState() => _InputAbsensiScreenState();
}

class _AbsensiStudentState {
  final String id;
  final String nis;
  final String nama;
  String? status; // 'H', 'S', 'I', 'A'

  _AbsensiStudentState({
    required this.id,
    required this.nis,
    required this.nama,
    this.status,
  });
}

class _InputAbsensiScreenState extends State<InputAbsensiScreen> {
  DateTime _selectedDate = DateTime.now();

  late List<_AbsensiStudentState> _students;

  @override
  void initState() {
    super.initState();
    _students = [
      _AbsensiStudentState(id: 'k1', nis: '1001', nama: 'Ahmad Faiz', status: 'H'),
      _AbsensiStudentState(id: 'k2', nis: '1002', nama: 'Budi Santoso', status: 'S'),
      _AbsensiStudentState(id: 'k3', nis: '1003', nama: 'Citra Dewi', status: 'H'),
      _AbsensiStudentState(id: 'k4', nis: '1004', nama: 'Deni Kurniawan', status: 'I'),
      _AbsensiStudentState(id: 'k5', nis: '1005', nama: 'Eka Pratama', status: 'A'),
    ];
  }

  void _setStatus(int index, String status) {
    HapticFeedback.lightImpact();
    setState(() {
      _students[index].status = status;
    });
  }

  void _setSemuaHadir() {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final s in _students) {
        s.status = 'H';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua siswa ditandai Hadir (H)'),
        duration: Duration(seconds: 2),
      ),
    );
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
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
            child: ListView.separated(
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
