import 'dart:convert';
import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../modules/analytics/models/snapshot_model.dart';
import '../../modules/analytics/repositories/analytics_repository.dart';
import '../../modules/measurements/repositories/measurements_repository.dart';
import '../../modules/goals/repositories/goals_repository.dart';
import '../../modules/goals/models/goal_model.dart';
import '../../modules/auth/notifiers/auth_state.dart';
import '../../modules/multimodal/repositories/multimodal_repository.dart';
import 'assistant_screen.dart';
import 'settings_screen.dart';
import 'multimodal_review_screen.dart';
import '../../modules/measurements/screens/measurement_history_sheet.dart';

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
                width: 26,
                height: 26,
                cacheWidth: 78,
                cacheHeight: 78,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.fitness_center_rounded, color: FormaTheme.primaryTeal, size: 22),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.appTitle,
                style: const TextStyle(
                  color: FormaTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
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
          // 1. Assistant button (Clean in-app bar integration, key preserved)
          IconButton(
            key: const Key('assistant_button'),
            tooltip: l10n.assistantTitle,
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: FormaTheme.textSecondary, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssistantScreen()),
              );
            },
          ),
          // 3. Settings button (key preserved)
          IconButton(
            key: const Key('settings_button'),
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined, color: FormaTheme.textSecondary, size: 20),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          // 4. Language toggle (key preserved)
          TextButton(
            key: const Key('language_toggle_button'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            child: Text(
              currentLocale.languageCode == 'en' ? 'العربية' : 'English',
              style: const TextStyle(
                color: FormaTheme.primaryTeal,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          // 5. Logout (key preserved)
          IconButton(
            key: const Key('logout_button'),
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout_rounded, color: FormaTheme.textTertiary, size: 19),
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmLogout(context, l10n),
          ),
          const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
      // Clean non-overlapping bottom navigation strip instead of a giant floating FAB blocking logs
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: FormaTheme.surfaceCard,
          border: Border(top: BorderSide(color: FormaTheme.borderSubtle)),
        ),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('assistant_fab'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FormaTheme.borderSubtle),
                  foregroundColor: FormaTheme.textPrimary,
                  backgroundColor: FormaTheme.surfaceElevated,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: FormaTheme.primaryTeal),
                label: Text(
                  l10n.assistantTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AssistantScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('add_measurement_quick_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FormaTheme.primaryTeal,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  currentLocale.languageCode == 'ar' ? 'تسجيل جديد' : 'New Entry',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _showAddMeasurementDialog(context, l10n, snapshotAsync.valueOrNull),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: FormaTheme.primaryTeal,
          onRefresh: () async {
            ref.invalidate(dashboardSnapshotProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                snapshotAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
                    ),
                  ),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FormaTheme.criticalCrimson.withValues(alpha: 0.12),
                      border: Border.all(color: FormaTheme.criticalCrimson.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: FormaTheme.criticalCrimson),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            formatApiErrorMessage(err),
                            style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
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
                      // 1. Physical Status & Body Composition Glance
                      _buildBodyStatusCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 2. Primary Goal & Progress Card
                      _buildGoalCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 3. Noise-Robust Trends Card (Multi-Window Dynamic Query)
                      _buildTrendsCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 3b. Data Quality & Anomaly Flags (visible only when present)
                      if (snapshot.anomalies.isNotEmpty || snapshot.dataQuality != null)
                        _buildDataQualityCard(snapshot, l10n),
                      if (snapshot.anomalies.isNotEmpty || snapshot.dataQuality != null)
                        const SizedBox(height: 16),

                      // 4. Energy & Nutrition Targets Card
                      _buildEnergyTargetsCard(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 5. Honest Health Records / Quick Log Action
                      _buildMeasurementsSection(snapshot, l10n, numeralSystem),
                      const SizedBox(height: 16),

                      // 6. Pending extraction drafts awaiting review
                      _buildPendingDraftsCard(l10n),
                      const SizedBox(height: 24),
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

  Widget _buildBodyStatusCard(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    final weightKg = snapshot.latestWeightKg;
    final bmi = snapshot.bmi;
    final bmiCategory = snapshot.bmiCategory;

    String localizedBmiCategory(String? cat) {
      switch (cat?.toLowerCase()) {
        case 'underweight':
          return l10n.bmiCategoryUnderweight;
        case 'normal':
          return l10n.bmiCategoryNormal;
        case 'overweight':
          return l10n.bmiCategoryOverweight;
        case 'obese':
          return l10n.bmiCategoryObese;
        default:
          return cat ?? 'Normal';
      }
    }

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
                      const Icon(Icons.accessibility_new_rounded, color: FormaTheme.primaryTeal, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.weightAndCompositionSection,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge(l10n.measured, FormaTheme.badgeMeasured),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMetricCol(
                    l10n.weight,
                    weightKg != null
                        ? '${formatNumeralString(weightKg.toStringAsFixed(1), numeralSystem)} kg'
                        : '-- kg',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCol(
                    l10n.bmiTitle,
                    bmi != null
                        ? formatNumeralString(bmi.toStringAsFixed(1), numeralSystem)
                        : '--',
                  ),
                ),
                if (bmiCategory != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: FormaTheme.primaryTeal.withValues(alpha: 0.14),
                          border: Border.all(color: FormaTheme.primaryTeal.withValues(alpha: 0.35), width: 0.8),
                          borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
                        ),
                        child: Text(
                          localizedBmiCategory(bmiCategory),
                          style: const TextStyle(
                            color: FormaTheme.primaryTealLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
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
                label: Text(l10n.setPrimaryGoal),
                onPressed: () => _showSetGoalDialog(context, l10n, snapshot),
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
    final remainingDiff = (currentKg - targetKg).abs();
    final projectedDate = snapshot.projectedTargetDate;

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
                IconButton(
                  tooltip: 'Update Goal',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: FormaTheme.primaryTeal),
                  onPressed: () => _showUpdateGoalDialog(context, l10n, snapshot),
                ),
                if (snapshot.goalId != null)
                  IconButton(
                    tooltip: 'Goal History',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.history, size: 18, color: FormaTheme.textSecondary),
                    onPressed: () => _showGoalVersionsSheet(snapshot.goalId!, l10n),
                  ),
                const SizedBox(width: 8),
                _buildBadge(l10n.calculated, FormaTheme.badgeCalculated),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    snapshot.goalType == 'weight_gain' ? l10n.goalMuscleGain : l10n.goalWeightLoss,
                    style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.remainingToTarget(formatNumeralString(remainingDiff.toStringAsFixed(1), numeralSystem)),
                    style: const TextStyle(color: FormaTheme.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
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
                if (snapshot.isSafeRate != null)
                  Flexible(
                    child: Text(
                      snapshot.isSafeRate! ? l10n.safeRate : l10n.rateWarning,
                      style: TextStyle(
                        color: snapshot.isSafeRate! ? FormaTheme.successGreen : FormaTheme.warningAmber,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            if (projectedDate != null && projectedDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.projectedCompletionDate(formatNumeralString(projectedDate.substring(0, 10), numeralSystem)),
                style: const TextStyle(color: FormaTheme.textTertiary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _selectedDays() {
    switch (selectedPeriod) {
      case '7d':
        return 7;
      case '30d':
        return 30;
      case '90d':
        return 90;
      case '1y':
        return 365;
      default:
        return 30;
    }
  }

  Widget _buildTrendsCard(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem) {
    final windowDays = _selectedDays();
    final trendAsync = ref.watch(trendAnalysisProvider(('weight', windowDays)));

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
            trendAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: FormaTheme.primaryTeal),
                  ),
                ),
              ),
              error: (_, _) => _buildFallbackTrend(snapshot, l10n, numeralSystem),
              data: (trendData) {
                final sufficiency = trendData['sufficiency'] as String? ?? 'insufficient';
                final smoothed = (trendData['smoothedLatest'] as num?)?.toDouble() ?? snapshot.trend7dKg;
                final weeklyRate = (trendData['weeklyRate'] as num?)?.toDouble() ?? snapshot.weeklyRateKg;
                final delta = (trendData['deltaValue'] as num?)?.toDouble();
                final rawSeries = (trendData['series'] as List<dynamic>?) ?? const [];
                final smoothedSeries = (trendData['smoothedSeries'] as List<dynamic>?) ?? const [];

                if (sufficiency == 'complete' && smoothed != null && weeklyRate != null) {
                  return Column(
                    children: [
                      if (rawSeries.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildTrendChart(rawSeries, smoothedSeries),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildMetricCol(
                              l10n.sevenDayAverage,
                              '${formatNumeralString(smoothed.toStringAsFixed(1), numeralSystem)} kg',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCol(
                              l10n.weeklyRate,
                              '${formatNumeralString(weeklyRate >= 0 ? "+${weeklyRate.toStringAsFixed(2)}" : weeklyRate.toStringAsFixed(2), numeralSystem)} kg/wk',
                            ),
                          ),
                          if (delta != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMetricCol(
                                l10n.deltaChange(''),
                                '${formatNumeralString(delta >= 0 ? "+${delta.toStringAsFixed(1)}" : delta.toStringAsFixed(1), numeralSystem)} kg',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      // Real recorded points still chart even when the trend
                      // rate is not yet computable.
                      if (rawSeries.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTrendChart(rawSeries, smoothedSeries),
                        ),
                      _buildFallbackTrend(snapshot, l10n, numeralSystem, trendData['reason'] as String?),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Line chart of real observations (dim) + server-computed EMA smoothed
  /// trend (teal). Series come from GET /api/v1/analytics/trends/:typeCode.
  Widget _buildTrendChart(List<dynamic> rawSeries, List<dynamic> smoothedSeries) {
    List<FlSpot> toSpots(List<dynamic> series) {
      if (series.isEmpty) return const [];
      final first = DateTime.tryParse((series.first as Map)['observedAt']?.toString() ?? '');
      if (first == null) return const [];
      final spots = <FlSpot>[];
      for (final p in series) {
        final m = p as Map;
        final t = DateTime.tryParse(m['observedAt']?.toString() ?? '');
        final v = (m['value'] as num?)?.toDouble();
        if (t == null || v == null) continue;
        spots.add(FlSpot(t.difference(first).inMilliseconds / 86400000.0, v));
      }
      return spots;
    }

    final raw = toSpots(rawSeries);
    final smooth = toSpots(smoothedSeries);
    if (raw.length < 2) return const SizedBox.shrink();

    final minY = raw.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = raw.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.5, 5.0);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9, color: FormaTheme.textSecondary),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                getTitlesWidget: (v, _) => Text(
                  '${v.round()}d',
                  style: const TextStyle(fontSize: 9, color: FormaTheme.textSecondary),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: raw,
              isCurved: false,
              color: FormaTheme.textSecondary.withValues(alpha: 0.5),
              barWidth: 1.5,
              dotData: const FlDotData(show: true),
            ),
            if (smooth.length >= 2)
              LineChartBarData(
                spots: smooth,
                isCurved: true,
                color: FormaTheme.primaryTeal,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackTrend(SnapshotModel snapshot, AppLocalizations l10n, String numeralSystem, [String? explicitReason]) {
    final smoothedWeight = snapshot.trend7dKg;
    final weeklyRate = snapshot.weeklyRateKg;

    if (smoothedWeight != null && weeklyRate != null) {
      return Row(
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
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FormaTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
        border: Border.all(color: FormaTheme.borderSubtle, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart_rounded, color: FormaTheme.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.insufficientTrendData,
                  style: const TextStyle(
                    color: FormaTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            explicitReason ?? 'Log measurements consistently across several days to calculate your smoothed trend and rate of progress.',
            style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
          ),
        ],
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
              // Macro breakdown is rendered only when the backend CalculationEngine
              // returns real values — never fabricated client-side.
              if (snapshot.proteinGrams != null &&
                  snapshot.fatGrams != null &&
                  snapshot.carbsGrams != null) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMacroBar(l10n.protein, '${snapshot.proteinGrams}g', '${(snapshot.proteinPct ?? 0).round()}%', FormaTheme.primaryTeal, numeralSystem)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroBar(l10n.fats, '${snapshot.fatGrams}g', '${(snapshot.fatPct ?? 0).round()}%', FormaTheme.warningAmber, numeralSystem)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildMacroBar(l10n.carbs, '${snapshot.carbsGrams}g', '${(snapshot.carbsPct ?? 0).round()}%', FormaTheme.secondaryMint, numeralSystem)),
                  ],
                ),
              ],
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

  Widget _buildMacroBar(String label, String amount, String sharePct, Color color, String numeralSystem) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              formatNumeralString(sharePct, numeralSystem),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  l10n.healthRecords,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton.icon(
                  key: const Key('view_all_history_button'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const MeasurementHistorySheet(initialTypeCode: 'weight'),
                    );
                  },
                  icon: const Icon(Icons.history_rounded, size: 16, color: FormaTheme.primaryTeal),
                  label: Text(l10n.allHistory, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  ),
                ),
                IconButton(
                  key: const Key('extract_report_button'),
                  tooltip: l10n.extractReport,
                  onPressed: () => _showImageExtractionDialog(context, l10n),
                  icon: const Icon(Icons.photo_camera_outlined, color: FormaTheme.primaryTeal, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
                ElevatedButton.icon(
                  key: const Key('add_measurement_button'),
                  onPressed: () => _showAddMeasurementDialog(context, l10n, snapshot),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.addMeasurement),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                    onTap: () => _showObservationProvenanceDialog(context, m, l10n, numeralSystem),
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
          style: const TextStyle(
            color: FormaTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: FormaTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 0.8),
        borderRadius: BorderRadius.circular(FormaTheme.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  void _showAddMeasurementDialog(BuildContext context, AppLocalizations l10n, [SnapshotModel? snapshot]) {
    final latestWeightKg = snapshot?.latestWeightKg;
    final defaultVal = latestWeightKg != null ? latestWeightKg.toStringAsFixed(1) : '';
    final valueController = TextEditingController(text: defaultVal);
    final unitController = TextEditingController();
    String? selectedType;

    String humanize(String code) =>
        code.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');


    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: Text(l10n.addMeasurement),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Catalog-driven picker — only user-enterable types from
                // GET /api/v1/measurements/types (never a hardcoded list).
                Consumer(
                  builder: (ctx, ref, _) {
                    final typesAsync = ref.watch(measurementTypesProvider);
                    return typesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (err, _) => Column(
                        children: [
                          Text(l10n.errorOccurred, style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 12)),
                          TextButton(
                            onPressed: () => ref.invalidate(measurementTypesProvider),
                            child: Text(l10n.retry),
                          ),
                        ],
                      ),
                      data: (types) {
                        final enterable = types.where((t) => t.isUserEnterable).toList();
                        if (enterable.isEmpty) {
                          return Text(l10n.noMeasurementTypesAvailable, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12));
                        }
                        final selected = enterable.where((t) => t.code == selectedType).firstOrNull;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              key: const Key('measurement_type_dropdown'),
                              initialValue: selected?.code,
                              isExpanded: true,
                              dropdownColor: FormaTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              decoration: const InputDecoration(labelText: 'Type'),
                              items: enterable.map((t) {
                                return DropdownMenuItem(
                                  value: t.code,
                                  child: Text(humanize(t.code), overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedType = val;
                                    final matched = enterable.firstWhere((t) => t.code == val);
                                    unitController.text = matched.canonicalUnit;
                                  });
                                }
                              },
                            ),
                            if (selected != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Range: ${selected.minPlausible}–${selected.maxPlausible} ${selected.canonicalUnit}',
                                  style: const TextStyle(fontSize: 11, color: FormaTheme.textSecondary),
                                ),
                              ),
                          ],
                        );
                      },
                    );
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
                final type = selectedType;
                if (val == null || type == null) return;

                Navigator.of(ctx).pop();
                try {
                  await ref.read(measurementsRepositoryProvider).recordObservation(
                        typeCode: type,
                        value: val,
                        unit: unitController.text.trim(),
                      );
                  ref.invalidate(dashboardSnapshotProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.measurementRecorded),
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

  void _showObservationProvenanceDialog(
    BuildContext context,
    SnapshotMeasurementItem m,
    AppLocalizations l10n,
    String numeralSystem,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FormaTheme.surfaceCard,
        title: Text(l10n.provenanceTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.metricLabel(m.typeCode), style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(l10n.canonicalValueLabel(formatNumeralString(m.canonicalValue.toStringAsFixed(2), numeralSystem), m.canonicalUnit)),
              const SizedBox(height: 6),
              Text(l10n.epistemicClassLabel((m.epistemicClass ?? 'unknown').toUpperCase()), style: const TextStyle(color: FormaTheme.primaryTeal)),
              const SizedBox(height: 6),
              Text(l10n.observedAtLabel(m.observedAt)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                l10n.appendOnlyNote,
                style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history, size: 16),
            label: Text(l10n.history),
            onPressed: () {
              Navigator.of(ctx).pop();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => MeasurementHistorySheet(initialTypeCode: m.typeCode),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final targetId = m.id ?? (await ref.read(measurementsRepositoryProvider).getObservations(typeCode: m.typeCode, limit: 1)).firstOrNull?.id;
                if (targetId != null) {
                  await ref.read(measurementsRepositoryProvider).voidObservation(
                        targetId,
                        'Voided by user from dashboard',
                      );
                  ref.invalidate(dashboardSnapshotProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.observationVoided),
                        backgroundColor: FormaTheme.successGreen,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.voidFailed(e.toString())),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.voidRecord),
          ),
        ],
      ),
    );
  }

  void _showImageExtractionDialog(BuildContext context, AppLocalizations l10n) {
    final imagePicker = ImagePicker();
    final config = ref.read(envConfigProvider);
    String selectedKind = 'body_composition_report';
    Uint8List? pickedBytes;
    String? pickedBase64;
    String? pickError;
    bool isExtracting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            setDialogState(() => pickError = null);
            try {
              final picked = await imagePicker.pickImage(
                source: source,
                maxWidth: config.imageMaxDimensionPx.toDouble(),
                maxHeight: config.imageMaxDimensionPx.toDouble(),
                imageQuality: config.imageJpegQuality,
              );
              if (picked == null) return;
              final bytes = await picked.readAsBytes();
              setDialogState(() {
                pickedBytes = bytes;
                pickedBase64 = base64Encode(bytes);
              });
            } catch (_) {
              setDialogState(() {
                pickedBytes = null;
                pickedBase64 = null;
                pickError = l10n.imageCaptureFailed;
              });
            }
          }

          return AlertDialog(
            backgroundColor: FormaTheme.surfaceCard,
            title: Text(l10n.multimodalReviewTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.extractionDialogHint,
                    style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKind,
                    isExpanded: true,
                    dropdownColor: FormaTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    decoration: InputDecoration(labelText: l10n.reportType),
                    items: [
                      DropdownMenuItem(value: 'body_composition_report', child: Text(l10n.docTypeBodyComposition, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'scale_display', child: Text(l10n.docTypeScaleDisplay, overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'tape_measurement_sheet', child: Text(l10n.docTypeTapeSheet, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedKind = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (pickedBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        pickedBytes!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: FormaTheme.successGreen, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.imageReady,
                            style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    key: const Key('capture_photo_button'),
                    icon: const Icon(Icons.photo_camera_outlined, color: FormaTheme.primaryTeal),
                    label: Text(pickedBytes == null ? l10n.capturePhoto : l10n.retakePhoto),
                    onPressed: isExtracting ? null : () => pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('choose_gallery_button'),
                    icon: const Icon(Icons.photo_library_outlined, color: FormaTheme.primaryTeal),
                    label: Text(l10n.chooseFromGallery),
                    onPressed: isExtracting ? null : () => pickImage(ImageSource.gallery),
                  ),
                  if (pickError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      pickError!,
                      style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
            TextButton(
              onPressed: isExtracting ? null : () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton.icon(
              icon: isExtracting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.analytics_outlined, size: 16),
              label: Text(l10n.extractReport),
              onPressed: (isExtracting || pickedBase64 == null)
                  ? null
                  : () async {
                      final b64 = pickedBase64!;

                      setDialogState(() => isExtracting = true);
                      try {
                        final res = await ref.read(multimodalRepositoryProvider).uploadAndExtract(
                              imageBase64: b64,
                              imageKindHint: selectedKind,
                            );

                        if (ctx.mounted) Navigator.of(ctx).pop();

                        final draftMap = res['draft'] as Map<String, dynamic>;
                        _openDraftReview(draftMap);
                      } catch (err) {
                        setDialogState(() => isExtracting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(l10n.extractionFailedMsg(err.toString())),
                              backgroundColor: FormaTheme.criticalCrimson,
                            ),
                          );
                        }
                      }
                    },
            ),
          ],
          );
        },
      ),
    );
  }

  /// Data-quality strip: real anomaly flags + measured-share/staleness
  /// metrics from the snapshot — rendered only when the backend emits them.
  Widget _buildDataQualityCard(SnapshotModel snapshot, AppLocalizations l10n) {
    final dq = snapshot.dataQuality;
    Color severityColor(String? severity) {
      switch (severity) {
        case 'critical':
          return FormaTheme.criticalCrimson;
        case 'warning':
          return FormaTheme.warningAmber;
        default:
          return FormaTheme.primaryTeal;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined, color: FormaTheme.primaryTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.dataQuality,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dq != null) ...[
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (dq.totalActiveObservations != null)
                    _buildMetricCol(l10n.observationsLabel, '${dq.totalActiveObservations}'),
                  if (dq.measuredSharePct != null)
                    _buildMetricCol(l10n.measuredShare, '${dq.measuredSharePct!.toStringAsFixed(0)}%'),
                  if (dq.stalenessDays != null)
                    _buildMetricCol(l10n.staleness, '${dq.stalenessDays}d'),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (snapshot.anomalies.isEmpty)
              Text(l10n.noAnomaliesDetected, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12))
            else
              ...snapshot.anomalies.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.flag_outlined, size: 16, color: severityColor(a.severity)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a.flagType ?? 'unknown'} • ${(a.severity ?? 'info').toUpperCase()}',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: severityColor(a.severity)),
                              ),
                              if ((a.details['reason'] ?? a.details['description']) != null)
                                Text(
                                  (a.details['reason'] ?? a.details['description']).toString(),
                                  style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  /// Pending extraction drafts — resume review of a previously uploaded report.
  Widget _buildPendingDraftsCard(AppLocalizations l10n) {
    final draftsAsync = ref.watch(pendingDraftsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pending_actions_outlined, color: FormaTheme.primaryTeal, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.pendingReviews,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            draftsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (err, _) => Row(
                children: [
                  Expanded(
                    child: Text(l10n.errorOccurred, style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(pendingDraftsProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
              data: (drafts) => drafts.isEmpty
                  ? Text(l10n.noPendingDrafts, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12))
                  : Column(
                      children: drafts.map((d) {
                        final id = d['id']?.toString() ?? '';
                        final kind = d['imageKind']?.toString() ?? d['image_kind']?.toString() ?? '—';
                        final created = d['createdAt']?.toString() ?? '';
                        final fieldCount = (d['extractedFields'] as List<dynamic>?)?.length;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.document_scanner_outlined, color: FormaTheme.textSecondary, size: 20),
                          title: Text(kind, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${created.isNotEmpty ? created.substring(0, 10) : '—'}${fieldCount != null ? ' • $fieldCount fields' : ''}',
                            style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: TextButton(
                            onPressed: id.isEmpty
                                ? null
                                : () async {
                                    try {
                                      final full = await ref.read(multimodalRepositoryProvider).getDraft(id);
                                      _openDraftReview(full);
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(formatApiErrorMessage(e)), backgroundColor: FormaTheme.criticalCrimson),
                                        );
                                      }
                                    }
                                  },
                            child: Text(l10n.reviewAction),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Maps a draft response map → DraftReviewState and opens the review screen.
  /// Skips malformed extraction rows rather than rendering invented values.
  void _openDraftReview(Map<String, dynamic> draftMap) {
    final rawFields = (draftMap['extractedFields'] as List<dynamic>?) ?? [];
    final fieldItems = <ExtractedFieldItem>[];
    for (final f in rawFields) {
      final fMap = f as Map<String, dynamic>;
      final typeCode = fMap['typeCode'] as String?;
      final value = (fMap['extractedValue'] as num?)?.toDouble();
      if (typeCode == null || value == null) continue;
      fieldItems.add(ExtractedFieldItem(
        typeCode: typeCode,
        rawLabel: fMap['rawLabel'] as String? ?? '',
        extractedValue: value,
        userEditedValue: (fMap['userEditedValue'] as num?)?.toDouble(),
        unit: fMap['unit'] as String? ?? '',
        canonicalValue: (fMap['canonicalValue'] as num?)?.toDouble() ?? value,
        canonicalUnit: fMap['canonicalUnit'] as String? ?? '',
        confidenceScore: (fMap['confidenceScore'] as num?)?.toDouble() ?? 0.0,
        qualityFlags: (fMap['qualityFlags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        epistemicClass: fMap['epistemicClass'] as String? ?? 'asserted',
        isApproved: fMap['isApproved'] as bool? ?? false,
      ));
    }

    final draftId = draftMap['id'] as String?;
    if (draftId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10nForContext.errorOccurred), backgroundColor: FormaTheme.criticalCrimson),
        );
      }
      return;
    }

    final initialDraft = DraftReviewState(
      draftId: draftId,
      imageKind: draftMap['imageKind'] as String? ?? draftMap['image_kind'] as String? ?? '',
      status: draftMap['status'] as String? ?? 'draft',
      overallConfidence: (draftMap['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      fields: fieldItems,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultimodalReviewScreen(
          initialDraft: initialDraft,
          onCommit: (state) async {
            final commitRes = await ref.read(multimodalRepositoryProvider).commitDraft(
                  draftId: state.draftId,
                  deleteSourceImage: state.deleteSourceImage,
                );
            ref.invalidate(dashboardSnapshotProvider);
            ref.invalidate(pendingDraftsProvider);
            return commitRes['receipt']?['receiptId'] as String?;
          },
        ),
      ),
    );
  }

  AppLocalizations get l10nForContext => AppLocalizations.of(context)!;

  /// Immutable goal-version history (GET /api/v1/goals/:id/versions).
  void _showGoalVersionsSheet(String goalId, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16.0),
        decoration: const BoxDecoration(
          color: FormaTheme.surfaceCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: FormaTheme.primaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.goalHistory,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<GoalVersionModel>>(
                future: ref.read(goalsRepositoryProvider).listGoalVersions(goalId),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: FormaTheme.primaryTeal));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('${l10n.errorOccurred}\n${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: FormaTheme.criticalCrimson)),
                    );
                  }
                  final versions = snap.data ?? const [];
                  if (versions.isEmpty) {
                    return Center(
                      child: Text(l10n.noGoalVersions,
                          style: const TextStyle(color: FormaTheme.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    itemCount: versions.length,
                    separatorBuilder: (_, _) => const Divider(color: FormaTheme.borderSubtle, height: 1),
                    itemBuilder: (ctx, idx) {
                      final v = versions[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: FormaTheme.surfaceElevated,
                          child: Text('v${v.version}',
                              style: const TextStyle(fontSize: 11, color: FormaTheme.primaryTeal)),
                        ),
                        title: Text(
                          '${v.startingValue.toStringAsFixed(1)} → ${v.targetValue.toStringAsFixed(1)}${v.weeklyRate != null ? ' • ${v.weeklyRate! >= 0 ? '+' : ''}${v.weeklyRate}/wk' : ''}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${v.startDate}${v.targetDate != null ? ' → ${v.targetDate}' : ''}${v.rationale != null ? '\n${v.rationale}' : ''}',
                          style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11),
                        ),
                        isThreeLine: v.rationale != null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetGoalDialog(BuildContext context, AppLocalizations l10n, [SnapshotModel? snapshot]) {
    // Prefill the baseline only from a real measured weight — never invent one.
    final currentWeight = snapshot?.latestWeightKg;
    final baselineController = TextEditingController(
      text: currentWeight != null ? currentWeight.toStringAsFixed(1) : '',
    );
    final targetController = TextEditingController();
    String goalType = 'weight_loss';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: Text(l10n.setPrimaryGoal),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: goalType,
                  isExpanded: true,
                  dropdownColor: FormaTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  decoration: const InputDecoration(labelText: 'Goal Type'),
                  items: [
                    DropdownMenuItem(value: 'weight_loss', child: Text(l10n.goalWeightLoss, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'muscle_gain', child: Text(l10n.goalMuscleGain, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'maintenance', child: Text(l10n.goalMaintenance, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'general_fitness', child: Text(l10n.goalGeneralFitness, overflow: TextOverflow.ellipsis)),
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
                      SnackBar(
                        content: Text(l10n.goalCreated),
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

  void _showUpdateGoalDialog(BuildContext context, AppLocalizations l10n, SnapshotModel snapshot) {
    final goalId = snapshot.goalId;
    if (goalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.activeGoalNotFound),
          backgroundColor: FormaTheme.warningAmber,
        ),
      );
      return;
    }

    final currentTarget = snapshot.targetValue?.toStringAsFixed(1) ?? '';
    final targetController = TextEditingController(text: currentTarget);
    final rateController = TextEditingController();
    final rationaleController = TextEditingController();
    String selectedAction = 'new_version';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: FormaTheme.surfaceCard,
          title: Text(l10n.managePrimaryGoal),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedAction,
                  isExpanded: true,
                  dropdownColor: FormaTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  decoration: InputDecoration(labelText: l10n.action),
                  items: [
                    DropdownMenuItem(value: 'new_version', child: Text(l10n.goalAdjustTarget)),
                    DropdownMenuItem(value: 'status_complete', child: Text(l10n.goalMarkCompleted)),
                    DropdownMenuItem(value: 'status_archive', child: Text(l10n.goalArchive)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedAction = val);
                  },
                ),
                const SizedBox(height: 12),
                if (selectedAction == 'new_version') ...[
                  TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${l10n.targetValue} (kg)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Weekly Target Rate (kg/wk)',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: rationaleController,
                  decoration: const InputDecoration(
                    labelText: 'Rationale / Reason',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final rationale = rationaleController.text.trim();
                Navigator.of(ctx).pop();
                try {
                  final goalsRepo = ref.read(goalsRepositoryProvider);
                  if (selectedAction == 'new_version') {
                    final target = double.tryParse(targetController.text);
                    final rate = double.tryParse(rateController.text);
                    if (target == null) return;
                    await goalsRepo.addGoalVersion(
                      goalId: goalId,
                      targetValue: target,
                      startingValue: snapshot.currentValue ?? snapshot.latestWeightKg,
                      weeklyRate: rate,
                      rationale: rationale.isNotEmpty ? rationale : null,
                    );
                  } else if (selectedAction == 'status_complete') {
                    await goalsRepo.updateGoalStatus(goalId, 'achieved');
                  } else if (selectedAction == 'status_archive') {
                    await goalsRepo.updateGoalStatus(goalId, 'abandoned');
                  }
                  ref.invalidate(dashboardSnapshotProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.goalUpdated),
                        backgroundColor: FormaTheme.successGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.goalUpdateFailed(e.toString())),
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
        content: Text(l10n.signOutConfirmBody),
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
