import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/kalkulator_k13.dart';
import '../../../data/providers/database_providers.dart';

class InputNilaiScreen extends ConsumerStatefulWidget {
  final String rombelId;
  final String rombelNama;
  final String mapelId;
  final String mapelNama;
  final double kkm;
  final String semesterId;

  const InputNilaiScreen({
    super.key,
    this.rombelId = 'rombel-7a',
    required this.rombelNama,
    this.mapelId = 'mapel-arab',
    required this.mapelNama,
    this.kkm = 75.0,
    this.semesterId = 'sem-2026-ganjil',
  });

  @override
  ConsumerState<InputNilaiScreen> createState() => _InputNilaiScreenState();
}

class _SiswaRowItem {
  final String keanggotaanId;
  final String siswaId;
  final String nis;
  final String nama;
  double? nilai;
  final bool isBawaan;
  final String? rombelAsal;
  final TextEditingController controller;
  final FocusNode focusNode;

  _SiswaRowItem({
    required this.keanggotaanId,
    required this.siswaId,
    required this.nis,
    required this.nama,
    this.nilai,
    this.isBawaan = false,
    this.rombelAsal,
  })  : controller = TextEditingController(
          text: nilai != null
              ? (nilai % 1 == 0 ? nilai.toInt().toString() : nilai.toString())
              : '',
        ),
        focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _InputNilaiScreenState extends ConsumerState<InputNilaiScreen> {
  final List<String> _jenisNilaiList = ['TGS', 'UH', 'PAS', 'PAT', 'PRY', 'PRT', 'UK'];
  String _selectedJenis = 'UH';
  int _urutanKe = 1;

  List<_SiswaRowItem> _siswaList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    for (final s in _siswaList) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(penilaianRepoProvider);
      final rawList = await repo.getSiswaNilaiList(
        rombelId: widget.rombelId,
        mapelId: widget.mapelId,
        semesterId: widget.semesterId,
        jenisNilaiId: _selectedJenis,
        urutanKe: _urutanKe,
      );

      // Dispose previous controllers
      for (final s in _siswaList) {
        s.dispose();
      }

      _siswaList = rawList.map((item) {
        final row = _SiswaRowItem(
          keanggotaanId: item.keanggotaanId,
          siswaId: item.siswaId,
          nis: item.nis,
          nama: item.namaLengkap,
          nilai: item.nilaiAngka,
          isBawaan: item.isBawaanRombelAsal,
          rombelAsal: item.isBawaanRombelAsal ? '7B' : null,
        );

        // Auto-save saat input kehilangan fokus (Fast-Entry on blur)
        row.focusNode.addListener(() {
          if (!row.focusNode.hasFocus) {
            _simpanNilaiKeDb(row, row.controller.text);
          }
        });

        return row;
      }).toList();
    } catch (e) {
      debugPrint('[InputNilai] Error loading siswa: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _simpanNilaiKeDb(_SiswaRowItem siswa, String text) async {
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
        mapelId: widget.mapelId,
        semesterId: widget.semesterId,
        jenisNilaiId: _selectedJenis,
        urutanKe: _urutanKe,
        nilaiAngka: val,
        guruId: user.guruId ?? 'guru-001',
        deviceId: deviceId,
      );

      if (mounted) {
        setState(() {
          siswa.nilai = val;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('[InputNilai] Error saving nilai: $e');
    }
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
                            if (val != null && val != _urutanKe) {
                              setState(() => _urutanKe = val);
                              _loadData();
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
                            if (val && _selectedJenis != j) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedJenis = j);
                              _loadData();
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _siswaList.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada siswa aktif di rombel ini',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
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
                                                'Bawaan ${siswa.rombelAsal ?? "rombel asal"}',
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
                                    focusNode: siswa.focusNode,
                                    textAlign: TextAlign.center,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (val) => _simpanNilaiKeDb(siswa, val),
                                    onChanged: (val) {
                                      final numVal = double.tryParse(val.trim());
                                      setState(() {
                                        siswa.nilai = numVal;
                                      });
                                    },
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
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isUnderKkm ? const Color(0xFFF87171) : AppTheme.borderSubtle,
                                          width: isUnderKkm ? 1.5 : 1.0,
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
