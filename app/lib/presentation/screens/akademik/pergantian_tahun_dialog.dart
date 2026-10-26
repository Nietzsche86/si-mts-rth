import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/database_providers.dart';

class PergantianTahunDialog extends ConsumerStatefulWidget {
  const PergantianTahunDialog({super.key});

  @override
  ConsumerState<PergantianTahunDialog> createState() => _PergantianTahunDialogState();
}

class _PergantianTahunDialogState extends ConsumerState<PergantianTahunDialog> {
  final _formKey = GlobalKey<FormState>();
  final _namaTahunController = TextEditingController(text: '2027/2028');
  final _tanggalMulaiController = TextEditingController(text: '2027-07-15');
  final _tanggalSelesaiController = TextEditingController(text: '2027-12-20');
  String _jenisSemester = 'ganjil';

  bool _salinRombel = true;
  bool _salinPengampu = true;
  bool _kunciSemesterLama = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _namaTahunController.dispose();
    _tanggalMulaiController.dispose();
    _tanggalSelesaiController.dispose();
    super.dispose();
  }

  Future<void> _prosesPergantian() async {
    if (!_formKey.currentState!.validate()) return;
    final activeSemester = ref.read(activeSemesterProvider);

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pergantian Tahun'),
        content: Text(
          'Anda akan membuat Tahun Ajaran Baru: ${_namaTahunController.text.trim()} '
          '(${_jenisSemester.toUpperCase()}).\n\n'
          'Opsi:\n'
          '• Salin Rombel: ${_salinRombel ? "Ya" : "Tidak"}\n'
          '• Salin Pengampu: ${_salinPengampu ? "Ya" : "Tidak"}\n'
          '• Kunci Semester Lama: ${_kunciSemesterLama ? "Ya" : "Tidak"}\n\n'
          'Lanjutkan proses?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    setState(() => _isProcessing = true);
    final rombelRepo = ref.read(rombelRepoProvider);

    try {
      final res = await rombelRepo.pergantianTahun(
        tahunAjaranLamaId: activeSemester.tahunAjaranId,
        namaTahunBaru: _namaTahunController.text.trim(),
        jenisSemesterBaru: _jenisSemester,
        tanggalMulai: _tanggalMulaiController.text.trim(),
        tanggalSelesai: _tanggalSelesaiController.text.trim(),
        salinRombel: _salinRombel,
        salinPengampu: _salinPengampu,
        kunciSemesterLama: _kunciSemesterLama,
        deviceId: 'mobile-dev-001',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil! Tahun Ajaran ${_namaTahunController.text} aktif. '
              'Rombel disalin: ${res["rombelCopied"]}, Pengampu disalin: ${res["pengampuCopied"]}',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal pergantian tahun: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Pergantian Tahun Ajaran', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _namaTahunController,
                decoration: const InputDecoration(
                  labelText: 'Nama Tahun Ajaran Baru',
                  hintText: 'Contoh: 2027/2028',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _jenisSemester,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  prefixIcon: Icon(Icons.timelapse_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'ganjil', child: Text('Semester 1 (Ganjil)')),
                  DropdownMenuItem(value: 'genap', child: Text('Semester 2 (Genap)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _jenisSemester = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tanggalMulaiController,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Mulai',
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _tanggalSelesaiController,
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Selesai',
                        hintText: 'YYYY-MM-DD',
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Opsi Otomasi:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              CheckboxListTile(
                value: _salinRombel,
                onChanged: (v) => setState(() => _salinRombel = v ?? true),
                title: const Text('Salin Rombel dari tahun sebelumnya', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _salinPengampu,
                onChanged: (v) => setState(() => _salinPengampu = v ?? true),
                title: const Text('Salin Pengampu dari semester sebelumnya', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _kunciSemesterLama,
                onChanged: (v) => setState(() => _kunciSemesterLama = v ?? true),
                title: const Text('Kunci semester sebelumnya', style: TextStyle(fontSize: 13)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _prosesPergantian,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Aktifkan Tahun Baru'),
        ),
      ],
    );
  }
}
