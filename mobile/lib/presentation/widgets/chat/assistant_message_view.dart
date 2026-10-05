import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../modules/assistant/models/assistant_models.dart';
import 'bento_metrics_grid.dart';
import 'proposal_card.dart';
import 'sources_sheet.dart';

class AssistantMessageView extends StatelessWidget {
  final AssistantChatMessage message;
  final Function(String messageId, String proposalId) onConfirmProposal;
  final Function(String messageId, String proposalId) onDeclineProposal;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;

  const AssistantMessageView({
    super.key,
    required this.message,
    required this.onConfirmProposal,
    required this.onDeclineProposal,
    this.onRetry,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRtl = intl.Bidi.detectRtlDirectionality(message.content);
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;

    if (message.isEmergencyNotice) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FormaTheme.alertCoral.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
          border: Border.all(color: FormaTheme.alertCoral, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emergency_rounded, color: FormaTheme.alertCoral, size: 24),
                const SizedBox(width: 8),
                Text(
                  isRtl ? 'تنبيه صحي طارئ' : 'Health & Safety Notice',
                  style: const TextStyle(
                    color: FormaTheme.alertCoral,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Directionality(
              textDirection: textDirection,
              child: Text(
                message.content,
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Split text around proposal tokens: <<proposal:{id}>>
    final parts = message.content.split(RegExp(r'<<proposal:([^>]+)>>'));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680), // Spec §1.4 measure
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FormaTheme.surfaceCard,
            borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
            border: Border.all(color: FormaTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar header (Spec §1.3)
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: FormaTheme.primaryTeal.withValues(alpha: 0.15),
                    ),
                    child: const Center(
                      child: Icon(Icons.auto_awesome, color: FormaTheme.primaryTeal, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Forma',
                    style: TextStyle(
                      color: FormaTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Markdown content with selection
              Directionality(
                textDirection: textDirection,
                child: SelectionArea(
                  child: MarkdownBody(
                    data: parts.isNotEmpty ? parts[0] : message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: FormaTheme.textPrimary,
                        fontSize: 15,
                        height: isRtl ? 1.7 : 1.5,
                      ),
                      h3: const TextStyle(
                        color: FormaTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      listBullet: const TextStyle(color: FormaTheme.primaryTeal),
                      blockquoteDecoration: BoxDecoration(
                        color: FormaTheme.obsidianBackground,
                        border: Border(
                          left: isRtl ? BorderSide.none : const BorderSide(color: FormaTheme.primaryTeal, width: 4),
                          right: isRtl ? const BorderSide(color: FormaTheme.primaryTeal, width: 4) : BorderSide.none,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      tableBorder: TableBorder.all(color: FormaTheme.borderSubtle),
                      tableHead: const TextStyle(color: FormaTheme.primaryTeal, fontWeight: FontWeight.w600),
                      tableBody: const TextStyle(color: FormaTheme.textPrimary),
                    ),
                  ),
                ),
              ),

              // In-message bento metrics grid if present
              if (message.metricsBlock != null) ...[
                BentoMetricsGrid(metrics: message.metricsBlock!),
              ],

              // Proposals
              for (final prop in message.proposals) ...[
                ProposalCard(
                  proposal: prop,
                  onConfirm: () => onConfirmProposal(message.id, prop.id),
                  onDecline: () => onDeclineProposal(message.id, prop.id),
                ),
              ],

              // Remainder markdown parts if proposal tokens were inline
              if (parts.length > 1) ...[
                for (int i = 1; i < parts.length; i++)
                  if (parts[i].trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Directionality(
                        textDirection: textDirection,
                        child: SelectionArea(
                          child: MarkdownBody(
                            data: parts[i],
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: FormaTheme.textPrimary,
                                fontSize: 15,
                                height: isRtl ? 1.7 : 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],

              // Footer: Sources bottom sheet button & Actions (Spec §1.3)
              const SizedBox(height: 12),
              Row(
                children: [
                  if (message.evidenceClaims.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => SourcesSheet.show(context, message.evidenceClaims),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: FormaTheme.obsidianBackground,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: FormaTheme.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined, size: 13, color: FormaTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Text(
                              l10n.sourcesCount(message.evidenceClaims.length),
                              style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onCopy != null)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: FormaTheme.textSecondary),
                      onPressed: onCopy,
                      tooltip: l10n.copy,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  if (onRetry != null)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 16, color: FormaTheme.textSecondary),
                      onPressed: onRetry,
                      tooltip: l10n.retry,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
