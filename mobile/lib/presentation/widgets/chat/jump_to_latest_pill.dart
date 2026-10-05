import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import 'glass_surface.dart';

class JumpToLatestPill extends StatelessWidget {
  final VoidCallback onTap;

  const JumpToLatestPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward_rounded, color: FormaTheme.primaryTeal, size: 16),
              const SizedBox(width: 6),
              Text(
                l10n.jumpToLatest,
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
