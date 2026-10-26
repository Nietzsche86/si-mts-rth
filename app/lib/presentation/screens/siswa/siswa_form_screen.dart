import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/db/app_database.dart';
import '../../../data/providers/database_providers.dart';

class SiswaFormScreen extends ConsumerStatefulWidget {
  final String? siswaId;
  final String namaLengkap;
  final String nis;
  final String? nisn;
  final String jk;

  const SiswaFormScreen({
    super.key,
    this.siswaId,
    required this.namaLengkap,
    required this.nis,
    this.nisn,
    this.jk = 'L',
  });

  @override
  ConsumerState<SiswaFormScreen> createState() => _SiswaFormScreenState();
}

class _SiswaFormScreenState extends ConsumerState<SiswaFormScreen> {
  int _currentSectionIndex = 0;
  final List<String> _sections = [
    'A. Data Diri',
    'B. Orang Tua',
    'C. Wali',
    'D. Alamat',
    'E. Sensitif',
    'F. Rekam Jejak',
    'G. Berkas',
  ];

  // Controllers
  late TextEditingController _namaController;
  late TextEditingController _nisController;
  late TextEditingController _nisnController;
  late TextEditingController _ayahController;
  late TextEditingController _ibuController;
  late TextEditingController _waliController;
  late TextEditingController _jalanController;
  late TextEditingController _desaController;
  late TextEditingController _kecamatanController;
  late TextEditingController _kabupatenController;

  late String _selectedJk;
  int _completenessPercentage = 80;

  // Sensitive unmask state
  bool _isNikUnmasked = false;
  int _unmaskRemainingSeconds = 0;
  Timer? _unmaskTimer;
  bool _hasWali = false;

