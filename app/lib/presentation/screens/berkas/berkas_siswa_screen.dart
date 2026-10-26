import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/berkas_util.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';
import 'sandboxed_viewer_screen.dart';

class BerkasSiswaScreen extends ConsumerStatefulWidget {
  final String siswaId;
  final String namaSiswa;

  const BerkasSiswaScreen({
    super.key,
    required this.siswaId,
    required this.namaSiswa,
  });

  @override
  ConsumerState<BerkasSiswaScreen> createState() => _BerkasSiswaScreenState();
}

class _BerkasSiswaScreenState extends ConsumerState<BerkasSiswaScreen> {
  List<SiswaBerkasData> _berkasList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBerkas();
  }

  Future<void> _loadBerkas() async {
    setState(() => _isLoading = true);
    final repo = ref.read(berkasRepoProvider);
    final list = await repo.getBerkasForSiswa(widget.siswaId);
    if (mounted) {
      setState(() {
        _berkasList = list;
        _isLoading = false;
      });
    }
  }

  void _bukaViewer(SiswaBerkasData berkas) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SandboxedViewerScreen(
          berkas: berkas,
          namaSiswa: widget.namaSiswa,
        ),
      ),
    );
  }

  void _showUploadDialog() {
    String selectedKode = 'KK';
    final namaController = TextEditingController(text: 'Kartu_Keluarga.jpg');
    String mockContentType = 'JPG';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Unggah Berkas Sandboxed'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jenis Berkas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('jenis_$selectedKode'),
                    initialValue: selectedKode,
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)),
                    items: const [
                      DropdownMenuItem(value: 'KK', child: Text('Kartu Keluarga (KK)')),
                      DropdownMenuItem(value: 'AKTA', child: Text('Akta Kelahiran')),
                      DropdownMenuItem(value: 'IJAZAH', child: Text('Ijazah SD/MI')),
                      DropdownMenuItem(value: 'FOTO', child: Text('Pasfoto Siswa (3x4)')),
                      DropdownMenuItem(value: 'KIP', child: Text('Kartu Indonesia Pintar (KIP)')),
                      DropdownMenuItem(value: 'LAINNYA', child: Text('Dokumen Lainnya')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedKode = val;
                          namaController.text = '${val}_${widget.namaSiswa.replaceAll(' ', '_')}.${mockContentType.toLowerCase()}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Nama Tampil Berkas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: namaController,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Contoh: Ijazah_Ahmad.pdf'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Tipe Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'JPG', label: Text('JPG (Foto)')),
                      ButtonSegment(value: 'PNG', label: Text('PNG')),
                      ButtonSegment(value: 'PDF', label: Text('PDF (Dokumen)')),
                    ],
                    selected: {mockContentType},
                    onSelectionChanged: (setVal) {
                      setDialogState(() {
                        mockContentType = setVal.first;
                        final base = namaController.text.split('.').first;
                        namaController.text = '$base.${mockContentType.toLowerCase()}';
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('Simpan & Enkripsi'),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _prosesSimpanBerkas(selectedKode, namaController.text, mockContentType);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _prosesSimpanBerkas(String jenisKode, String namaFile, String type) async {
    // Generate data byte valid dengan magic bytes
    Uint8List dummyBytes;
    if (type == 'JPG') {
      dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(256, 65)]);
    } else if (type == 'PNG') {
      dummyBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, ...List.filled(256, 66)]);
    } else {
      dummyBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, ...List.filled(256, 67)]);
    }

    try {
      final repo = ref.read(berkasRepoProvider);
      final currentUser = ref.read(currentUserProvider);
      await repo.simpanBerkasSiswa(
        siswaId: widget.siswaId,
        jenisBerkasKode: jenisKode,
        namaTampil: namaFile,
        bytes: dummyBytes,
        diunggahOlehUserId: currentUser.userId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berkas $namaFile berhasil disimpan dan diantrekan untuk sinkron'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadBerkas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan berkas: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _konfirmasiHapus(SiswaBerkasData berkas) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Berkas?'),
        content: Text('Apakah Anda yakin ingin menghapus berkas "${berkas.namaTampil}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final repo = ref.read(berkasRepoProvider);
      await repo.hapusBerkasSiswa(berkas.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berkas berhasil dihapus')),
      );
      _loadBerkas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Berkas Siswa: ${widget.namaSiswa}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Tambah Berkas'),
        onPressed: _showUploadDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _berkasList.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _berkasList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = _berkasList[index];
                    final isPdf = b.mimeType == 'application/pdf';
                    final isPending = b.statusUnggah == 'PENDING';

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.outline, width: 1),
                      ),
                      child: ListTile(
                        onTap: () => _bukaViewer(b),
                        leading: CircleAvatar(
                          backgroundColor: isPdf ? const Color(0xFFFEE2E2) : AppColors.primaryContainer,
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                            color: isPdf ? AppColors.danger : AppColors.primary,
                          ),
                        ),
                        title: Text(
                          b.namaTampil,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${BerkasUtil.getLabelJenisBerkas(b.jenisBerkasKode)} • ${(b.ukuranByte / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isPending ? AppColors.warningSoft : AppColors.successSoft,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isPending ? 'Antrean Sync' : 'Tersinkron',
                                    style: TextStyle(
                                      color: isPending ? AppColors.warning : AppColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'FLAG_SECURE',
                                  style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () => _konfirmasiHapus(b),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 64, color: AppColors.textHint),
          SizedBox(height: 16),
          Text(
            'Belum ada berkas terunggah',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Ketuk tombol di bawah untuk mengunggah KK, Akta,\nIjazah, atau Pasfoto siswa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
