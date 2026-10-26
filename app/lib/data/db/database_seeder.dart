import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  /// Melakukan seeding data master dan data awal madrasah secara idempoten
  static Future<void> seedInitialData(AppDatabase db) async {
    final nowEpoch = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);
    const deviceId = 'device-initial-seeder';

    // Cek apakah madrasah sudah ada
    final existingMadrasah = await (db.select(db.madrasah)..limit(1)).getSingleOrNull();
    if (existingMadrasah != null) {
      return; // Sudah di-seed sebelumnya
    }

    await db.transaction(() async {
      // 1. Madrasah
      await db.into(db.madrasah).insert(
        MadrasahCompanion.insert(
          id: 'madrasah-001',
          nama: 'MTs Roudhotut Thowalib',
          npsn: const Value('20363311'),
          nsm: const Value('121233240015'),
          alamat: const Value('Jl. KH. Abdul Manan No. 12, Tanjung, Kec. Tirto, Pekalongan'),
          semesterAktifId: const Value('sem-2026-ganjil'),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 2. Tahun Ajaran & Semester
      await db.into(db.tahunAjaran).insert(
        TahunAjaranCompanion.insert(
          id: 'ta-2026-2027',
          nama: '2026/2027',
          tanggalMulai: '2026-07-15',
          tanggalSelesai: '2027-06-25',
          aktif: const Value(1),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.semester).insert(
        SemesterCompanion.insert(
          id: 'sem-2026-ganjil',
          tahunAjaranId: 'ta-2026-2027',
          jenis: 'ganjil',
          tanggalMulai: '2026-07-15',
          tanggalSelesai: '2026-12-20',
          dikunci: const Value(0),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 3. Mapel Standar Kemenag (14 Mapel)
      final mapelList = [
        ('mapel-qurhad', 'QH', 'Al-Qur\'an Hadis', 'A', 1),
        ('mapel-akidah', 'AA', 'Akidah Akhlak', 'A', 2),
        ('mapel-fikih', 'FIK', 'Fikih', 'A', 3),
        ('mapel-ski', 'SKI', 'Sejarah Kebudayaan Islam', 'A', 4),
        ('mapel-arab', 'ARB', 'Bahasa Arab', 'A', 5),
        ('mapel-ppkn', 'PPKN', 'Pendidikan Pancasila dan Kewarganegaraan', 'A', 6),
        ('mapel-ind', 'BIN', 'Bahasa Indonesia', 'A', 7),
        ('mapel-mat', 'MAT', 'Matematika', 'A', 8),
        ('mapel-ipa', 'IPA', 'Ilmu Pengetahuan Alam', 'A', 9),
        ('mapel-ips', 'IPS', 'Ilmu Pengetahuan Sosial', 'A', 10),
        ('mapel-ing', 'BIG', 'Bahasa Inggris', 'A', 11),
        ('mapel-sbk', 'SBK', 'Seni Budaya', 'B', 12),
        ('mapel-pjok', 'PJK', 'Pendidikan Jasmani, Olahraga dan Kesehatan', 'B', 13),
        ('mapel-prakarya', 'PRA', 'Prakarya', 'B', 14),
      ];

      for (final m in mapelList) {
        await db.into(db.mapel).insert(
          MapelCompanion.insert(
            id: m.$1,
            kode: m.$2,
            nama: m.$3,
            kelompok: m.$4,
            urutan: Value(m.$5),
            aktif: const Value(1),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
      }

      // 4. Jenis Nilai K13
      final jenisNilaiList = [
        ('TGS', 'Tugas', 'pengetahuan', 1),
        ('UH', 'Ulangan Harian', 'pengetahuan', 2),
        ('PAS', 'Penilaian Akhir Semester', 'pengetahuan', 3),
        ('PAT', 'Penilaian Akhir Tahun', 'pengetahuan', 4),
        ('PRY', 'Proyek', 'keterampilan', 5),
        ('PRT', 'Praktik', 'keterampilan', 6),
        ('UK', 'Uji Kinerja / Portofolio', 'keterampilan', 7),
      ];

      for (final jn in jenisNilaiList) {
        await db.into(db.jenisNilai).insert(
          JenisNilaiCompanion.insert(
            id: jn.$1,
            kode: jn.$1,
            nama: jn.$2,
            kategori: jn.$3,
            urutan: Value(jn.$4),
            aktif: const Value(1),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
      }

      // 5. Pengaturan KKM Global (75.0)
      await db.into(db.pengaturanKkm).insert(
        PengaturanKkmCompanion.insert(
          id: 'kkm-global-2026',
          semesterId: 'sem-2026-ganjil',
          kkm: const Value(75.0),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 6. Guru & User
      await db.into(db.guru).insert(
        GuruCompanion.insert(
          id: 'guru-001',
          namaLengkap: 'Drs. H. Ahmad Dahlan, M.Pd.I',
          nip: const Value('197508122003121002'),
          jk: 'L',
          aktif: const Value(1),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.guru).insert(
        GuruCompanion.insert(
          id: 'guru-002',
          namaLengkap: 'Hj. Siti Fatimah, S.Ag',
          nip: const Value('198203152009012008'),
          jk: 'P',
          aktif: const Value(1),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.user).insert(
        UserCompanion.insert(
          id: 'user-001',
          username: 'admin',
          aktif: const Value(1),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.userRole).insert(
        UserRoleCompanion.insert(
          id: 'ur-001',
          userId: 'user-001',
          role: 'admin',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.user).insert(
        UserCompanion.insert(
          id: 'user-002',
          guruId: const Value('guru-001'),
          username: 'guru_dahlan',
          aktif: const Value(1),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 7. Rombel
      await db.into(db.rombel).insert(
        RombelCompanion.insert(
          id: 'rombel-7a',
          tahunAjaranId: 'ta-2026-2027',
          nama: '7A',
          tingkat: '7',
          waliGuruId: const Value('guru-001'),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.rombel).insert(
        RombelCompanion.insert(
          id: 'rombel-7b',
          tahunAjaranId: 'ta-2026-2027',
          nama: '7B',
          tingkat: '7',
          waliGuruId: const Value('guru-002'),
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.rombel).insert(
        RombelCompanion.insert(
          id: 'rombel-8a',
          tahunAjaranId: 'ta-2026-2027',
          nama: '8A',
          tingkat: '8',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      await db.into(db.rombel).insert(
        RombelCompanion.insert(
          id: 'rombel-9a',
          tahunAjaranId: 'ta-2026-2027',
          nama: '9A',
          tingkat: '9',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 8. Pengampu
      // Guru Dahlan: Bahasa Arab di 7A (Utama, Seluruh)
      await db.into(db.pengampu).insert(
        PengampuCompanion.insert(
          id: 'pengampu-001',
          guruId: 'guru-001',
          mapelId: 'mapel-arab',
          rombelId: 'rombel-7a',
          semesterId: 'sem-2026-ganjil',
          cakupan: const Value('seluruh'),
          peran: const Value('utama'),
          tanggalMulai: '2026-07-15',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // Guru Dahlan: Al-Qur'an Hadis di 7B (Utama, Sebagian dengan unassigned fallback)
      await db.into(db.pengampu).insert(
        PengampuCompanion.insert(
          id: 'pengampu-002',
          guruId: 'guru-001',
          mapelId: 'mapel-qurhad',
          rombelId: 'rombel-7b',
          semesterId: 'sem-2026-ganjil',
          cakupan: const Value('sebagian'),
          peran: const Value('utama'),
          tanggalMulai: '2026-07-15',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // Guru Fatimah: Fikih di 8A (Pendamping, Sebagian)
      await db.into(db.pengampu).insert(
        PengampuCompanion.insert(
          id: 'pengampu-003',
          guruId: 'guru-002',
          mapelId: 'mapel-fikih',
          rombelId: 'rombel-8a',
          semesterId: 'sem-2026-ganjil',
          cakupan: const Value('sebagian'),
          peran: const Value('pendamping'),
          tanggalMulai: '2026-07-15',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 9. Siswa Sample
      final sampleSiswa = [
        ('siswa-001', '202607001', '0081234501', 'Ahmad Fauzi Ridwan', 'L'),
        ('siswa-002', '202607002', '0081234502', 'Bilqis Nur Azizah', 'P'),
        ('siswa-003', '202607003', '0081234503', 'Dian Muhammad Irfan', 'L'),
        ('siswa-004', '202607004', '0081234504', 'Farah Nabila Putri', 'P'),
        ('siswa-005', '202607005', '0081234505', 'Genta Pratama', 'L'),
      ];

      for (int i = 0; i < sampleSiswa.length; i++) {
        final s = sampleSiswa[i];
        await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: s.$1,
            nis: s.$2,
            nisn: Value(s.$3),
            namaLengkap: s.$4,
            jk: s.$5,
            statusAktif: const Value('aktif'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Detail
        await db.into(db.siswaDetail).insert(
          SiswaDetailCompanion.insert(
            id: 'detail-${s.$1}',
            siswaId: s.$1,
            tempatLahir: const Value('Pekalongan'),
            tanggalLahir: const Value('2012-05-14'),
            agamaKode: const Value('ISLAM'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Ortu Ayah
        await db.into(db.siswaOrtu).insert(
          SiswaOrtuCompanion.insert(
            id: 'ortu-ayah-${s.$1}',
            siswaId: s.$1,
            hubungan: 'ayah',
            namaLengkap: 'Abdul Somad',
            pekerjaanKode: const Value('WIRASWASTA'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Ortu Ibu
        await db.into(db.siswaOrtu).insert(
          SiswaOrtuCompanion.insert(
            id: 'ortu-ibu-${s.$1}',
            siswaId: s.$1,
            hubungan: 'ibu',
            namaLengkap: 'Siti Aminah',
            pekerjaanKode: const Value('IRT'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Alamat
        await db.into(db.alamat).insert(
          AlamatCompanion.insert(
            id: 'alamat-${s.$1}',
            pemilikTipe: 'siswa',
            pemilikId: s.$1,
            siswaId: Value(s.$1),
            jalan: const Value('Jl. Pesantren No. 12'),
            desaNama: const Value('Tirto'),
            kecamatanNama: const Value('Tirto'),
            kabupatenNama: const Value('Pekalongan'),
            provinsiNama: const Value('Jawa Tengah'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Sensitif (Terenkripsi)
        await db.into(db.siswaSensitif).insert(
          SiswaSensitifCompanion.insert(
            id: 'sensitif-${s.$1}',
            siswaId: s.$1,
            noKkEnc: const Value('enc_kk_3326123456780001'),
            nikSiswaEnc: const Value('enc_nik_3326121405120001'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Keanggotaan di Rombel 7A
        await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k-7a-00${i + 1}',
            siswaId: s.$1,
            rombelId: 'rombel-7a',
            tanggalMasuk: '2026-07-15',
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
      }

      // Siswa sample di 7B (untuk menguji pengampu 7B & unassigned fallback)
      final siswa7b = [
        ('siswa-006', '202607006', 'Hafiz Azhar', 'L'),
        ('siswa-007', '202607007', 'Irfan Hakim', 'L'),
        ('siswa-008', '202607008', 'Jasmine Laila', 'P'),
      ];

      for (int i = 0; i < siswa7b.length; i++) {
        final s = siswa7b[i];
        await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: s.$1,
            nis: s.$2,
            namaLengkap: s.$3,
            jk: s.$4,
            statusAktif: const Value('aktif'),
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        final keanggotaanId = 'k-7b-00${i + 1}';
        await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: keanggotaanId,
            siswaId: s.$1,
            rombelId: 'rombel-7b',
            tanggalMasuk: '2026-07-15',
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

        // Hanya siswa-006 yang ditugaskan ke kelompok pengampu-002,
        // siswa-007 & 008 sengaja TIDAK ditugaskan agar menjadi fallback Guru Utama (+2 belum dikelompokkan)!
        if (s.$1 == 'siswa-006') {
          await db.into(db.pengampuSiswa).insert(
            PengampuSiswaCompanion.insert(
              id: 'ps-001',
              pengampuId: 'pengampu-002',
              keanggotaanId: keanggotaanId,
              deviceId: deviceId,
              createdAt: nowEpoch,
              updatedAt: nowEpoch,
            ),
          );
        }
      }

      // 10. Nilai Sample Awal di 7A Bahasa Arab (UH 1)
      // Ahmad Fauzi: 85
      await db.into(db.nilai).insert(
        NilaiCompanion.insert(
          id: 'nilai-001',
          keanggotaanId: 'k-7a-001',
          mapelId: 'mapel-arab',
          semesterId: 'sem-2026-ganjil',
          jenisNilaiId: 'UH',
          urutanKe: const Value(1),
          nilai: 85.0,
          tanggal: '2026-08-10',
          diinputOlehGuruId: 'guru-001',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // Bilqis: 70 (Di bawah KKM 75)
      await db.into(db.nilai).insert(
        NilaiCompanion.insert(
          id: 'nilai-002',
          keanggotaanId: 'k-7a-002',
          mapelId: 'mapel-arab',
          semesterId: 'sem-2026-ganjil',
          jenisNilaiId: 'UH',
          urutanKe: const Value(1),
          nilai: 70.0,
          tanggal: '2026-08-10',
          diinputOlehGuruId: 'guru-001',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // Dian: 92 (Bawaan rombel asal)
      await db.into(db.nilai).insert(
        NilaiCompanion.insert(
          id: 'nilai-003',
          keanggotaanId: 'k-7a-003',
          mapelId: 'mapel-arab',
          semesterId: 'sem-2026-ganjil',
          jenisNilaiId: 'UH',
          urutanKe: const Value(1),
          nilai: 92.0,
          tanggal: '2026-08-10',
          sumberNilaiId: const Value('nilai-asal-999'),
          diinputOlehGuruId: 'guru-001',
          deviceId: deviceId,
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
        ),
      );

      // 11. Absensi Sample Hari Ini di 7A
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final sampleAbsensi = [
        ('k-7a-001', 'H'),
        ('k-7a-002', 'S'),
        ('k-7a-003', 'H'),
        ('k-7a-004', 'I'),
        ('k-7a-005', 'A'),
      ];

      for (int i = 0; i < sampleAbsensi.length; i++) {
        final a = sampleAbsensi[i];
        await db.into(db.absensi).insert(
          AbsensiCompanion.insert(
            id: 'absensi-00${i + 1}',
            keanggotaanId: a.$1,
            semesterId: 'sem-2026-ganjil',
            tanggal: todayStr,
            status: a.$2,
            diinputOlehUserId: 'user-002',
            deviceId: deviceId,
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
      }
    });
  }
}
