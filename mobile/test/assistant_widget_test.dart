import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/assistant_screen.dart';

void main() {
  Widget buildTestableWidget({Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FormaTheme.darkTheme(locale),
        home: const AssistantScreen(),
      ),
    );
  }

  testWidgets('Assistant Screen renders greeting and evidence badge', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Forma Assistant'), findsOneWidget);
    expect(find.text('Evidence-grounded wellness companion'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // Initial evidence badge
    expect(find.textContaining('Grounding verified'), findsOneWidget);
  });

  testWidgets('Controlled Actions Protocol: Propose -> Confirm -> Receipt interaction', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Type a request that triggers an action proposal
    await tester.enterText(find.byType(TextField), 'Please log weight 74.0 kg');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify Action Proposal card is displayed
    expect(find.text('Action Proposed'), findsOneWidget);
    expect(find.text('Record today’s weight measurement as 74.0 kg'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    // Scroll into view if needed and tap Confirm button
    await tester.ensureVisible(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify Action Receipt confirmation
    expect(find.text('Confirmed & Executed'), findsOneWidget);
    expect(find.textContaining('Action Receipt verified'), findsOneWidget);
  });

  testWidgets('Safety Category D emergency symptom redirect in Assistant UI', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Type acute symptom
    await tester.enterText(find.byType(TextField), 'I have severe chest pain and dizziness');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Safety Redirection
    expect(find.text('Health & Safety Notice'), findsOneWidget);
    expect(find.textContaining('licensed healthcare professional'), findsOneWidget);
  });

  testWidgets('Arabic RTL localization of Assistant Screen', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مساعد فورما'), findsOneWidget);
    expect(find.text('مساعدك الصحي الموثق بالأدلة'), findsOneWidget);

    final BuildContext context = tester.element(find.byType(AssistantScreen));
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
