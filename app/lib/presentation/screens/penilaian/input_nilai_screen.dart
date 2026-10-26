import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/kalkulator_k13.dart';

class InputNilaiScreen extends StatefulWidget {
  final String rombelNama;
  final String mapelNama;
  final double kkm;

  const InputNilaiScreen({
    super.key,
    required this.rombelNama,
    required this.mapelNama,
    this.kkm = 75.0,
  });

  @override
  State<InputNilaiScreen> createState() => _InputNilaiScreenState();
}

class _SiswaMockItem {
  final String keanggotaanId;
  final String nis;
  final String nama;
  double? nilai;
  final bool isBawaan;
  final String? rombelAsal;
  final TextEditingController controller;

  _SiswaMockItem({
    required this.keanggotaanId,
    required this.nis,
    required this.nama,
    this.nilai,
    this.isBawaan = false,
    this.rombelAsal,
  }) : controller = TextEditingController(text: nilai != null ? nilai.toStringAsFixed(0) : '');
}

class _InputNilaiScreenState extends State<InputNilaiScreen> {
  final List<String> _jenisNilaiList = ['TGS', 'UH', 'PAS', 'PAT', 'PRY', 'PRT', 'UK'];
  String _selectedJenis = 'UH';
  int _urutanKe = 1;

  late List<_SiswaMockItem> _siswaList;

  @override
  void initState() {
    super.initState();
    _siswaList = [
      _SiswaMockItem(keanggotaanId: 'k1', nis: '1001', nama: 'Ahmad Faiz', nilai: 88.0),
      _SiswaMockItem(keanggotaanId: 'k2', nis: '1002', nama: 'Budi Santoso', nilai: 70.0), // < KKM (Red)
      _SiswaMockItem(keanggotaanId: 'k3', nis: '1003', nama: 'Citra Dewi', nilai: 95.0),
      _SiswaMockItem(
        keanggotaanId: 'k4',
        nis: '1004',
        nama: 'Deni Kurniawan',
        nilai: 82.0,
        isBawaan: true,
        rombelAsal: '7B',
      ),
      _SiswaMockItem(keanggotaanId: 'k5', nis: '1005', nama: 'Eka Pratama', nilai: null),
    ];
  }

  @override
  void dispose() {
    for (final s in _siswaList) {
      s.controller.dispose();
    }
    super.dispose();
  }

  void _simpanNilai(int index, String text) {
    final val = double.tryParse(text);
    setState(() {
      _siswaList[index].nilai = val;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.mapelNama} • ${widget.rombelNama}'),
            Text(
              'KKM: ${widget.kkm.toStringAsFixed(0)} • Kurikulum 2013',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sticky Jenis Nilai Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jenis Penilaian:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        const Text('Ke: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        DropdownButton<int>(
                          value: _urutanKe,
                          underline: const SizedBox.shrink(),
                          items: [1, 2, 3, 4, 5].map((u) {
                            return DropdownMenuItem(value: u, child: Text('$u'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _urutanKe = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _jenisNilaiList.map((j) {
                      final isSelected = _selectedJenis == j;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(j),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedJenis = j;
                              });
                            }
                          },
                          selectedColor: AppTheme.emeraldPrimary,
                          backgroundColor: AppTheme.sandGrey,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? AppTheme.emeraldPrimary : AppTheme.borderSubtle,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Fast-Entry Grid Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.sandGrey,
            child: const Row(
              children: [
                SizedBox(width: 32, child: Text('No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                Expanded(child: Text('Nama Siswa & NIS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                SizedBox(width: 80, child: Center(child: Text('Nilai', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))),
                SizedBox(width: 60, child: Center(child: Text('Predikat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Fast-Entry Student Rows
          Expanded(
            child: ListView.separated(
              itemCount: _siswaList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
              itemBuilder: (context, index) {
                final siswa = _siswaList[index];
                final isUnderKkm = siswa.nilai != null && siswa.nilai! < widget.kkm;
                final predikat = siswa.nilai != null
                    ? KalkulatorK13.tentukanPredikat(siswa.nilai!, widget.kkm)
                    : '-';

                return Container(
                  color: isUnderKkm ? const Color(0xFFFEF2F2) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // No
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),

                      // Nama & NIS & Badge Bawaan
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              siswa.nama,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Row(
                              children: [
                                Text(
                                  siswa.nis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                if (siswa.isBawaan) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Bawaan ${siswa.rombelAsal ?? ""}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Input Box Nilai
                      SizedBox(
                        width: 76,
                        height: 42,
                        child: TextField(
                          controller: siswa.controller,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          onChanged: (val) => _simpanNilai(index, val),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isUnderKkm ? const Color(0xFFDC2626) : AppTheme.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            fillColor: isUnderKkm ? const Color(0xFFFEE2E2) : AppTheme.sandGrey,
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isUnderKkm ? const Color(0xFFDC2626) : AppTheme.emeraldPrimary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Predikat K13 Pill
                      SizedBox(
                        width: 52,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: predikat == 'A'
                                  ? AppTheme.mintSurface
                                  : predikat == 'B'
                                      ? const Color(0xFFEFF6FF)
                                      : predikat == 'C'
                                          ? const Color(0xFFFEF3C7)
                                          : predikat == 'D'
                                              ? const Color(0xFFFEE2E2)
                                              : AppTheme.sandGrey,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              predikat,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: predikat == 'A'
                                    ? AppTheme.emeraldPrimary
                                    : predikat == 'B'
                                        ? const Color(0xFF2563EB)
                                        : predikat == 'C'
                                            ? const Color(0xFFD97706)
                                            : predikat == 'D'
                                                ? const Color(0xFFDC2626)
                                                : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
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
}
