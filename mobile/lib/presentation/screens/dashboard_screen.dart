import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String selectedPeriod = '30d';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final numeralSystem = ref.watch(numeralSystemProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal),
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
              style: const TextStyle(
                color: FormaTheme.primaryTeal,
                fontWeight: FontWeight.bold,
              ),
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
              Text(
                l10n.tagline,
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Epistemic Class Badges
              _buildEpistemicLegend(l10n),
              const SizedBox(height: 20),

              // 1. Primary Goal & Progress Card
              _buildGoalCard(l10n, numeralSystem),
              const SizedBox(height: 16),

              // 2. Noise-Robust Trends Card
              _buildTrendsCard(l10n, numeralSystem),
              const SizedBox(height: 16),

              // 3. Energy & Nutrition Targets Card
              _buildEnergyTargetsCard(l10n, numeralSystem),
              const SizedBox(height: 16),

              // 4. Honest Empty Measurements / Quick Log Action
              _buildMeasurementsSection(l10n, numeralSystem),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpistemicLegend(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildBadge(l10n.measured, FormaTheme.badgeMeasured),
          const SizedBox(width: 8),
          _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
          const SizedBox(width: 8),
          _buildBadge(l10n.estimated, FormaTheme.badgeEstimated),
          const SizedBox(width: 8),
          _buildBadge(l10n.asserted, FormaTheme.badgeAsserted),
        ],
      ),
    );
  }

  Widget _buildGoalCard(AppLocalizations l10n, String numeralSystem) {
    // Current goal data
    const double startingKg = 90.0;
    const double currentKg = 84.5;
    const double targetKg = 78.0;
    const double progress = 45.8;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: FormaTheme.warningAmber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.primaryGoal,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.goalWeightLoss,
              style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol(l10n.startingValue, '${formatNumeralString(startingKg.toStringAsFixed(1), numeralSystem)} kg'),
                _buildMetricCol(l10n.currentValue, '${formatNumeralString(currentKg.toStringAsFixed(1), numeralSystem)} kg'),
                _buildMetricCol(l10n.targetValue, '${formatNumeralString(targetKg.toStringAsFixed(1), numeralSystem)} kg'),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 8,
                backgroundColor: FormaTheme.surfaceElevated,
                valueColor: const AlwaysStoppedAnimation<Color>(FormaTheme.primaryTeal),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.progress}: ${formatNumeralString(progress.toStringAsFixed(1), numeralSystem)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  l10n.safeRate,
                  style: const TextStyle(color: FormaTheme.successGreen, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsCard(AppLocalizations l10n, String numeralSystem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_down, color: FormaTheme.primaryTeal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.trends,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPeriodChip('7d', l10n.period7d),
                _buildPeriodChip('30d', l10n.period30d),
                _buildPeriodChip('90d', l10n.period90d),
                _buildPeriodChip('1y', l10n.period1y),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol(
                  l10n.sevenDayAverage,
                  '${formatNumeralString('84.2', numeralSystem)} kg',
                ),
                _buildMetricCol(
                  l10n.weeklyRate,
                  '${formatNumeralString('-0.48', numeralSystem)} kg/wk',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String id, String label) {
    final isSelected = selectedPeriod == id;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => selectedPeriod = id);
      },
      selectedColor: FormaTheme.primaryTeal.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: isSelected ? FormaTheme.primaryTeal : FormaTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEnergyTargetsCard(AppLocalizations l10n, String numeralSystem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: FormaTheme.warningAmber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.energyTargets,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol(
                  l10n.maintenanceCalories,
                  '${formatNumeralString('2,450', numeralSystem)} kcal',
                ),
                _buildMetricCol(
                  l10n.targetCalories,
                  '${formatNumeralString('1,950', numeralSystem)} kcal',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroBar(l10n.protein, '152g', FormaTheme.primaryTeal, numeralSystem),
                _buildMacroBar(l10n.fats, '54g', FormaTheme.warningAmber, numeralSystem),
                _buildMacroBar(l10n.carbs, '213g', FormaTheme.secondaryMint, numeralSystem),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, String amount, Color color, String numeralSystem) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 6,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(height: 4),
        Text(
          formatNumeralString(amount, numeralSystem),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMeasurementsSection(AppLocalizations l10n, String numeralSystem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.healthRecords,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  key: const Key('add_measurement_button'),
                  onPressed: () => _showAddMeasurementDialog(context, l10n),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addMeasurement),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: FormaTheme.surfaceElevated,
                child: Icon(Icons.monitor_weight_outlined, color: FormaTheme.primaryTeal),
              ),
              title: Text(l10n.weight, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${formatNumeralString('84.5', numeralSystem)} kg',
                style: const TextStyle(color: FormaTheme.textSecondary),
              ),
              trailing: _buildBadge(l10n.measured, FormaTheme.badgeMeasured),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
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
