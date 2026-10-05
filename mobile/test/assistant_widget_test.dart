import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/assistant_screen.dart';



class FakeAssistantRepository extends AssistantRepository {
  FakeAssistantRepository() : super(apiClient: ApiClient(tokenStorage: TokenStorage(), getBaseUrl: () => 'http://localhost'));

  @override
  Future<SendMessageResult> sendMessage({required String message, String? conversationId}) async {
    final lower = message.toLowerCase();
    if (lower.contains('chest pain') || lower.contains('dizziness')) {
      return SendMessageResult(
        conversationId: 'conv_1',
        assistantMessage: AssistantChatMessage(
          id: 'msg_emergency',
          role: 'assistant',
          content: 'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services.',
          isEmergencyNotice: true,
          timestamp: DateTime.now(),
        ),
      );
    }

    if (lower.contains('log') || lower.contains('weight')) {
      return SendMessageResult(
        conversationId: 'conv_1',
        assistantMessage: AssistantChatMessage(
          id: 'msg_proposal',
          role: 'assistant',
          content: 'I have prepared an action proposal to record your weight.',
          proposals: [
            ActionProposalModel(
              id: 'prop_123',
              actionType: 'log_measurement',
              humanReadableSummary: 'Record today’s weight measurement as 74.0 kg',
              diffBefore: '75.0 kg',
              diffAfter: '74.0 kg',
            ),
          ],
          timestamp: DateTime.now(),
        ),
      );
    }

    return SendMessageResult(
      conversationId: 'conv_1',
      assistantMessage: AssistantChatMessage(
        id: 'msg_reply',
        role: 'assistant',
        content: 'Hello, how can I help you today?',
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<ConfirmProposalResult> confirmProposal(String proposalId, {String? idempotencyKey}) async {
    return ConfirmProposalResult(
      proposal: ActionProposalModel(
        id: proposalId,
        actionType: 'log_measurement',
        humanReadableSummary: 'Record today’s weight measurement as 74.0 kg',
        diffAfter: '74.0 kg',
        status: 'executed',
      ),
      receipt: const ActionReceiptModel(
        receiptId: 'rcpt_123',
        proposalId: 'prop_123',
        actionType: 'log_measurement',
        committedAt: '2026-10-05T00:00:00Z',
        entityId: 'obs_123',
        entityType: 'observation',
        provenance: 'assistant_proposal',
        summary: 'Weight measurement of 74.0 kg recorded',
      ),
    );
  }

  @override
  Future<ActionProposalModel> declineProposal(String proposalId) async {
    return ActionProposalModel(
      id: proposalId,
      actionType: 'log_measurement',
      humanReadableSummary: 'Record today’s weight measurement as 74.0 kg',
      diffAfter: '74.0 kg',
      status: 'declined',
    );
  }
}

void main() {
  Widget buildTestableWidget({Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        assistantRepositoryProvider.overrideWithValue(FakeAssistantRepository()),
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
