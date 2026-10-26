class EmisImportRowData {
  final int rowIndex;
  final bool isValid;
  final List<String> errors;
  final String nik;
  final String noKk;
  final String nis;
  final String nisn;
  final String namaLengkap;
  final String jk;
  final String tempatLahir;
  final String tanggalLahir;
  final String namaIbu;
  final String namaAyah;
  final String jalan;
  final String desaNama;
  final String kecamatanNama;
  final String kabupatenNama;
  final String provinsiNama;

  EmisImportRowData({
    required this.rowIndex,
    required this.isValid,
    required this.errors,
    required this.nik,
    required this.noKk,
    required this.nis,
    required this.nisn,
    required this.namaLengkap,
    required this.jk,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.namaIbu,
    required this.namaAyah,
    required this.jalan,
    required this.desaNama,
    required this.kecamatanNama,
    required this.kabupatenNama,
    required this.provinsiNama,
  });
}

class EmisImportPreviewResult {
  final int totalRows;
  final int validCount;
  final int errorCount;
  final List<EmisImportRowData> rows;

  EmisImportPreviewResult({
    required this.totalRows,
    required this.validCount,
    required this.errorCount,
    required this.rows,
  });
}

class EmisCsvHelper {
  static const List<String> emisHeaders = [
    'NO',
    'NIK',
    'NO KK',
    'NIS',
    'NISN',
    'NAMA LENGKAP',
    'JK',
    'TEMPAT LAHIR',
    'TANGGAL LAHIR (YYYY-MM-DD)',
    'NAMA IBU',
    'NAMA AYAH',
    'ALAMAT JALAN',
    'DESA/KELURAHAN',
    'KECAMATAN',
    'KABUPATEN/KOTA',
    'PROVINSI',
  ];

  static const List<String> sampleRow = [
    '1',
    '3301011205120001',
    '3301010101100002',
    '1001',
    '0081234567',
    'Ahmad Fauzi',
    'L',
    'Semarang',
    '2012-05-12',
    'Siti Aminah',
    'Abdul Somad',
    'Jl. Pesantren No. 12',
    'Kauman',
    'Semarang Tengah',
    'Kota Semarang',
    'Jawa Tengah',
  ];

  /// Meng-escape satu nilai cell sesuai spesifikasi RFC-4180
  static String escapeCsvCell(String? value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Membuat string CSV template EMIS kosong lengkap dengan baris contoh
  static String generateTemplateCsv() {
    final buffer = StringBuffer();
    // UTF-8 BOM untuk kompatibilitas aplikasi spreadsheet
    buffer.write('\uFEFF');
    buffer.writeln(emisHeaders.map(escapeCsvCell).join(','));
    buffer.writeln(sampleRow.map(escapeCsvCell).join(','));
    return buffer.toString();
  }

  /// Membuat string CSV dari kumpulan data baris siswa
  static String generateExportCsv(List<List<String>> dataRows) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(emisHeaders.map(escapeCsvCell).join(','));
    for (final row in dataRows) {
      buffer.writeln(row.map(escapeCsvCell).join(','));
    }
    return buffer.toString();
  }

