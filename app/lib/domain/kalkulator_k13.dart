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
}
