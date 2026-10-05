import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../modules/assistant/models/assistant_models.dart';

class BentoMetricsGrid extends StatelessWidget {
  final FormaMetricsModel metrics;

  const BentoMetricsGrid({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.tiles.isEmpty) return const SizedBox.shrink();

    final isWideScreen = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWideScreen ? 4 : 2;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics.tiles.map((tile) {
              final isWide = tile.size == 'wide';
              final double tileWidth = isWide && !isWideScreen
                  ? constraints.maxWidth
                  : (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;

              return SizedBox(
                width: tileWidth,
                child: _BentoTile(tile: tile),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _BentoTile extends StatelessWidget {
  final MetricTileModel tile;

  const _BentoTile({required this.tile});

  Color _getBadgeColor(EvidenceBadgeType type) {
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
    final delta = tile.delta;
    final hasDelta = delta != null && delta != 0.0;
    final isPositiveDelta = (delta ?? 0.0) > 0;
    final deltaColor = isPositiveDelta ? FormaTheme.successGreen : FormaTheme.alertCoral;
    final deltaGlyph = isPositiveDelta ? '▲ +' : '▼ ';

    final semanticLabel =
        '${tile.label}, ${tile.value} ${tile.unit ?? ""}, ${hasDelta ? "$deltaGlyph$delta" : ""}, ${tile.evidence.name}';

    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FormaTheme.surfaceCard,
          borderRadius: BorderRadius.circular(FormaTheme.radiusTile),
          border: Border.all(color: FormaTheme.borderSubtle, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tile.label,
                    style: const TextStyle(
                      color: FormaTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getBadgeColor(tile.evidence),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  tile.value.toString(),
                  style: const TextStyle(
                    color: FormaTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (tile.unit != null && tile.unit!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    tile.unit!,
                    style: const TextStyle(
                      color: FormaTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
            if (hasDelta || tile.period != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (hasDelta)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: deltaColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$deltaGlyph${delta.abs()}',
                        style: TextStyle(
                          color: deltaColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (tile.period != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '/${tile.period}',
                      style: const TextStyle(
                        color: FormaTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