  @override
  void initState() {
    super.initState();
    _selectedJk = widget.jk;
    _namaController = TextEditingController(text: widget.namaLengkap);
    _nisController = TextEditingController(text: widget.nis);
    _nisnController = TextEditingController(text: widget.nisn ?? '');
    _ayahController = TextEditingController(text: 'Abdul Somad');
    _ibuController = TextEditingController(text: 'Siti Aminah');
    _waliController = TextEditingController();
    _jalanController = TextEditingController(text: 'Jl. Pesantren No. 12');
    _desaController = TextEditingController(text: 'Kauman');
    _kecamatanController = TextEditingController(text: 'Semarang Tengah');
    _kabupatenController = TextEditingController(text: 'Kota Semarang');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileFromDb();
    });
  }

  Future<void> _loadProfileFromDb() async {
    if (widget.siswaId == null) return;
    try {
      final repo = ref.read(siswaRepoProvider);
      final profile = await repo.getSiswaFullProfile(widget.siswaId!);
      if (profile != null && mounted) {
        setState(() {
          _namaController.text = profile.siswa.namaLengkap;
          _nisController.text = profile.siswa.nis;
          _nisnController.text = profile.siswa.nisn ?? '';
          _selectedJk = profile.siswa.jk;

          final ayah = profile.ortuList.where((o) => o.hubungan == 'ayah').firstOrNull;
          final ibu = profile.ortuList.where((o) => o.hubungan == 'ibu').firstOrNull;
          final wali = profile.ortuList.where((o) => o.hubungan == 'wali').firstOrNull;

          if (ayah != null) _ayahController.text = ayah.namaLengkap;
          if (ibu != null) _ibuController.text = ibu.namaLengkap;
          if (wali != null) {
            _hasWali = true;
            _waliController.text = wali.namaLengkap;
          }

          if (profile.alamat != null) {
            _jalanController.text = profile.alamat!.jalan ?? '';
            _desaController.text = profile.alamat!.desaNama ?? '';
            _kecamatanController.text = profile.alamat!.kecamatanNama ?? '';
            _kabupatenController.text = profile.alamat!.kabupatenNama ?? '';
          }

          _completenessPercentage = profile.completenessPercentage;
        });
      }
    } catch (e) {
      debugPrint('[SiswaForm] Error loading profile: $e');
    }
  }

  @override
  void dispose() {
    _unmaskTimer?.cancel();
    _namaController.dispose();
    _nisController.dispose();
    _nisnController.dispose();
    _ayahController.dispose();
    _ibuController.dispose();
    _waliController.dispose();
    _jalanController.dispose();
    _desaController.dispose();
    _kecamatanController.dispose();
    _kabupatenController.dispose();
    super.dispose();
  }

  Future<void> _unmaskSensitiveData() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isNikUnmasked = true;
      _unmaskRemainingSeconds = 15;
    });

    // Catat ke Audit Log sesuai PRD
    try {
      final repo = ref.read(siswaRepoProvider);
      final user = ref.read(currentUserProvider);
      final deviceId = ref.read(activeDeviceIdProvider);

      await repo.logSensitifAccess(
        siswaId: widget.siswaId ?? 'siswa-001',
        kolom: 'nik_siswa',
        userId: user.userId,
        deviceId: deviceId,
      );
    } catch (e) {
      debugPrint('[SiswaForm] Error logging sensitive access: $e');
    }

    _unmaskTimer?.cancel();
    _unmaskTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_unmaskRemainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isNikUnmasked = false;
            _unmaskRemainingSeconds = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _unmaskRemainingSeconds--;
          });
        }
      }
    });
  }

  void _salinAlamatOrtu() {
    HapticFeedback.lightImpact();
    setState(() {
      _jalanController.text = 'Jl. Pesantren No. 12';
      _desaController.text = 'Kauman';
      _kecamatanController.text = 'Semarang Tengah';
      _kabupatenController.text = 'Kota Semarang';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alamat disalin dari Kartu Keluarga / Orang Tua'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _simpanData() async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);
    final nowMs = now.toUtc().millisecondsSinceEpoch;

    final user = ref.read(currentUserProvider);
    final deviceId = ref.read(activeDeviceIdProvider);
    final repo = ref.read(siswaRepoProvider);

    final id = widget.siswaId ?? 'siswa-${_nisController.text}';
    final isWali = user.isWaliKelas;

    // Pelacakan kolom_ts per field (PRD 9.6)
    final tsJson = jsonEncode({
      'nama_lengkap': nowMs,
      'nis': nowMs,
      'nisn': nowMs,
      'jk': nowMs,
      'updated_at': nowMs,
    });

    final siswaData = SiswaData(
      id: id,
      nis: _nisController.text.trim(),
      nisn: _nisnController.text.trim().isNotEmpty ? _nisnController.text.trim() : null,
      namaLengkap: _namaController.text.trim(),
      jk: _selectedJk,
      statusAktif: 'aktif',
      diubahWaliKelas: isWali ? 1 : 0,
      createdAt: nowEpoch,
      updatedAt: nowEpoch,
      deleted: 0,
      deviceId: deviceId,
    );

    final detailData = SiswaDetailData(
      id: 'detail-$id',
      siswaId: id,
      penerimaKip: 0,
      penerimaKps: 0,
      penerimaPkh: 0,
      diubahWaliKelas: isWali ? 1 : 0,
      kolomTs: tsJson,
      createdAt: nowEpoch,
      updatedAt: nowEpoch,
      deleted: 0,
      deviceId: deviceId,
    );

    final ortuList = <SiswaOrtuData>[
      SiswaOrtuData(
        id: 'ortu-ayah-$id',
        siswaId: id,
        hubungan: 'ayah',
        namaLengkap: _ayahController.text.trim(),
        diubahWaliKelas: isWali ? 1 : 0,
        kolomTs: tsJson,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
        deleted: 0,
        deviceId: deviceId,
      ),
      SiswaOrtuData(
        id: 'ortu-ibu-$id',
        siswaId: id,
        hubungan: 'ibu',
        namaLengkap: _ibuController.text.trim(),
        diubahWaliKelas: isWali ? 1 : 0,
        kolomTs: tsJson,
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
        deleted: 0,
        deviceId: deviceId,
      ),
    ];

    if (_hasWali && _waliController.text.trim().isNotEmpty) {
      ortuList.add(
        SiswaOrtuData(
          id: 'ortu-wali-$id',
          siswaId: id,
          hubungan: 'wali',
          namaLengkap: _waliController.text.trim(),
          diubahWaliKelas: isWali ? 1 : 0,
          kolomTs: tsJson,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
          deleted: 0,
          deviceId: deviceId,
        ),
      );
    }

    final alamatData = AlamatData(
      id: 'alamat-$id',
      pemilikTipe: 'siswa',
      pemilikId: id,
      siswaId: id,
      jalan: _jalanController.text.trim(),
      desaNama: _desaController.text.trim(),
      kecamatanNama: _kecamatanController.text.trim(),
      kabupatenNama: _kabupatenController.text.trim(),
      diubahWaliKelas: isWali ? 1 : 0,
      kolomTs: tsJson,
      createdAt: nowEpoch,
      updatedAt: nowEpoch,
      deleted: 0,
      deviceId: deviceId,
    );

    try {
      await repo.saveSiswaProfile(
        siswa: siswaData,
        detail: detailData,
        ortuList: ortuList,
        alamat: alamatData,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perubahan data siswa berhasil disimpan ke database lokal & antrean outbox')),
        );
      }
    } catch (e) {
      debugPrint('[SiswaForm] Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.namaLengkap.isNotEmpty ? widget.namaLengkap : 'Input Siswa Baru'),
        actions: [
          IconButton(
            onPressed: _simpanData,
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Simpan',
          ),
        ],
      ),
      body: Column(
        children: [
          // Kelengkapan Progress Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kelengkapan Berkas & Data',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.mintSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_completenessPercentage% Lengkap',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.emeraldPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _completenessPercentage / 100.0,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emeraldPrimary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Horizontal Modular Step Pills A-G
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: List.generate(_sections.length, (index) {
                final isSelected = _currentSectionIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(_sections[index]),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _currentSectionIndex = index;
                        });
                      }
                    },
                    selectedColor: AppTheme.emeraldPrimary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppTheme.emeraldPrimary : AppTheme.borderSubtle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),

          // Dynamic Section Form Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildSectionContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_currentSectionIndex) {
      case 0:
        return _buildSectionADataDiri();
      case 1:
        return _buildSectionBOrangTua();
      case 2:
        return _buildSectionCWali();
      case 3:
        return _buildSectionDAlamat();
      case 4:
        return _buildSectionESensitif();
      case 5:
        return _buildSectionFRekamJejak();
      case 6:
        return _buildSectionGBerkas();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionADataDiri() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField('Nama Lengkap', _namaController, 'Contoh: Ahmad Fauzi'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildTextField('NIS (Nomor Induk)', _nisController, '1001')),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField('NISN', _nisnController, '0081234567')),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Jenis Kelamin', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'L', label: Text('Laki-laki')),
            ButtonSegment(value: 'P', label: Text('Perempuan')),
          ],
          selected: {_selectedJk},
          onSelectionChanged: (setVal) {
            setState(() {
              _selectedJk = setVal.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSectionBOrangTua() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField('Nama Lengkap Ayah Kandung', _ayahController, 'Nama Ayah'),
        const SizedBox(height: 16),
        _buildTextField('Nama Lengkap Ibu Kandung', _ibuController, 'Nama Ibu'),
      ],
    );
  }

  Widget _buildSectionCWali() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          title: const Text('Tinggal Bersama / Memiliki Wali', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Aktifkan jika siswa diasuh wali di luar orang tua kandung'),
          value: _hasWali,
          onChanged: (val) {
            setState(() {
              _hasWali = val;
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_hasWali) ...[
          const SizedBox(height: 12),
          _buildTextField('Nama Lengkap Wali', _waliController, 'Nama Wali'),
        ],
      ],
    );
  }

  Widget _buildSectionDAlamat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _salinAlamatOrtu,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Sama dengan Alamat Orang Tua / KK'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.emeraldPrimary),
            foregroundColor: AppTheme.emeraldPrimary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField('Jalan / Gang / RT-RW', _jalanController, 'Jl. Pesantren No. 12'),
        const SizedBox(height: 16),
        _buildTextField('Desa / Kelurahan', _desaController, 'Kauman'),
        const SizedBox(height: 16),
        _buildTextField('Kecamatan', _kecamatanController, 'Semarang Tengah'),
        const SizedBox(height: 16),
        _buildTextField('Kabupaten / Kota', _kabupatenController, 'Kota Semarang'),
      ],
    );
  }

  Widget _buildSectionESensitif() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Security Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.warmGold, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data sensitif dilindungi enkripsi AES-256-GCM. Membuka visual disamarkan akan mengaktifkan audit log dan timer 15 detik.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // NIK Siswa Masked Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NIK Siswa (Nomor Induk Kependudukan)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isNikUnmasked ? '3301011205120001' : '3301••••••••0001',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2),
                  ),
                  if (_isNikUnmasked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_unmaskRemainingSeconds}s',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _unmaskSensitiveData,
                      icon: const Icon(Icons.visibility_outlined, color: AppTheme.emeraldPrimary),
                      tooltip: 'Buka Visual (15 detik)',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionFRekamJejak() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Riwayat Kelas & Mutasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildTimelineItem('2026/2027 Ganjil', 'Rombel 7A (Aktif)', isCurrent: true),
        _buildTimelineItem('15 Juli 2026', 'Pendaftaran Siswa Baru (Diterima)'),
      ],
    );
  }

  Widget _buildSectionGBerkas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.file_present_rounded, size: 48, color: AppTheme.emeraldPrimary),
              const SizedBox(height: 8),
              const Text('Foto Kartu Keluarga (KK)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Tersimpan di sandbox privat aplikasi', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Buka Berkas Privat'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(String title, String subtitle, {bool isCurrent = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
            color: isCurrent ? AppTheme.emeraldPrimary : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isCurrent ? AppTheme.emeraldPrimary : AppTheme.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
