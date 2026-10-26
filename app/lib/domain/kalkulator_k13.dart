/// Model hasil kalkulasi nilai K13 on-the-fly sesuai PRD Bagian 5.4 & F10.
class HasilKalkulasiK13 {
  final double nilaiAkhir;
  final String predikat; // 'A' | 'B' | 'C' | 'D'
  final bool tuntas;
  final String keterangan;

  const HasilKalkulasiK13({
    required this.nilaiAkhir,
    required this.predikat,
    required this.tuntas,
    required this.keterangan,
  });
}

/// Model hasil kalkulasi lengkap K13 (memisahkan aspek Pengetahuan KD3 & Keterampilan KD4)
class HasilKalkulasiMapelK13 {
  final double rataRataPengetahuan;
  final String predikatPengetahuan;
  final double rataRataKeterampilan;
  final String predikatKeterampilan;
  final double nilaiAkhir;
  final String predikat;
  final bool tuntas;
  final double kkm;
  final String keterangan;

  const HasilKalkulasiMapelK13({
    required this.rataRataPengetahuan,
    required this.predikatPengetahuan,
    required this.rataRataKeterampilan,
    required this.predikatKeterampilan,
    required this.nilaiAkhir,
    required this.predikat,
    required this.tuntas,
    required this.kkm,
    required this.keterangan,
  });
}

class KalkulatorK13 {
  /// Menghitung interval predikat: (100 - KKM) / 3
  static double hitungInterval(double kkm) {
    if (kkm >= 100) return 1.0;
    return (100.0 - kkm) / 3.0;
  }

  /// Menentukan predikat Kurikulum 2013 berdasarkan KKM dan interval
  /// - D : Nilai < KKM (Remedial / Belum Tuntas)
  /// - C : KKM <= Nilai < KKM + interval
  /// - B : KKM + interval <= Nilai < KKM + (2 * interval)
  /// - A : Nilai >= KKM + (2 * interval)
  static String tentukanPredikat(double nilai, double kkm) {
    if (nilai < kkm) {
      return 'D';
    }
    final interval = hitungInterval(kkm);
    final batasB = kkm + interval;
    final batasA = kkm + (2.0 * interval);

    if (nilai >= batasA) {
      return 'A';
    } else if (nilai >= batasB) {
      return 'B';
    } else {
      return 'C';
    }
  }

  /// Menghitung Nilai Akhir dari kumpulan nilai terbobot
  /// [rataRataPerJenis]: Map { jenisNilaiId: rata_rata_nilai }
  /// [bobotPerJenis]: Map { jenisNilaiId: bobot }
  static HasilKalkulasiK13 hitungNilaiAkhir({
    required Map<String, double> rataRataPerJenis,
    required Map<String, double> bobotPerJenis,
    required double kkm,
  }) {
    if (rataRataPerJenis.isEmpty) {
      return const HasilKalkulasiK13(
        nilaiAkhir: 0.0,
        predikat: 'D',
        tuntas: false,
        keterangan: 'Belum ada nilai',
      );
    }

    double totalNilaiKaliBobot = 0.0;
    double totalBobotAktif = 0.0;

    for (final entry in rataRataPerJenis.entries) {
      final jenisId = entry.key;
      final rataNilai = entry.value;
      final bobot = bobotPerJenis[jenisId] ?? 1.0;

      totalNilaiKaliBobot += (rataNilai * bobot);
      totalBobotAktif += bobot;
    }

    if (totalBobotAktif == 0.0) {
      return const HasilKalkulasiK13(
        nilaiAkhir: 0.0,
        predikat: 'D',
        tuntas: false,
        keterangan: 'Bobot komponen tidak valid',
      );
    }

    final nilaiAkhir = totalNilaiKaliBobot / totalBobotAktif;
    // Pembulatan standar 2 desimal
    final rounded = double.parse(nilaiAkhir.toStringAsFixed(2));
    final predikat = tentukanPredikat(rounded, kkm);
    final tuntas = rounded >= kkm;

    return HasilKalkulasiK13(
      nilaiAkhir: rounded,
      predikat: predikat,
      tuntas: tuntas,
      keterangan: tuntas ? 'Tuntas' : 'Perlu Remedial',
    );
  }

