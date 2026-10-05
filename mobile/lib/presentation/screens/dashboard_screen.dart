import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../modules/analytics/models/snapshot_model.dart';
import '../../modules/analytics/repositories/analytics_repository.dart';
import '../../modules/measurements/repositories/measurements_repository.dart';
import '../../modules/goals/repositories/goals_repository.dart';
import '../../modules/auth/notifiers/auth_state.dart';
import 'assistant_screen.dart';
import 'sync_screen.dart';

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
    final snapshotAsync = ref.watch(dashboardSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                width: 28,
                height: 28,
                cacheWidth: 84,
                cacheHeight: 84,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.appTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('sync_devices_button'),
                  tooltip: l10n.syncScreenTitle,
                  icon: const Icon(Icons.sync_outlined, color: FormaTheme.primaryTeal),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SyncScreen()),
                    );
                  },
                ),
                IconButton(
                  key: const Key('assistant_button'),
                  tooltip: l10n.assistantTitle,
                  icon: const Icon(Icons.smart_toy_outlined, color: FormaTheme.primaryTeal),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssistantScreen()),
                    );
                  },
                ),
                TextButton.icon(
                  key: const Key('language_toggle_button'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                  onPressed: () {
                    if (currentLocale.languageCode == 'en') {
                      updateAppLocale(ref, const Locale('ar'));
                      updateAppNumeralSystem(ref, 'eastern_arabic');
                    } else {
                      updateAppLocale(ref, const Locale('en'));
                      updateAppNumeralSystem(ref, 'western');
                    }
                  },
                  icon: const Icon(Icons.language, color: FormaTheme.primaryTeal, size: 18),
                  label: Text(
                    currentLocale.languageCode == 'en' ? 'العربية' : 'English',
                    style: const TextStyle(
                      color: FormaTheme.primaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('logout_button'),
                  tooltip: l10n.logout,
                  icon: const Icon(Icons.logout, color: FormaTheme.textSecondary, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmLogout(context, l10n),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('assistant_fab'),
        backgroundColor: FormaTheme.primaryTeal,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.smart_toy_outlined),
        label: Text(l10n.assistantTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssistantScreen()),
          );
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSnapshotProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tagline,
                  style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),

                // Epistemic Class Badges Legend
                _buildEpistemicLegend(l10n),
                const SizedBox(height: 20),

                snapshotAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
                    ),
                  ),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FormaTheme.criticalCrimson.withValues(alpha: 0.15),
                      border: Border.all(color: FormaTheme.criticalCrimson.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: FormaTheme.criticalCrimson),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            err.toString().replaceAll('ApiException(0): ', ''),
                            style: const TextStyle(color: FormaTheme.criticalCrimson),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.invalidate(dashboardSnapshotProvider),
                          child: Text(l10n.retry, style: const TextStyle(color: FormaTheme.primaryTeal)),
                        ),
                      ],
                    ),
                  ),
                  data: (snapshot) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Primary Goal & Progress Card
                      _buildGoalCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 2. Noise-Robust Trends Card
                      _buildTrendsCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 3. Energy & Nutrition Targets Card
                      _buildEnergyTargetsCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 4. Honest Health Records / Quick Log Action
                      _buildMeasurementsSection(snapshot, l10n, numeralSystem),
                    ],
                  ),
                ),
              ],
            ),
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

  Widget _buildGoalCard(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    if (!snapshot.hasActiveGoal) {
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
                  _buildBadge(l10n.asserted, FormaTheme.badgeAsserted),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.goalWeightLoss,
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'No active goal set. Tap below to configure your target weight and weekly trajectory.',
                style: TextStyle(color: FormaTheme.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const Key('set_goal_button'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Set Primary Goal'),
                onPressed: () => _showSetGoalDialog(context, l10n),
              ),
            ],
          ),
        ),
      );
    }

    final startingKg = snapshot.startingValue ?? 0.0;
    final currentKg = snapshot.currentValue ?? snapshot.latestWeightKg ?? startingKg;
    final targetKg = snapshot.targetValue ?? startingKg;
    final progress = (snapshot.progressPct ?? 0.0).clamp(0.0, 100.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: FormaTheme.warningAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.primaryGoal,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              snapshot.goalType == 'weight_gain' ? l10n.goalMuscleGain : l10n.goalWeightLoss,
              style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMetricCol(
                    l10n.startingValue,
                    '${formatNumeralString(startingKg.toStringAsFixed(1), numeralSystem)} kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCol(
                    l10n.currentValue,
                    '${formatNumeralString(currentKg.toStringAsFixed(1), numeralSystem)} kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCol(
                    l10n.targetValue,
                    '${formatNumeralString(targetKg.toStringAsFixed(1), numeralSystem)} kg',
                  ),
                ),
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
                Flexible(
                  child: Text(
                    '${l10n.progress}: ${formatNumeralString(progress.toStringAsFixed(1), numeralSystem)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    snapshot.isSafeRate ? l10n.safeRate : l10n.rateWarning,
                    style: TextStyle(
                      color: snapshot.isSafeRate ? FormaTheme.successGreen : FormaTheme.warningAmber,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsCard(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    final smoothedWeight = snapshot.trend7dKg;
    final weeklyRate = snapshot.weeklyRateKg;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.trending_down, color: FormaTheme.primaryTeal, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.trends,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodChip('7d', l10n.period7d),
                  const SizedBox(width: 8),
                  _buildPeriodChip('30d', l10n.period30d),
                  const SizedBox(width: 8),
                  _buildPeriodChip('90d', l10n.period90d),
                  const SizedBox(width: 8),
                  _buildPeriodChip('1y', l10n.period1y),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (smoothedWeight != null && weeklyRate != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildMetricCol(
                      l10n.sevenDayAverage,
                      '${formatNumeralString(smoothedWeight.toStringAsFixed(1), numeralSystem)} kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCol(
                      l10n.weeklyRate,
                      '${formatNumeralString(weeklyRate >= 0 ? "+${weeklyRate.toStringAsFixed(2)}" : weeklyRate.toStringAsFixed(2), numeralSystem)} kg/wk',
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FormaTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: FormaTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.insufficientTrendData,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildEnergyTargetsCard(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    final maintenance = snapshot.maintenanceCalories;
    final target = snapshot.targetCalories;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: FormaTheme.warningAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.energyTargets,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 14),
            if (maintenance != null && target != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildMetricCol(
                      l10n.maintenanceCalories,
                      '${formatNumeralString(maintenance.round().toString(), numeralSystem)} kcal',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCol(
                      l10n.targetCalories,
                      '${formatNumeralString(target.round().toString(), numeralSystem)} kcal',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Deterministic macro breakdown: 30% protein, 25% fats, 45% carbs
              Builder(builder: (context) {
                final proteinGrams = (target * 0.30 / 4).round();
                final fatGrams = (target * 0.25 / 9).round();
                final carbGrams = (target * 0.45 / 4).round();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMacroBar(l10n.protein, '${proteinGrams}g', FormaTheme.primaryTeal, numeralSystem)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroBar(l10n.fats, '${fatGrams}g', FormaTheme.warningAmber, numeralSystem)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroBar(l10n.carbs, '${carbGrams}g', FormaTheme.secondaryMint, numeralSystem)),
                  ],
                );
              }),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FormaTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: FormaTheme.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Log your weight and profile parameters to generate deterministic BMR & energy targets.',
                        style: TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String label, String amount, Color color, String numeralSystem) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        FractionallySizedBox(
          widthFactor: 0.8,
          child: Container(
            height: 6,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatNumeralString(amount, numeralSystem),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMeasurementsSection(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    l10n.healthRecords,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: ElevatedButton.icon(
                    key: const Key('add_measurement_button'),
                    onPressed: () => _showAddMeasurementDialog(context, l10n),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      l10n.addMeasurement,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.recentMeasurements.isNotEmpty) ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.recentMeasurements.length,
                separatorBuilder: (_, _) => const Divider(color: FormaTheme.borderSubtle, height: 1),
                itemBuilder: (context, idx) {
                  final m = snapshot.recentMeasurements[idx];
                  final label = m.typeCode == 'weight'
                      ? l10n.weight
                      : m.typeCode == 'body_fat_percentage'
                          ? l10n.bodyFat
                          : m.typeCode;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: FormaTheme.surfaceElevated,
                      child: Icon(
                        m.typeCode == 'weight' ? Icons.monitor_weight_outlined : Icons.fitness_center,
                        color: FormaTheme.primaryTeal,
                        size: 20,
                      ),
                    ),
                    title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${formatNumeralString(m.canonicalValue.toStringAsFixed(1), numeralSystem)} ${m.canonicalUnit}',
                      style: const TextStyle(color: FormaTheme.textSecondary),
                    ),
                    trailing: _buildBadge(
                      m.epistemicClass == 'calculated'
                          ? l10n.calculated
                          : m.epistemicClass == 'estimated'
                              ? l10n.estimated
                              : l10n.measured,
                      m.epistemicClass == 'calculated'
                          ? FormaTheme.badgeCalculated
                          : m.epistemicClass == 'estimated'
                              ? FormaTheme.badgeEstimated
                              : FormaTheme.badgeMeasured,
                    ),
                  );
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.monitor_weight_outlined, size: 40, color: FormaTheme.textSecondary),
                    const SizedBox(height: 8),
                    Text(
                      l10n.emptyMeasurementsTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.emptyMeasurementsDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
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
    final valueController = TextEditingController(text: '80.0');
    final unitController = TextEditingController(text: 'kg');
    String selectedType = 'weight';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: Text(l10n.addMeasurement),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('measurement_type_dropdown'),
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  DropdownMenuItem(value: 'weight', child: Text(l10n.weight)),
                  DropdownMenuItem(value: 'body_fat_percentage', child: Text(l10n.bodyFat)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      selectedType = val;
                      unitController.text = val == 'weight' ? 'kg' : '%';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('measurement_value_field'),
                controller: valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.value,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('measurement_unit_field'),
                controller: unitController,
                decoration: InputDecoration(
                  labelText: l10n.unit,
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
              key: const Key('save_measurement_button'),
              onPressed: () async {
                final val = double.tryParse(valueController.text);
                if (val == null) return;

                Navigator.of(ctx).pop();
                try {
                  await ref.read(measurementsRepositoryProvider).recordObservation(
                        typeCode: selectedType,
                        value: val,
                        unit: unitController.text.trim(),
                      );
                  ref.invalidate(dashboardSnapshotProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Measurement recorded successfully'),
                        backgroundColor: FormaTheme.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: FormaTheme.criticalCrimson,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetGoalDialog(BuildContext context, AppLocalizations l10n) {
    final targetController = TextEditingController(text: '75.0');
    final baselineController = TextEditingController(text: '85.0');
    String goalType = 'weight_loss';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: const Text('Set Primary Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: goalType,
                decoration: const InputDecoration(labelText: 'Goal Type'),
                items: [
                  DropdownMenuItem(value: 'weight_loss', child: Text(l10n.goalWeightLoss)),
                  DropdownMenuItem(value: 'weight_gain', child: Text(l10n.goalMuscleGain)),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => goalType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: baselineController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l10n.startingValue} (kg)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l10n.targetValue} (kg)',
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
              onPressed: () async {
                final target = double.tryParse(targetController.text);
                final baseline = double.tryParse(baselineController.text);
                if (target == null || baseline == null) return;

                Navigator.of(ctx).pop();
                try {
                  await ref.read(goalsRepositoryProvider).createGoal(
                        type: goalType,
                        targetValue: target,
                        baselineValue: baseline,
                      );
                  ref.invalidate(dashboardSnapshotProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Goal created successfully'),
                        backgroundColor: FormaTheme.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: FormaTheme.criticalCrimson,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.logout),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            key: const Key('confirm_logout_button'),
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authStateProvider.notifier).logout();
            },
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}
