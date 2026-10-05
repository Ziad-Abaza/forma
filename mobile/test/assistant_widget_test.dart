import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/assistant_screen.dart';
import 'package:forma/presentation/widgets/chat/empty_state_bento.dart';
import 'package:forma/presentation/widgets/chat/composer.dart';
import 'package:forma/presentation/widgets/chat/proposal_card.dart';

class FakeAssistantRepository extends AssistantRepository {
  FakeAssistantRepository()
      : super(apiClient: ApiClient(tokenStorage: TokenStorage(), getBaseUrl: () => 'http://localhost'));

  @override
  Stream<SSEEvent> streamMessage({
    required String message,
    String? conversationId,
  }) async* {
    yield const SSEEvent(event: 'start', data: {'conversationId': 'conv_1'});

    final lower = message.toLowerCase();
    if (lower.contains('chest pain') || lower.contains('dizziness')) {
      yield const SSEEvent(
        event: 'done',
        data: {
          'content':
              'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services.',
          'safetyCategory': 'D',
        },
      );
      return;
    }

    if (lower.contains('log') || lower.contains('weight')) {
      yield const SSEEvent(
        event: 'delta',
        data: {'text': 'I have prepared an action proposal to record your weight.'},
      );
      yield const SSEEvent(
        event: 'proposal',
        data: {
          'id': 'prop_123',
          'actionType': 'log_measurement',
          'humanReadableSummary': 'Record today’s weight measurement as 74.0 kg',
          'diffBefore': '75.0 kg',
          'diffAfter': '74.0 kg',
          'status': 'pending',
        },
      );
      yield const SSEEvent(
        event: 'evidence',
        data: {
          'claimText': 'Measured data',
          'type': 'retrieved',
        },
      );
      yield const SSEEvent(
        event: 'done',
        data: {
          'content': 'I have prepared an action proposal to record your weight.',
          'safetyCategory': 'A',
        },
      );
      return;
    }

    yield const SSEEvent(
      event: 'delta',
      data: {'text': 'Hello, how can I help you today?'},
    );
    yield const SSEEvent(
      event: 'evidence',
      data: {
        'claimText': 'Grounding verified',
        'type': 'retrieved',
      },
    );
    yield const SSEEvent(
      event: 'done',
      data: {
        'content': 'Hello, how can I help you today?',
        'safetyCategory': 'A',
      },
    );
  }

  @override
  Future<SendMessageResult> sendMessage({required String message, String? conversationId}) async {
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
  FlutterSecureStorage.setMockInitialValues({});
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

  testWidgets('Assistant Screen renders header and empty state bento cards', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    expect(find.text('Forma Assistant'), findsOneWidget);
    expect(find.text('Evidence-grounded wellness companion'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Composer), findsOneWidget);
    expect(find.byType(EmptyStateBento), findsOneWidget);
    expect(find.text('Forma Companion'), findsOneWidget);
  });

  testWidgets('Controlled Actions Protocol: Propose -> Confirm -> Receipt interaction', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Type a request that triggers an action proposal
    await tester.enterText(find.byType(TextField), 'Please log weight 74.0 kg');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_circle_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Action Proposal card is displayed
    expect(find.byType(ProposalCard), findsOneWidget);
    expect(find.text('Record today’s weight measurement as 74.0 kg'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    // Scroll into view if needed and tap Confirm button
    await tester.ensureVisible(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify the server-issued receipt is rendered verbatim
    expect(find.textContaining('Weight measurement of 74.0 kg recorded'), findsOneWidget);
    expect(find.textContaining('Receipt: rcpt_123'), findsOneWidget);
  });

  testWidgets('Safety Category D emergency symptom redirect in Assistant UI', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Type acute symptom
    await tester.enterText(find.byType(TextField), 'I have severe chest pain and dizziness');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_circle_up_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Safety Redirection
    expect(find.text('Health & Safety Notice'), findsOneWidget);
    expect(find.textContaining('licensed healthcare professional'), findsOneWidget);
  });

  testWidgets('Arabic RTL localization of Assistant Screen', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مساعد Forma'), findsOneWidget);
    expect(find.text('مساعدك الصحي الموثق بالأدلة'), findsOneWidget);

    final BuildContext context = tester.element(find.byType(AssistantScreen));
    expect(Directionality.of(context), TextDirection.rtl);
  });
}