  /// Menghitung kalkulasi lengkap K13 yang memisahkan aspek Pengetahuan dan Keterampilan
  /// [kategoriPerJenis]: Map { jenisNilaiId: 'pengetahuan' | 'keterampilan' }
  static HasilKalkulasiMapelK13 hitungK13Lengkap({
    required Map<String, double> rataRataPerJenis,
    required Map<String, double> bobotPerJenis,
    required Map<String, String> kategoriPerJenis,
    required double kkm,
  }) {
    final pengetahuanMap = <String, double>{};
    final keterampilanMap = <String, double>{};

    for (final entry in rataRataPerJenis.entries) {
      final jenisId = entry.key;
      final kategori = kategoriPerJenis[jenisId] ?? 'pengetahuan';
      if (kategori == 'keterampilan') {
        keterampilanMap[jenisId] = entry.value;
      } else {
        pengetahuanMap[jenisId] = entry.value;
      }
    }

    final hasilPengetahuan = hitungNilaiAkhir(
      rataRataPerJenis: pengetahuanMap,
      bobotPerJenis: bobotPerJenis,
      kkm: kkm,
    );

    final hasilKeterampilan = hitungNilaiAkhir(
      rataRataPerJenis: keterampilanMap,
      bobotPerJenis: bobotPerJenis,
      kkm: kkm,
    );

    // Nilai Akhir Mapel:
    // Jika kedua ranah ada, rata-rata dari pengetahuan dan keterampilan.
    // Jika hanya salah satu ranah yang ada, gunakan ranah yang tersedia.
    double finalScore;
    if (pengetahuanMap.isNotEmpty && keterampilanMap.isNotEmpty) {
      finalScore = (hasilPengetahuan.nilaiAkhir + hasilKeterampilan.nilaiAkhir) / 2.0;
    } else if (pengetahuanMap.isNotEmpty) {
      finalScore = hasilPengetahuan.nilaiAkhir;
    } else if (keterampilanMap.isNotEmpty) {
      finalScore = hasilKeterampilan.nilaiAkhir;
    } else {
      finalScore = 0.0;
    }

    final rounded = double.parse(finalScore.toStringAsFixed(2));
    final predikat = tentukanPredikat(rounded, kkm);
    final tuntas = rounded >= kkm;

    return HasilKalkulasiMapelK13(
      rataRataPengetahuan: hasilPengetahuan.nilaiAkhir,
      predikatPengetahuan: hasilPengetahuan.predikat,
      rataRataKeterampilan: hasilKeterampilan.nilaiAkhir,
      predikatKeterampilan: hasilKeterampilan.predikat,
      nilaiAkhir: rounded,
      predikat: predikat,
      tuntas: tuntas,
      kkm: kkm,
      keterangan: tuntas ? 'Tuntas' : 'Perlu Remedial',
    );
  }

  /// Menghitung peringkat (ranking) daftar siswa berdasarkan skor rata-rata (descending)
  /// Mengembalikan list of tuple atau map yang mengaitkan ID dengan peringkat
  static Map<String, int> hitungRanking(Map<String, double> nilaiSiswaMap) {
    if (nilaiSiswaMap.isEmpty) return {};

    final sortedEntries = nilaiSiswaMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rankingMap = <String, int>{};
    int currentRank = 1;

    for (int i = 0; i < sortedEntries.length; i++) {
      if (i > 0 && sortedEntries[i].value < sortedEntries[i - 1].value) {
        currentRank = i + 1;
      }
      rankingMap[sortedEntries[i].key] = currentRank;
    }

    return rankingMap;
  }
}
