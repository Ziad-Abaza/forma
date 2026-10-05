import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/main.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/presentation/screens/dashboard_screen.dart';

import 'package:forma/modules/auth/notifiers/auth_state.dart';
import 'package:forma/modules/auth/models/user_model.dart';
import 'package:forma/modules/auth/repositories/auth_repository.dart';

import 'package:forma/modules/analytics/models/snapshot_model.dart';
import 'package:forma/modules/analytics/repositories/analytics_repository.dart';

void main() {
  testWidgets('Bilingual Localization & RTL/LTR dynamic parity test (Phase 1 & Phase 2)', (WidgetTester tester) async {
    // 1. Pump FormaApp wrapped in Riverpod ProviderScope with authenticated state
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AuthNotifier(ref, ref.watch(authRepositoryProvider))
            ..state = const AuthState(
              status: AuthStatus.authenticated,
              user: UserModel(
                id: 'test-user',
                email: 'test@forma.local',
                role: 'user',
                locale: 'en',
                numeralSystem: 'western',
                emailVerified: true,
              ),
            )),
          dashboardSnapshotProvider.overrideWith((ref) => Future.value(
                const SnapshotModel(
                  latestWeightKg: 84.5,
                  trend7dKg: 84.2,
                  weeklyRateKg: -0.48,
                  hasActiveGoal: true,
                  startingValue: 90.0,
                  currentValue: 84.5,
                  targetValue: 78.0,
                  progressPct: 45.8,
                  maintenanceCalories: 2450,
                  targetCalories: 1950,
                  recentMeasurements: [
                    SnapshotMeasurementItem(
                      typeCode: 'weight',
                      canonicalValue: 84.5,
                      canonicalUnit: 'kg',
                      observedAt: '2026-10-05',
                      epistemicClass: 'measured',
                    ),
                  ],
                ),
              )),
        ],
        child: const FormaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Verify English initial state (LTR)
    expect(find.text('Forma'), findsOneWidget);
    expect(find.text('Primary Goal'), findsOneWidget);
    expect(find.text('Weight Loss'), findsOneWidget);
    expect(find.text('Trends & Trajectory'), findsOneWidget);
    expect(find.text('Energy & Nutrition Targets'), findsOneWidget);
    expect(find.text('Health Records'), findsOneWidget);
    expect(find.text('Add Measurement'), findsOneWidget);
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
    expect(find.text('الهدف الأساسي'), findsOneWidget);
    expect(find.text('إنقاص الوزن'), findsOneWidget);
    expect(find.text('المسار والاتجاهات'), findsOneWidget);
    expect(find.text('أهداف الطاقة والتغذية'), findsOneWidget);
    expect(find.text('السجلات الصحية'), findsOneWidget);
    expect(find.text('إضافة قياس'), findsOneWidget);
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