  /// Parser RFC-4180 robust tanpa dependensi eksternal
  static List<List<String>> parseCsvString(String csvContent) {
    final cleanContent = csvContent.replaceFirst('\uFEFF', '');
    final List<List<String>> rows = [];
    List<String> currentRow = [];
    final StringBuffer currentCell = StringBuffer();
    bool insideQuotes = false;
    int i = 0;

    while (i < cleanContent.length) {
      final char = cleanContent[i];

      if (insideQuotes) {
        if (char == '"') {
          // Periksa apakah ini escaped quote ("")
          if (i + 1 < cleanContent.length && cleanContent[i + 1] == '"') {
            currentCell.write('"');
            i += 2;
            continue;
          } else {
            insideQuotes = false;
            i++;
            continue;
          }
        } else {
          currentCell.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
          continue;
        } else if (char == ',') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < cleanContent.length && cleanContent[i + 1] == '\n') {
            i++; // Lewati \r\n
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = [];
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = [];
          i++;
          continue;
        } else {
          currentCell.write(char);
          i++;
          continue;
        }
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  /// Memvalidasi berkas CSV EMIS baris-demi-baris secara offline
  static EmisImportPreviewResult validateAndPreviewCsv(
    String csvContent, {
    Set<String> existingNisSet = const {},
  }) {
    final rawRows = parseCsvString(csvContent);
    if (rawRows.length < 2) {
      return EmisImportPreviewResult(totalRows: 0, validCount: 0, errorCount: 0, rows: []);
    }

    final List<EmisImportRowData> parsedList = [];
    int validCount = 0;
    int errorCount = 0;
    final Set<String> batchNisSet = {};

    for (int idx = 1; idx < rawRows.length; idx++) {
      final r = rawRows[idx];
      if (r.isEmpty || r.every((c) => c.isEmpty)) continue;

      final nik = r.length > 1 ? r[1].trim() : '';
      final noKk = r.length > 2 ? r[2].trim() : '';
      final nis = r.length > 3 ? r[3].trim() : '';
      final nisn = r.length > 4 ? r[4].trim() : '';
      final nama = r.length > 5 ? r[5].trim() : '';
      final jk = r.length > 6 ? r[6].trim().toUpperCase() : '';
      final tempatLahir = r.length > 7 ? r[7].trim() : '';
      final tanggalLahir = r.length > 8 ? r[8].trim() : '';
      final namaIbu = r.length > 9 ? r[9].trim() : '';
      final namaAyah = r.length > 10 ? r[10].trim() : '';
      final jalan = r.length > 11 ? r[11].trim() : '';
      final desaNama = r.length > 12 ? r[12].trim() : '';
      final kecamatanNama = r.length > 13 ? r[13].trim() : '';
      final kabupatenNama = r.length > 14 ? r[14].trim() : '';
      final provinsiNama = r.length > 15 ? r[15].trim() : '';

      final List<String> errors = [];

      if (nama.isEmpty) {
        errors.add('Nama lengkap siswa wajib diisi');
      }
      if (nis.isEmpty) {
        errors.add('NIS wajib diisi');
      } else {
        if (existingNisSet.contains(nis)) {
          errors.add("NIS '$nis' sudah terdaftar di database");
        }
        if (batchNisSet.contains(nis)) {
          errors.add("NIS '$nis' duplikat di dalam file impor ini");
        }
        batchNisSet.add(nis);
      }

      if (jk != 'L' && jk != 'P') {
        errors.add("Jenis kelamin harus 'L' atau 'P' (terdeteksi '$jk')");
      }

      if (tanggalLahir.isNotEmpty) {
        final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
        if (!dateRegex.hasMatch(tanggalLahir)) {
          errors.add("Format tanggal lahir harus YYYY-MM-DD (terdeteksi '$tanggalLahir')");
        }
      }

      final isValid = errors.isEmpty;
      if (isValid) {
        validCount++;
      } else {
        errorCount++;
      }

      parsedList.add(EmisImportRowData(
        rowIndex: idx + 1,
        isValid: isValid,
        errors: errors,
        nik: nik,
        noKk: noKk,
        nis: nis,
        nisn: nisn,
        namaLengkap: nama,
        jk: jk,
        tempatLahir: tempatLahir,
        tanggalLahir: tanggalLahir,
        namaIbu: namaIbu,
        namaAyah: namaAyah,
        jalan: jalan,
        desaNama: desaNama,
        kecamatanNama: kecamatanNama,
        kabupatenNama: kabupatenNama,
        provinsiNama: provinsiNama,
      ));
    }

    return EmisImportPreviewResult(
      totalRows: parsedList.length,
      validCount: validCount,
      errorCount: errorCount,
      rows: parsedList,
    );
  }
}
