import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../modules/assistant/models/assistant_models.dart';

class SourcesSheet extends StatelessWidget {
  final List<EvidenceClaimModel> evidenceClaims;

  const SourcesSheet({super.key, required this.evidenceClaims});

  static void show(BuildContext context, List<EvidenceClaimModel> claims) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FormaTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FormaTheme.radiusCard)),
      ),
      builder: (context) => SourcesSheet(evidenceClaims: claims),
    );
  }

  Color _badgeColor(EvidenceBadgeType type) {
    switch (type) {
      case EvidenceBadgeType.retrieved:
        return FormaTheme.badgeMeasured;
      case EvidenceBadgeType.calculated:
        return FormaTheme.badgeCalculated;
      case EvidenceBadgeType.estimated:
        return FormaTheme.badgeEstimated;
      case EvidenceBadgeType.inferred:
        return FormaTheme.badgeAsserted;
      case EvidenceBadgeType.recommended:
        return FormaTheme.badgeRecommended;
      default:
        return FormaTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: FormaTheme.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: FormaTheme.primaryTeal, size: 20),
              const SizedBox(width: 8),
              Text(
                'Sources & Evidence (${evidenceClaims.length})',
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: evidenceClaims.length,
              separatorBuilder: (_, __) => const Divider(color: FormaTheme.borderSubtle, height: 16),
              itemBuilder: (context, index) {
                final claim = evidenceClaims[index];
                final color = _badgeColor(claim.type);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        claim.type.name.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            claim.claimText,
                            style: const TextStyle(
                              color: FormaTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          if (claim.source != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Source: ${claim.source}',
                              style: const TextStyle(
                                color: FormaTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
