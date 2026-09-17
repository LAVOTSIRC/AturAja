// Basic smoke test for the AturAja app: verifies the splash screen shows
// the app name on launch.

import 'package:flutter_test/flutter_test.dart';

import 'package:bruh/main.dart';
import 'package:bruh/theme/theme_scope.dart';

void main() {
  testWidgets('Splash screen shows the AturAja logo text', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(controller: ThemeController()));

    expect(find.textContaining('Atur'), findsWidgets);
    expect(find.textContaining('Aja'), findsWidgets);
  });
}
