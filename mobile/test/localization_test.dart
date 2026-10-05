import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/main.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/presentation/screens/dashboard_screen.dart';

void main() {
  testWidgets('Bilingual Localization & RTL/LTR dynamic parity test', (WidgetTester tester) async {
    // 1. Pump FormaApp wrapped in Riverpod ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: FormaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify English initial state (LTR)
    expect(find.text('Forma'), findsOneWidget);
    expect(find.text('No measurements yet'), findsOneWidget);
    expect(find.text('Add Measurement'), findsOneWidget);
    expect(find.text('Measured'), findsOneWidget);
    expect(find.text('العربية'), findsOneWidget);

    // Verify initial LTR text direction
    final BuildContext initialContext = tester.element(find.byType(DashboardScreen));
    expect(Directionality.of(initialContext), TextDirection.ltr);

    // 3. Tap language toggle button to switch to Arabic (RTL)
    final toggleButton = find.byKey(const Key('language_toggle_button'));
    expect(toggleButton, findsOneWidget);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // 4. Verify Arabic localized strings
    expect(find.text('فورما'), findsOneWidget);
    expect(find.text('لا توجد قياسات بعد'), findsOneWidget);
    expect(find.text('إضافة قياس'), findsOneWidget);
    expect(find.text('مقاس'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // Verify dynamic RTL text direction
    final BuildContext arabicContext = tester.element(find.byType(DashboardScreen));
    expect(Directionality.of(arabicContext), TextDirection.rtl);
  });

  test('Numeral formatting converts to Eastern Arabic digits properly', () {
    expect(formatNumeralString('82.5 kg', 'western'), '82.5 kg');
    expect(formatNumeralString('82.5 kg', 'eastern_arabic'), '٨٢.٥ kg');
    expect(formatNumeralString('2026-10-05', 'eastern_arabic'), '٢٠٢٦-١٠-٠٥');
  });
}
