import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/kalkulator_k13.dart';

void main() {
  group('Kalkulator K13 Kurikulum 2013 Tests', () {
    test('Perhitungan interval predikat dengan KKM 75', () {
      final interval = KalkulatorK13.hitungInterval(75.0);
      // (100 - 75) / 3 = 8.333333333333334
      expect(interval, closeTo(8.33, 0.01));
    });

    test('Penetapan predikat A, B, C, D dengan KKM 75', () {
      // KKM = 75.0, Interval = 8.33
      // D < 75.0
      // 75.0 <= C < 83.33
      // 83.33 <= B < 91.67
      // A >= 91.67
      expect(KalkulatorK13.tentukanPredikat(70.0, 75.0), 'D');
      expect(KalkulatorK13.tentukanPredikat(75.0, 75.0), 'C');
      expect(KalkulatorK13.tentukanPredikat(80.0, 75.0), 'C');
      expect(KalkulatorK13.tentukanPredikat(85.0, 75.0), 'B');
      expect(KalkulatorK13.tentukanPredikat(92.0, 75.0), 'A');
      expect(KalkulatorK13.tentukanPredikat(100.0, 75.0), 'A');
    });

    test('Perhitungan Nilai Akhir Terbobot', () {
      // Misal: Tugas rata-rata 80 (bobot 1), UH rata-rata 85 (bobot 2), PAS 90 (bobot 3)
      // Total nilai kali bobot: (80*1) + (85*2) + (90*3) = 80 + 170 + 270 = 520
      // Total bobot: 1 + 2 + 3 = 6
      // Nilai akhir: 520 / 6 = 86.67 -> Predikat B (KKM 75)
      final hasil = KalkulatorK13.hitungNilaiAkhir(
        rataRataPerJenis: {
          'tgs': 80.0,
          'uh': 85.0,
          'pas': 90.0,
        },
        bobotPerJenis: {
          'tgs': 1.0,
          'uh': 2.0,
          'pas': 3.0,
        },
        kkm: 75.0,
      );

      expect(hasil.nilaiAkhir, closeTo(86.67, 0.01));
      expect(hasil.predikat, 'B');
      expect(hasil.tuntas, isTrue);
      expect(hasil.keterangan, 'Tuntas');
    });

    test('Kasus nilai remedial di bawah KKM', () {
      final hasil = KalkulatorK13.hitungNilaiAkhir(
        rataRataPerJenis: {
          'uh': 60.0,
          'tgs': 65.0,
        },
        bobotPerJenis: {
          'uh': 1.0,
          'tgs': 1.0,
        },
        kkm: 75.0,
      );

      expect(hasil.nilaiAkhir, 62.5);
      expect(hasil.predikat, 'D');
      expect(hasil.tuntas, isFalse);
      expect(hasil.keterangan, 'Perlu Remedial');
    });
  });
}
