import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:app/data/db/app_database.dart';
import 'package:app/data/sync/outbox_manager.dart';
import 'package:app/data/repositories/siswa_repository.dart';
import 'package:app/data/repositories/rombel_repository.dart';
import 'package:app/data/repositories/pengampu_repository.dart';
import 'package:app/data/repositories/penilaian_repository.dart';
import 'package:app/data/repositories/absensi_repository.dart';

void main() {
  late AppDatabase db;
  late OutboxManager outbox;
  late SiswaRepository siswaRepo;
  late RombelRepository rombelRepo;
  late PengampuRepository pengampuRepo;
  late PenilaianRepository penilaianRepo;
  late AbsensiRepository absensiRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxManager(db);
    siswaRepo = SiswaRepository(db, outbox);
    rombelRepo = RombelRepository(db, outbox);
    pengampuRepo = PengampuRepository(db, outbox);
    penilaianRepo = PenilaianRepository(db, outbox);
    absensiRepo = AbsensiRepository(db, outbox);

    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Master data
    await db.into(db.madrasah).insert(
          MadrasahCompanion.insert(
            id: 'm1',
            nama: 'MTs Roudhotut Thowalib',
            npsn: const drift.Value('20277800'),
            nsm: const drift.Value('121233010001'),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.tahunAjaran).insert(
          TahunAjaranCompanion.insert(
            id: 'ta1',
            nama: '2026/2027',
            tanggalMulai: nowStr,
            tanggalSelesai: '2027-06-30',
            aktif: const drift.Value(1),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.semester).insert(
          SemesterCompanion.insert(
            id: 'sem1',
            tahunAjaranId: 'ta1',
            jenis: 'ganjil',
            tanggalMulai: nowStr,
            tanggalSelesai: '2026-12-31',
            dikunci: const drift.Value(0),
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.mapel).insert(
          MapelCompanion.insert(
            id: 'mapel_mtk',
            kode: 'MTK',
            nama: 'Matematika',
            kelompok: 'A',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'rombel_7a',
            tahunAjaranId: 'ta1',
            nama: '7A',
            tingkat: '7',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.rombel).insert(
          RombelCompanion.insert(
            id: 'rombel_7b',
            tahunAjaranId: 'ta1',
            nama: '7B',
            tingkat: '7',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // 2 Siswa
    await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: 's1',
            nis: '1001',
            nisn: const drift.Value('0081234567'),
            namaLengkap: 'Ahmad Faiz',
            jk: 'L',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.siswa).insert(
          SiswaCompanion.insert(
            id: 's2',
            nis: '1002',
            nisn: const drift.Value('0081234568'),
            namaLengkap: 'Budi Santoso',
            jk: 'L',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Keanggotaan 7A
    await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k1',
            siswaId: 's1',
            rombelId: 'rombel_7a',
            tanggalMasuk: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    await db.into(db.keanggotaanRombel).insert(
          KeanggotaanRombelCompanion.insert(
            id: 'k2',
            siswaId: 's2',
            rombelId: 'rombel_7a',
            tanggalMasuk: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('SiswaRepository menghitung persentase kelengkapan data', () async {
    final nowEpoch = BigInt.from(DateTime.now().toUtc().millisecondsSinceEpoch);
    final s1 = await (db.select(db.siswa)..where((t) => t.id.equals('s1'))).getSingle();
    final profilePartial = SiswaFullProfile(siswa: s1);
    expect(profilePartial.completenessPercentage, 20); // Hanya Data Diri (1/5)

    // Test logSensitifAccess
    await siswaRepo.logSensitifAccess(
      siswaId: 's1',
      kolom: 'nik',
      userId: 'user_1',
      deviceId: 'dev1',
    );
    final pendingCount = await outbox.getPendingCount();
    expect(pendingCount, greaterThan(0));

    final profileFull = SiswaFullProfile(
      siswa: s1,
      ortuList: [
        SiswaOrtuData(
          id: 'o1',
          siswaId: 's1',
          hubungan: 'ayah',
          namaLengkap: 'Hasan',
          deviceId: 'dev1',
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
          deleted: 0,
          diubahWaliKelas: 0,
          kolomTs: '{}',
        ),
        SiswaOrtuData(
          id: 'o2',
          siswaId: 's1',
          hubungan: 'ibu',
          namaLengkap: 'Fatimah',
          deviceId: 'dev1',
          createdAt: nowEpoch,
          updatedAt: nowEpoch,
          deleted: 0,
          diubahWaliKelas: 0,
          kolomTs: '{}',
        ),
      ],
      alamat: AlamatData(
        id: 'a1',
        pemilikTipe: 'siswa',
        pemilikId: 's1',
        jalan: 'Jl. Pesantren No. 5',
        desaNama: 'Kauman',
        deviceId: 'dev1',
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
        deleted: 0,
        diubahWaliKelas: 0,
        kolomTs: '{}',
      ),
      sensitif: SiswaSensitifData(
        id: 'sec1',
        siswaId: 's1',
        nikSiswaEnc: 'ENC_NIK_TEST',
        deviceId: 'dev1',
        createdAt: nowEpoch,
        updatedAt: nowEpoch,
        deleted: 0,
      ),
    );

    expect(profileFull.completenessPercentage, 100);
  });

  test('RombelRepository mutasi pindah rombel transaksional membawa nilai', () async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Beri nilai pada s1 di 7A
    await db.into(db.nilai).insert(
          NilaiCompanion.insert(
            id: 'n1',
            keanggotaanId: 'k1',
            mapelId: 'mapel_mtk',
            semesterId: 'sem1',
            jenisNilaiId: 'UH',
            urutanKe: const drift.Value(1),
            nilai: 88.0,
            tanggal: nowStr,
            diinputOlehGuruId: 'guru_1',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Pindah rombel s1 dari 7A ke 7B dengan bawa nilai = true
    final newKeanggotaanId = await rombelRepo.pindahRombel(
      siswaId: 's1',
      rombelLamaId: 'rombel_7a',
      rombelBaruId: 'rombel_7b',
      semesterId: 'sem1',
      bawaNilai: true,
      guruId: 'guru_1',
      deviceId: 'dev1',
    );

    // 1. Keanggotaan lama harus punya tanggal_keluar
    final kLama = await (db.select(db.keanggotaanRombel)..where((t) => t.id.equals('k1'))).getSingle();
    expect(kLama.tanggalKeluar, isNotNull);

    // 2. Keanggotaan baru terbentuk di 7B dengan sumber_keanggotaan_id = k1
    final kBaru = await (db.select(db.keanggotaanRombel)..where((t) => t.id.equals(newKeanggotaanId))).getSingle();
    expect(kBaru.rombelId, 'rombel_7b');
    expect(kBaru.sumberKeanggotaanId, 'k1');

    // 3. Nilai baru terduplikasi di keanggotaan baru dengan sumber_nilai_id = n1
    final nilaiBaru = await (db.select(db.nilai)..where((t) => t.keanggotaanId.equals(newKeanggotaanId))).getSingle();
    expect(nilaiBaru.nilai, 88.0);
    expect(nilaiBaru.sumberNilaiId, 'n1');

    // 4. Riwayat status siswa tercatat
    final riwayat = await db.select(db.riwayatStatusSiswa).get();
    expect(riwayat.any((r) => r.siswaId == 's1' && r.jenisStatus == 'MUTASI_ROMBEL'), isTrue);
  });

  test('PengampuRepository fallback otomatis Guru Utama untuk siswa belum terkelompokkan', () async {
    final now = DateTime.now();
    final nowStr = now.toIso8601String().substring(0, 10);
    final nowEpoch = BigInt.from(now.toUtc().millisecondsSinceEpoch);

    // Daftarkan Guru Utama
    await db.into(db.pengampu).insert(
          PengampuCompanion.insert(
            id: 'p_utama',
            guruId: 'guru_1',
            mapelId: 'mapel_mtk',
            rombelId: 'rombel_7a',
            semesterId: 'sem1',
            peran: const drift.Value('utama'),
            cakupan: const drift.Value('sebagian'),
            tanggalMulai: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Daftarkan Guru Pendamping
    await db.into(db.pengampu).insert(
          PengampuCompanion.insert(
            id: 'p_pendamping',
            guruId: 'guru_2',
            mapelId: 'mapel_mtk',
            rombelId: 'rombel_7a',
            semesterId: 'sem1',
            peran: const drift.Value('pendamping'),
            cakupan: const drift.Value('sebagian'),
            tanggalMulai: nowStr,
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Alokasikan HANYA s1 (k1) ke Guru Pendamping
    await db.into(db.pengampuSiswa).insert(
          PengampuSiswaCompanion.insert(
            id: 'ps1',
            pengampuId: 'p_pendamping',
            keanggotaanId: 'k1',
            deviceId: 'dev1',
            createdAt: nowEpoch,
            updatedAt: nowEpoch,
          ),
        );

    // Guru Pendamping hanya melihat s1
    final siswaPendamping = await pengampuRepo.getSiswaForPengampu(
      pengampuId: 'p_pendamping',
      rombelId: 'rombel_7a',
      semesterId: 'sem1',
    );
    expect(siswaPendamping.length, 1);
    expect(siswaPendamping.first.id, 's1');

    // Guru Utama harus menerima s2 (fallback) karena s2 belum dimasukkan ke kelompok manapun
    final siswaUtama = await pengampuRepo.getSiswaForPengampu(
      pengampuId: 'p_utama',
      rombelId: 'rombel_7a',
      semesterId: 'sem1',
    );
    expect(siswaUtama.length, 1);
    expect(siswaUtama.first.id, 's2');
  });

  test('PenilaianRepository simpan dan kalkulasi K13', () async {
    // Simpan nilai UH 1
    await penilaianRepo.simpanNilai(
      keanggotaanId: 'k1',
      mapelId: 'mapel_mtk',
      semesterId: 'sem1',
      jenisNilaiId: 'UH',
      urutanKe: 1,
      nilaiAngka: 85.0,
      guruId: 'guru_1',
      deviceId: 'dev1',
    );

    final list = await penilaianRepo.getSiswaNilaiList(
      rombelId: 'rombel_7a',
      mapelId: 'mapel_mtk',
      semesterId: 'sem1',
      jenisNilaiId: 'UH',
      urutanKe: 1,
    );

    final s1Item = list.firstWhere((i) => i.keanggotaanId == 'k1');
    expect(s1Item.nilaiAngka, 85.0);
    expect(s1Item.isBawaanRombelAsal, isFalse);

    // Hitung rekap K13 on-the-fly
    final rekap = await penilaianRepo.hitungRekapSiswa(
      keanggotaanId: 'k1',
      mapelId: 'mapel_mtk',
      semesterId: 'sem1',
      kkm: 75.0,
    );
    expect(rekap.nilaiAkhir, 85.0);
    expect(rekap.predikat, 'B'); // Interval KKM 75: 75-82: C, 83-91: B, 92-100: A
  });

  test('AbsensiRepository toggle satu ketuk dan set semua hadir', () async {
    final today = DateTime.now();

    // 1. Set Semua Hadir
    await absensiRepo.setSemuaHadir(
      rombelId: 'rombel_7a',
      semesterId: 'sem1',
      tanggal: today,
      userId: 'user_guru',
      deviceId: 'dev1',
    );

    var absensiList = await absensiRepo.getAbsensiByTanggal(
      rombelId: 'rombel_7a',
      semesterId: 'sem1',
      tanggal: today,
    );
    expect(absensiList.length, 2);
    expect(absensiList.every((a) => a.status == 'H'), isTrue);

    // 2. Ganti s2 menjadi Izin (I)
    await absensiRepo.setStatusAbsensi(
      keanggotaanId: 'k2',
      semesterId: 'sem1',
      tanggal: today,
      status: 'I',
      userId: 'user_guru',
      deviceId: 'dev1',
    );

    absensiList = await absensiRepo.getAbsensiByTanggal(
      rombelId: 'rombel_7a',
      semesterId: 'sem1',
      tanggal: today,
    );
    final s2Absensi = absensiList.firstWhere((a) => a.keanggotaanId == 'k2');
    expect(s2Absensi.status, 'I');
  });
}
