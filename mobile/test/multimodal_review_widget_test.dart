import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/multimodal_review_screen.dart';

void main() {
  DraftReviewState createSampleDraft({bool hasAttention = true}) {
    return DraftReviewState(
      draftId: 'draft-uuid-1234-5678',
      imageKind: 'scale_display',
      overallConfidence: 0.88,
      unrecognizedCount: 1,
      fields: [
        ExtractedFieldItem(
          typeCode: 'weight',
          rawLabel: 'Weight',
          extractedValue: 74.5,
          unit: 'kg',
          canonicalValue: 74.5,
          canonicalUnit: 'kg',
          confidenceScore: 0.95,
          epistemicClass: 'measured',
          isApproved: true,
          requiresFieldAttention: false,
        ),
        ExtractedFieldItem(
          typeCode: 'body_fat_percentage',
          rawLabel: 'Body Fat',
          extractedValue: 18.2,
          unit: '%',
          canonicalValue: 18.2,
          canonicalUnit: 'percent',
          confidenceScore: hasAttention ? 0.65 : 0.92,
          qualityFlags: hasAttention ? ['low_confidence'] : [],
          epistemicClass: 'measured',
          isApproved: true,
          requiresFieldAttention: hasAttention,
        ),
      ],
    );
  }

  Widget buildTestableWidget({
    Locale locale = const Locale('en'),
    required DraftReviewState draft,
    Future<String> Function(DraftReviewState)? onCommit,
    VoidCallback? onDiscard,
  }) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FormaTheme.darkTheme(locale),
        home: MultimodalReviewScreen(
          initialDraft: draft,
          onCommit: onCommit,
          onDiscard: onDiscard,
        ),
      ),
    );
  }

  testWidgets('renders multimodal review screen with attention warning and fields', (WidgetTester tester) async {
    final draft = createSampleDraft(hasAttention: true);
    await tester.pumpWidget(buildTestableWidget(draft: draft));
    await tester.pumpAndSettle();

    // Verify title and image kind
    expect(find.text('Review Extracted Data'), findsOneWidget);
    expect(find.text('SCALE_DISPLAY'), findsOneWidget);

    // Verify adaptive attention warning
    expect(find.text('Some fields need your attention due to low confidence or values.'), findsOneWidget);
    expect(find.text('Needs Attention'), findsOneWidget);

    // Verify fields
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('74.5 kg'), findsOneWidget);
    expect(find.text('Body Fat'), findsOneWidget);
    expect(find.text('18.2 %'), findsOneWidget);

    // Verify unrecognized fields note
    expect(find.text('Unrecognized fields omitted (1)'), findsOneWidget);

    // Verify delete source image switch is on
    expect(find.text('Delete source image after saving (Privacy Recommended)'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('edits field value through edit dialog', (WidgetTester tester) async {
    final draft = createSampleDraft(hasAttention: false);
    await tester.pumpWidget(buildTestableWidget(draft: draft));
    await tester.pumpAndSettle();

    // Tap edit button on field 0 (Weight)
    await tester.tap(find.byKey(const Key('edit_field_0')));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Edit Value: Weight'), findsOneWidget);
    expect(find.byKey(const Key('edit_field_input')), findsOneWidget);

    // Enter 75.0
    await tester.enterText(find.byKey(const Key('edit_field_input')), '75.0');
    await tester.tap(find.byKey(const Key('save_field_button')));
    await tester.pumpAndSettle();

    // Verify updated value and 'Edited' label
    expect(find.text('75.0 kg'), findsOneWidget);
    expect(find.text('Edited'), findsOneWidget);
  });

  testWidgets('toggles field approval and disables commit when all unchecked', (WidgetTester tester) async {
    final draft = createSampleDraft(hasAttention: false);
    await tester.pumpWidget(buildTestableWidget(draft: draft));
    await tester.pumpAndSettle();

    // Initially commit button is enabled
    final commitFinder = find.byKey(const Key('commit_to_health_record_button'));
    expect(tester.widget<ElevatedButton>(commitFinder).enabled, isTrue);

    // Uncheck field 0
    await tester.tap(find.byKey(const Key('checkbox_field_0')));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(commitFinder).enabled, isTrue);

    // Uncheck field 1
    await tester.tap(find.byKey(const Key('checkbox_field_1')));
    await tester.pumpAndSettle();

    // Now 0 fields approved -> button disabled and warning displayed
    expect(tester.widget<ElevatedButton>(commitFinder).enabled, isFalse);
    expect(find.text('No fields selected for commit'), findsOneWidget);
  });

  testWidgets('commits draft to health record and displays receipt', (WidgetTester tester) async {
    final draft = createSampleDraft(hasAttention: false);
    await tester.pumpWidget(buildTestableWidget(
      draft: draft,
      onCommit: (st) async => 'rcpt_mm_verified_9999',
    ));
    await tester.pumpAndSettle();

    final commitFinder = find.byKey(const Key('commit_to_health_record_button'));
    await tester.ensureVisible(commitFinder);
    await tester.tap(commitFinder);
    await tester.pumpAndSettle();

    // Verify receipt view
    expect(find.text('Confirmed & Executed'), findsOneWidget);
    expect(find.text('Receipt ID: rcpt_mm_verified_9999'), findsOneWidget);
  });

  testWidgets('renders Arabic RTL parity correctly', (WidgetTester tester) async {
    final draft = createSampleDraft(hasAttention: true);
    await tester.pumpWidget(buildTestableWidget(
      locale: const Locale('ar'),
      draft: draft,
    ));
    await tester.pumpAndSettle();

    expect(find.text('مراجعة البيانات المستخرجة'), findsOneWidget);
    expect(find.text('بعض الحقول تتطلب انتباهك بسبب انخفاض دقة القراءة أو القيم.'), findsOneWidget);
    expect(find.text('حفظ في السجل الصحي'), findsOneWidget);
    expect(find.text('حذف الصورة الأصلية بعد الحفظ (موصى به للخصوصية)'), findsOneWidget);
    expect(find.text('تم استبعاد الحقول غير المعروفة (1)'), findsOneWidget);
  });
}
