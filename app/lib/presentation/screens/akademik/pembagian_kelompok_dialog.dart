import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';

class PembagianKelompokDialog extends ConsumerStatefulWidget {
  final String rombelId;
  final String rombelNama;
  final String mapelId;
  final String mapelNama;
  final String semesterId;

  const PembagianKelompokDialog({
    super.key,
    required this.rombelId,
    required this.rombelNama,
    required this.mapelId,
    required this.mapelNama,
    required this.semesterId,
  });

  @override
  ConsumerState<PembagianKelompokDialog> createState() => _PembagianKelompokDialogState();
}

class _PembagianKelompokDialogState extends ConsumerState<PembagianKelompokDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<PengampuData> _teachers = [];
  Map<String, String> _guruNamaMap = {};
  List<SiswaData> _students = [];
  Map<String, String> _keanggotaanMap = {}; // siswaId -> keanggotaanId
  final Map<String, String?> _assignment = {}; // siswaId -> pengampuId

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = ref.read(appDatabaseProvider);

    // 1. Ambil semua pengampu aktif untuk mapel & rombel ini
    final pengampuRows = await (db.select(db.pengampu)
          ..where((t) =>
              t.rombelId.equals(widget.rombelId) &
              t.mapelId.equals(widget.mapelId) &
              t.semesterId.equals(widget.semesterId) &
              t.tanggalSelesai.isNull() &
              t.deleted.equals(0)))
        .get();

    final guruIds = pengampuRows.map((p) => p.guruId).toList();
    final gurus = await (db.select(db.guru)..where((t) => t.id.isIn(guruIds))).get();
    final guruMap = {for (final g in gurus) g.id: g.namaLengkap};

    // 2. Ambil semua keanggotaan dan siswa aktif di rombel
    final studentQuery = db.select(db.keanggotaanRombel).join([
      innerJoin(db.siswa, db.siswa.id.equalsExp(db.keanggotaanRombel.siswaId)),
    ])
      ..where(
        db.keanggotaanRombel.rombelId.equals(widget.rombelId) &
            db.keanggotaanRombel.tanggalKeluar.isNull() &
            db.keanggotaanRombel.deleted.equals(0) &
            db.siswa.deleted.equals(0),
      )
      ..orderBy([OrderingTerm.asc(db.siswa.namaLengkap)]);

    final studentRows = await studentQuery.get();
    final students = studentRows.map((r) => r.readTable(db.siswa)).toList();
    final kMap = {
      for (final r in studentRows)
        r.readTable(db.siswa).id: r.readTable(db.keanggotaanRombel).id
    };

    // 3. Ambil pengampu_siswa eksisting
    final pengampuIds = pengampuRows.map((p) => p.id).toList();
    final psRows = await (db.select(db.pengampuSiswa)
          ..where((t) => t.pengampuId.isIn(pengampuIds) & t.deleted.equals(0)))
        .get();

    final keanggotaanToPengampu = {for (final ps in psRows) ps.keanggotaanId: ps.pengampuId};

    if (mounted) {
      setState(() {
        _teachers = pengampuRows;
        _guruNamaMap = guruMap;
        _students = students;
        _keanggotaanMap = kMap;

        for (final s in students) {
          final kId = kMap[s.id];
          _assignment[s.id] = kId != null ? keanggotaanToPengampu[kId] : null;
        }
        _isLoading = false;
      });
    }
  }

  void _bagiOtomatisGanjilGenap() {
    if (_teachers.isEmpty || _students.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      for (int i = 0; i < _students.length; i++) {
        final teacherIndex = i % _teachers.length;
        _assignment[_students[i].id] = _teachers[teacherIndex].id;
      }
    });
  }

  void _bagiRataUrutanAbsen() {
    if (_teachers.isEmpty || _students.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      final chunkSize = (_students.length / _teachers.length).ceil();
      for (int i = 0; i < _students.length; i++) {
        final teacherIndex = (i ~/ (chunkSize > 0 ? chunkSize : 1)).clamp(0, _teachers.length - 1);
        _assignment[_students[i].id] = _teachers[teacherIndex].id;
      }
    });
  }

  Future<void> _simpan() async {
    setState(() => _isSaving = true);
    final pengampuRepo = ref.read(pengampuRepoProvider);

    try {
      final pengampuToKeanggotaanMap = <String, List<String>>{};
      for (final s in _students) {
        final pengampuId = _assignment[s.id];
        final kId = _keanggotaanMap[s.id];
        if (pengampuId != null && kId != null) {
          pengampuToKeanggotaanMap.putIfAbsent(pengampuId, () => []).add(kId);
        }
      }

      await pengampuRepo.simpanPembagianKelompok(
        rombelId: widget.rombelId,
        mapelId: widget.mapelId,
        semesterId: widget.semesterId,
        pengampuToKeanggotaanMap: pengampuToKeanggotaanMap,
        deviceId: 'mobile-dev-001',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembagian kelompok siswa berhasil disimpan!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unassignedCount = _assignment.values.where((v) => v == null).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Bagi Kelompok: ${widget.mapelNama} (${widget.rombelNama})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info & Action Buttons Header
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daftar Guru Pengampu:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _teachers.map((t) {
                          final guruNama = _guruNamaMap[t.guruId] ?? 'Guru';
                          final isUtama = t.peran == 'utama';
                          final count = _assignment.values.where((v) => v == t.id).length;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isUtama ? AppColors.secondaryContainer : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isUtama ? AppColors.secondary : AppColors.outline,
                              ),
                            ),
                            child: Text(
                              '$guruNama (${isUtama ? "Utama" : "Pendamping"}) • $count Siswa',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isUtama ? AppColors.onSecondaryContainer : AppColors.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _bagiOtomatisGanjilGenap,
                              icon: const Icon(Icons.shuffle_rounded, size: 18, color: AppColors.primary),
                              label: const Text('Bagi Ganjil / Genap'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _bagiRataUrutanAbsen,
                              icon: const Icon(Icons.format_list_numbered_rounded, size: 18, color: AppColors.primary),
                              label: const Text('Bagi Rata Urutan'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (unassignedCount > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$unassignedCount siswa belum teralokasi (otomatis fallback ke Guru Utama)',
                                  style: const TextStyle(fontSize: 12, color: AppColors.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Student List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _students.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final siswa = _students[idx];
                      final assignedPengampuId = _assignment[siswa.id];

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
                                  Text(
                                    '${idx + 1}.',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      siswa.namaLengkap,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'NIS: ${siswa.nis}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Radio / Selector per teacher
                              Wrap(
                                spacing: 8,
                                children: _teachers.map((t) {
                                  final isSelected = assignedPengampuId == t.id;
                                  final gNama = _guruNamaMap[t.guruId] ?? 'Guru';
                                  return InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _assignment[siswa.id] = isSelected ? null : t.id;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primaryContainer : AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.outline,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        gNama,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? AppColors.onPrimaryContainer : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Save Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.outline)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _simpan,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_rounded),
                      label: const Text('Simpan Pembagian Kelompok'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
