import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../modules/assistant/models/assistant_models.dart';

class ProposalCard extends StatelessWidget {
  final ActionProposalModel proposal;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;

  const ProposalCard({
    super.key,
    required this.proposal,
    required this.onConfirm,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPending = proposal.status == 'pending';
    final isConfirming = proposal.status == 'confirming';
    final isExecuted = proposal.status == 'executed';
    final isDeclined = proposal.status == 'declined';
    final isExpired = proposal.status == 'expired';
    final isFailed = proposal.status == 'failed';

    if (isExecuted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FormaTheme.successGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
          border: Border.all(color: FormaTheme.successGreen.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: FormaTheme.successGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                proposal.humanReadableSummary.isNotEmpty
                    ? proposal.humanReadableSummary
                    : l10n.actionExecuted,
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isDeclined || isExpired) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FormaTheme.surfaceCard,
          borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
          border: Border.all(color: FormaTheme.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(
              isDeclined ? Icons.cancel_outlined : Icons.timer_off_outlined,
              color: FormaTheme.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${isDeclined ? l10n.actionDeclined : l10n.actionExpired}: ${proposal.humanReadableSummary}',
                style: const TextStyle(
                  color: FormaTheme.textSecondary,
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Pending, Confirming or Failed state
    final borderColor = isFailed ? FormaTheme.alertCoral : FormaTheme.warningAmber;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FormaTheme.surfaceCard,
        borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: borderColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  proposal.humanReadableSummary,
                  style: const TextStyle(
                    color: FormaTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (proposal.diffBefore != null || proposal.diffAfter.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: FormaTheme.obsidianBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (proposal.diffBefore != null) ...[
                    Text(
                      proposal.diffBefore!,
                      style: const TextStyle(
                        color: FormaTheme.textSecondary,
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward_rounded, size: 14, color: FormaTheme.textSecondary),
                    ),
                  ],
                  Text(
                    proposal.diffAfter,
                    style: const TextStyle(
                      color: FormaTheme.primaryTeal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (proposal.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              proposal.errorMessage!,
              style: const TextStyle(color: FormaTheme.alertCoral, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending)
                OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FormaTheme.textSecondary,
                    side: const BorderSide(color: FormaTheme.borderSubtle),
                    minimumSize: const Size(80, 48), // tap target >= 48dp
                  ),
                  child: Text(l10n.declineAction),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (isPending || isFailed) ? onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FormaTheme.primaryTeal,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(100, 48), // tap target >= 48dp
                ),
                child: isConfirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(isFailed ? l10n.retry : l10n.confirmAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
