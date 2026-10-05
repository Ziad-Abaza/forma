import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class EmptyStateBento extends StatelessWidget {
  final ValueChanged<String> onPromptTap;

  const EmptyStateBento({super.key, required this.onPromptTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FormaTheme.surfaceCard,
              borderRadius: BorderRadius.circular(FormaTheme.radiusCard),
              border: Border.all(color: FormaTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FormaTheme.primaryTeal.withValues(alpha: 0.15),
                  ),
                  child: const Center(
                    child: Icon(Icons.fitness_center_rounded, color: FormaTheme.primaryTeal, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forma Companion',
                        style: TextStyle(
                          color: FormaTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Evidence-based coaching grounded in your data',
                        style: TextStyle(
                          color: FormaTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Quick Actions & Prompts',
            style: TextStyle(
              color: FormaTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _LauncherTile(
                  title: 'Today’s Snapshot',
                  subtitle: 'How am I progressing towards my goals?',
                  icon: Icons.trending_up_rounded,
                  onTap: () => onPromptTap('How am I progressing towards my current goals?'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _LauncherTile(
                  title: 'Log Weight',
                  subtitle: 'Record entry',
                  icon: Icons.scale_rounded,
                  onTap: () => onPromptTap('I want to log my weight today: '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _LauncherTile(
                  title: 'Target Calories',
                  subtitle: 'BMR & TDEE',
                  icon: Icons.local_fire_department_rounded,
                  onTap: () => onPromptTap('What are my maintenance and target calories?'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _LauncherTile(
                  title: 'Review Trends',
                  subtitle: 'How are my measurements trending this month?',
                  icon: Icons.insights_rounded,
                  onTap: () => onPromptTap('How are my body measurements trending over the last month?'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LauncherTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FormaTheme.radiusTile),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FormaTheme.surfaceCard,
          borderRadius: BorderRadius.circular(FormaTheme.radiusTile),
          border: Border.all(color: FormaTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: FormaTheme.primaryTeal, size: 20),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: FormaTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: FormaTheme.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
