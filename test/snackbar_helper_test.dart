import 'package:aturaja/utils/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menampilkan snackbar sukses', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () => showSuccessSnackBar(
                  context,
                  'Perubahan berhasil disimpan.',
                ),
                child: const Text('Tampilkan'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tampilkan'));
    await tester.pump();

    expect(find.text('Perubahan berhasil disimpan.'), findsOneWidget);
  });

  testWidgets('menampilkan snackbar error', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () => showErrorSnackBar(
                  context,
                  'Terjadi kesalahan saat menyimpan.',
                ),
                child: const Text('Tampilkan'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tampilkan'));
    await tester.pump();

    expect(find.text('Terjadi kesalahan saat menyimpan.'), findsOneWidget);
  });
}
