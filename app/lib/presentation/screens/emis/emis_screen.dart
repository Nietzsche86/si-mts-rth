import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/emis_csv_helper.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';

class EmisScreen extends ConsumerStatefulWidget {
  const EmisScreen({super.key});

  @override
  ConsumerState<EmisScreen> createState() => _EmisScreenState();
}

class _EmisScreenState extends ConsumerState<EmisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<RombelData> _rombelList = [];
  String? _selectedExportRombelId;
  String? _selectedImportRombelId;
  bool _maskSensitif = true;
  String _exportPreviewText = '';
  bool _isExporting = false;

  // Impor state
  final TextEditingController _importCsvController = TextEditingController();
  EmisImportPreviewResult? _previewResult;
  bool _isValidating = false;
  bool _isCommitting = false;
  final String _tanggalMasuk = '2026-07-15';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRombelList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _importCsvController.dispose();
    super.dispose();
  }

  Future<void> _loadRombelList() async {
    final rombelRepo = ref.read(rombelRepoProvider);
    final list = await rombelRepo.getAllRombel();
    if (mounted) {
      setState(() {
        _rombelList = list;
        if (list.isNotEmpty) {
          _selectedExportRombelId = list.first.id;
          _selectedImportRombelId = list.first.id;
        }
      });
    }
  }

  Future<void> _generateExport() async {
    if (_selectedExportRombelId == null) return;
    setState(() => _isExporting = true);
    final emisRepo = ref.read(emisRepoProvider);
    final csv = await emisRepo.exportRombelToCsv(_selectedExportRombelId!, maskSensitif: _maskSensitif);
    if (mounted) {
      setState(() {
        _exportPreviewText = csv;
        _isExporting = false;
      });
    }
  }

  void _muatTemplateContoh() {
    _importCsvController.text = EmisCsvHelper.generateTemplateCsv();
    _validasiCsv();
  }

  Future<void> _validasiCsv() async {
    final text = _importCsvController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teks CSV masih kosong')),
      );
      return;
    }

    setState(() => _isValidating = true);
    final emisRepo = ref.read(emisRepoProvider);
    final result = await emisRepo.previewCsv(text);
    if (mounted) {
      setState(() {
        _previewResult = result;
        _isValidating = false;
      });
    }
  }

  Future<void> _commitImport() async {
    if (_previewResult == null || _previewResult!.validCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada baris valid untuk diimpor')),
      );
      return;
    }

    if (_selectedImportRombelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih rombel tujuan')),
      );
      return;
    }

    setState(() => _isCommitting = true);
    final emisRepo = ref.read(emisRepoProvider);
    final validRows = _previewResult!.rows.where((r) => r.isValid).toList();

    try {
      final res = await emisRepo.commitImportOffline(
        validRows: validRows,
        rombelId: _selectedImportRombelId!,
        tanggalMasuk: _tanggalMasuk,
      );

      if (mounted) {
        setState(() {
          _isCommitting = false;
          _previewResult = null;
          _importCsvController.clear();
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Impor Sukses'),
              ],
            ),
            content: Text(res.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCommitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal impor: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekspor & Impor EMIS Kemenag'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.file_upload_outlined), text: 'Ekspor EMIS'),
            Tab(icon: Icon(Icons.file_download_outlined), text: 'Impor EMIS Offline'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEksporTab(),
          _buildImporTab(),
        ],
      ),
    );
  }

  Widget _buildEksporTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Konfigurasi Ekspor Rombel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('export_rombel_$_selectedExportRombelId'),
                    isExpanded: true,
                    initialValue: _rombelList.any((r) => r.id == _selectedExportRombelId) ? _selectedExportRombelId : null,
                    decoration: const InputDecoration(labelText: 'Pilih Rombel Kelas', border: OutlineInputBorder()),
                    items: _rombelList.map((r) => DropdownMenuItem(value: r.id, child: Text('Kelas ${r.nama}'))).toList(),
                    onChanged: (val) => setState(() => _selectedExportRombelId = val),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Samarkan NIK & No KK', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('3201••••••••0004 (Direkomendasikan untuk privasi guru)', style: TextStyle(fontSize: 12)),
                    value: _maskSensitif,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _maskSensitif = val),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isExporting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.table_view_outlined),
                      label: const Text('Pratinjau Data CSV EMIS'),
                      onPressed: _isExporting ? null : _generateExport,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_exportPreviewText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hasil Ekspor CSV (Standar EMIS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Salin CSV'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _exportPreviewText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data CSV berhasil disalin ke papan klip')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _exportPreviewText,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImporTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Impor Data Siswa EMIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        icon: const Icon(Icons.article_outlined, size: 16),
                        label: const Text('Muat Contoh'),
                        onPressed: _muatTemplateContoh,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tempelkan isi file CSV berstandar EMIS (16 kolom) ke kolom di bawah:',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _importCsvController,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'NO,NIK,NO KK,NIS,NISN,NAMA LENGKAP,JK,TEMPAT LAHIR...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isValidating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.rule_outlined),
                      label: const Text('Validasi & Pratinjau Baris'),
                      onPressed: _isValidating ? null : _validasiCsv,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_previewResult != null) ...[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(6)),
                          child: Text('${_previewResult!.validCount} Valid', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        if (_previewResult!.errorCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(6)),
                            child: Text('${_previewResult!.errorCount} Error', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      key: ValueKey('import_rombel_$_selectedImportRombelId'),
                      isExpanded: true,
                      initialValue: _rombelList.any((r) => r.id == _selectedImportRombelId) ? _selectedImportRombelId : null,
                      decoration: const InputDecoration(labelText: 'Pilih Rombel Tujuan', border: OutlineInputBorder()),
                      items: _rombelList.map((r) => DropdownMenuItem(value: r.id, child: Text('Kelas ${r.nama}'))).toList(),
                      onChanged: (val) => setState(() => _selectedImportRombelId = val),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _isCommitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text('Terapkan Impor (${_previewResult!.validCount} Siswa)'),
                        onPressed: _isCommitting || _previewResult!.validCount == 0 ? null : _commitImport,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
