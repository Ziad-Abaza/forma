import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal),
            ),
            const SizedBox(width: 12),
            Text(l10n.appTitle),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('language_toggle_button'),
            onPressed: () {
              if (currentLocale.languageCode == 'en') {
                ref.read(localeProvider.notifier).state = const Locale('ar');
                ref.read(numeralSystemProvider.notifier).state = 'eastern_arabic';
              } else {
                ref.read(localeProvider.notifier).state = const Locale('en');
                ref.read(numeralSystemProvider.notifier).state = 'western';
              }
            },
            icon: const Icon(Icons.language, color: FormaTheme.primaryTeal),
            label: Text(
              currentLocale.languageCode == 'en' ? 'العربية' : 'English',
              style: const TextStyle(color: FormaTheme.primaryTeal, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Epistemic Class Legend Row
              Text(
                l10n.tagline,
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildEpistemicBadge(l10n.measured, FormaTheme.badgeMeasured),
                    const SizedBox(width: 8),
                    _buildEpistemicBadge(l10n.calculated, FormaTheme.badgeCalculated),
                    const SizedBox(width: 8),
                    _buildEpistemicBadge(l10n.estimated, FormaTheme.badgeEstimated),
                    const SizedBox(width: 8),
                    _buildEpistemicBadge(l10n.asserted, FormaTheme.badgeAsserted),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Honest Empty State Card (Blueprint §18.1)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FormaTheme.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monitor_weight_outlined,
                          size: 48,
                          color: FormaTheme.primaryTeal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.emptyMeasurementsTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: FormaTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.emptyMeasurementsDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          color: FormaTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        key: const Key('add_measurement_button'),
                        onPressed: () => _showAddMeasurementDialog(context, l10n),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addMeasurement),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpistemicBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.addMeasurement),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.value,
                hintText: '82.5',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: l10n.unit,
                hintText: 'kg',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
