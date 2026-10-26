import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class PindahRombelDialog extends StatefulWidget {
  final String siswaNama;
  final String rombelAsalNama;
  final List<String> daftarRombelTujuan;
  final Function(String rombelTujuan, bool bawaNilai) onConfirm;

  const PindahRombelDialog({
    super.key,
    required this.siswaNama,
    required this.rombelAsalNama,
    required this.daftarRombelTujuan,
    required this.onConfirm,
  });

  @override
  State<PindahRombelDialog> createState() => _PindahRombelDialogState();
}

class _PindahRombelDialogState extends State<PindahRombelDialog> {
  late String _selectedRombel;
  bool _bawaNilai = true;

  @override
  void initState() {
    super.initState();
    _selectedRombel = widget.daftarRombelTujuan.isNotEmpty ? widget.daftarRombelTujuan.first : '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.mintSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: AppTheme.emeraldPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Pindah Rombel Siswa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student & Origin Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.sandGrey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.siswaNama,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rombel Asal: ${widget.rombelAsalNama}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Destination Picker
            const Text(
              'Pilih Rombel Tujuan:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderSubtle),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedRombel,
                  items: widget.daftarRombelTujuan.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRombel = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Checkbox Bawa Nilai
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Bawa Nilai ke rombel baru',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Nilai lama akan otomatis disalin dengan penanda sumber asli.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              value: _bawaNilai,
              activeColor: AppTheme.emeraldPrimary,
              onChanged: (val) {
                setState(() {
                  _bawaNilai = val ?? true;
                });
              },
            ),
            const SizedBox(height: 8),

            // Transactional Warning Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tindakan ini dieksekusi dalam satu transaksi atomik lokal dan masuk antrean sinkronisasi server.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            widget.onConfirm(_selectedRombel, _bawaNilai);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emeraldPrimary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Konfirmasi Pindah'),
        ),
      ],
    );
  }
}
