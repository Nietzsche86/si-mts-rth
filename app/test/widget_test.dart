import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('MTsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MTsApp()));

    // Verifikasi judul madrasah tampil
    expect(find.text('MTs Roudhotut Thowalib'), findsOneWidget);
    // Verifikasi banner sinkronisasi tampil
    expect(find.byType(SyncStatusBar), findsOneWidget);
    // Verifikasi tombol navigasi tampil
    expect(find.text('Kelas Saya'), findsOneWidget);
    expect(find.text('Input Nilai'), findsOneWidget);
    expect(find.text('Absensi'), findsOneWidget);
  });
}
