import 'dart:typed_data';
import 'package:crypto/crypto.dart';

enum BerkasMimeType {
  jpeg('image/jpeg', 'JPG/JPEG'),
  png('image/png', 'PNG'),
  pdf('application/pdf', 'PDF'),
  unknown('application/octet-stream', 'Tidak Diketahui');

  final String mimeString;
  final String label;
  const BerkasMimeType(this.mimeString, this.label);
}

class BerkasValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BerkasMimeType mimeType;
  final int byteSize;
  final String sha256Checksum;
  final String namaTampil;

  BerkasValidationResult({
    required this.isValid,
    this.errorMessage,
    required this.mimeType,
    required this.byteSize,
    required this.sha256Checksum,
    required this.namaTampil,
  });

  String get formattedSize {
    if (byteSize < 1024) return '$byteSize B';
    if (byteSize < 1024 * 1024) return '${(byteSize / 1024).toStringAsFixed(1)} KB';
    return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class BerkasUtil {
  // Magic bytes signatures
  static const List<int> _jpegHeader = [0xFF, 0xD8, 0xFF];
  static const List<int> _pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  static const List<int> _pdfHeader = [0x25, 0x50, 0x44, 0x46]; // %PDF

  // Batas ukuran per PRD F5
  static const int maxImageSizeBytes = 1 * 1024 * 1024; // 1 MB untuk dokumen foto
  static const int targetCameraPhotoBytes = 100 * 1024; // ±100 KB untuk pasfoto (target ±480px)
  static const int maxPdfSizeBytes = 5 * 1024 * 1024; // 5 MB untuk dokumen PDF

  /// Memeriksa magic bytes di awal data biner untuk memastikan tipe file asli
  static BerkasMimeType detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == _jpegHeader[0] &&
        bytes[1] == _jpegHeader[1] &&
        bytes[2] == _jpegHeader[2]) {
      return BerkasMimeType.jpeg;
    }

    if (bytes.length >= 8 &&
        bytes[0] == _pngHeader[0] &&
        bytes[1] == _pngHeader[1] &&
        bytes[2] == _pngHeader[2] &&
        bytes[3] == _pngHeader[3] &&
        bytes[4] == _pngHeader[4] &&
        bytes[5] == _pngHeader[5] &&
        bytes[6] == _pngHeader[6] &&
        bytes[7] == _pngHeader[7]) {
      return BerkasMimeType.png;
    }

    if (bytes.length >= 4 &&
        bytes[0] == _pdfHeader[0] &&
        bytes[1] == _pdfHeader[1] &&
        bytes[2] == _pdfHeader[2] &&
        bytes[3] == _pdfHeader[3]) {
      return BerkasMimeType.pdf;
    }

    return BerkasMimeType.unknown;
  }

  /// Menghitung SHA-256 hash dari data biner berkas
  static String calculateSha256(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Memvalidasi berkas siswa sebelum diunggah/disimpan
  static BerkasValidationResult validateBerkas(Uint8List bytes, String filename) {
    if (bytes.isEmpty) {
      return BerkasValidationResult(
        isValid: false,
        errorMessage: 'Berkas kosong (0 bytes)',
        mimeType: BerkasMimeType.unknown,
        byteSize: 0,
        sha256Checksum: '',
        namaTampil: filename,
      );
    }

    final mime = detectMimeType(bytes);
    final hash = calculateSha256(bytes);

    if (mime == BerkasMimeType.unknown) {
      return BerkasValidationResult(
        isValid: false,
        errorMessage: 'Format berkas tidak valid. Hanya menerima file JPG, PNG, atau PDF asli.',
        mimeType: mime,
        byteSize: bytes.length,
        sha256Checksum: hash,
        namaTampil: filename,
      );
    }

    if ((mime == BerkasMimeType.jpeg || mime == BerkasMimeType.png) && bytes.length > maxImageSizeBytes) {
      return BerkasValidationResult(
        isValid: false,
        errorMessage: 'Ukuran foto melebihi batas 1 MB (Terdeteksi ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
        mimeType: mime,
        byteSize: bytes.length,
        sha256Checksum: hash,
        namaTampil: filename,
      );
    }

    if (mime == BerkasMimeType.pdf && bytes.length > maxPdfSizeBytes) {
      return BerkasValidationResult(
        isValid: false,
        errorMessage: 'Ukuran dokumen PDF melebihi batas 5 MB (Terdeteksi ${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)',
        mimeType: mime,
        byteSize: bytes.length,
        sha256Checksum: hash,
        namaTampil: filename,
      );
    }

    return BerkasValidationResult(
      isValid: true,
      mimeType: mime,
      byteSize: bytes.length,
      sha256Checksum: hash,
      namaTampil: filename,
    );
  }

  /// Mendapatkan nama kategori berkas yang rapi dari kodenya
  static String getLabelJenisBerkas(String kode) {
    switch (kode.toUpperCase()) {
      case 'KK':
        return 'Kartu Keluarga (KK)';
      case 'AKTA':
        return 'Akta Kelahiran';
      case 'IJAZAH':
        return 'Ijazah SD/MI';
      case 'FOTO':
        return 'Pasfoto Siswa (3x4)';
      case 'KIP':
        return 'Kartu Indonesia Pintar (KIP/PIP)';
      case 'MUTASI':
        return 'Surat Keterangan Pindah/Mutasi';
      case 'LAINNYA':
      default:
        return 'Dokumen Lainnya';
    }
  }
}
