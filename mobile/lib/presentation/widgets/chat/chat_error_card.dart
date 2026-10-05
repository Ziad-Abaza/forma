import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';

class ChatErrorCard extends StatelessWidget {
  final String errorCode;
  final VoidCallback onRetry;

  const ChatErrorCard({
    super.key,
    required this.errorCode,
    required this.onRetry,
  });

  String _getErrorMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (errorCode) {
      case 'S01':
        return l10n.errorS01Offline;
      case 'S02':
        return l10n.errorS02Provider;
      case 'S03':
        return l10n.errorS03Timeout;
      case 'S04':
        return l10n.errorS04Interrupted;
      case 'S05':
        return l10n.errorS05RateLimit;
      case 'S06':
        return l10n.errorS06Expired;
      case 'S07':
        return l10n.errorS07Commit;
      case 'S08':
        return l10n.errorS08Malformed;
      default:
        return l10n.errorS02Provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = _getErrorMessage(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FormaTheme.surfaceCard,
        borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
        border: Border.all(color: FormaTheme.alertCoral.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: FormaTheme.alertCoral, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FormaTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: FormaTheme.primaryTeal,
              minimumSize: const Size(60, 48), // tap target >= 48dp
            ),
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}
