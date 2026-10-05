import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';

class TypingIndicator extends StatefulWidget {
  final String stage; // 'retrieving_context' | 'calculating' | 'generating' | 'waiting'

  const TypingIndicator({super.key, required this.stage});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getStageLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.stage) {
      case 'retrieving_context':
        return l10n.assistantStatusThinking;
      case 'calculating':
        return l10n.assistantStatusCalculating;
      case 'generating':
        return l10n.assistantStatusGenerating;
      default:
        return l10n.assistantStatusThinking;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _getStageLabel(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FormaTheme.surfaceCard,
        borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
        border: Border.all(color: FormaTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
                  final scale = 0.6 + 0.4 * (1.0 - (value - 0.5).abs() * 2);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7 * scale,
                    height: 7 * scale,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: FormaTheme.primaryTeal,
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: FormaTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
