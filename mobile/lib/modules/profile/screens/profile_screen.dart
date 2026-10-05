import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/repositories/analytics_repository.dart';
import '../repositories/profile_repository.dart';
import '../models/profile_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _heightController;
  late TextEditingController _dobController;
  late TextEditingController _constraintController;
  String _sex = 'unspecified';
  String _activity = 'sedentary';
  String? _experience;
  List<String> _constraints = [];
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
    _dobController = TextEditingController();
    _constraintController = TextEditingController();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _dobController.dispose();
    _constraintController.dispose();
    super.dispose();
  }

  void _saveProfile(AppLocalizations l10n) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final height = double.tryParse(_heightController.text.trim());
    if (height == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            dateOfBirth: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
            heightCm: height,
            sexForCalculation: _sex,
            activityLevel: _activity,
            experienceLevel: _experience,
            constraints: _constraints,
          );
      ref.invalidate(userProfileProvider);
      ref.invalidate(dashboardSnapshotProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profileUpdated),
            backgroundColor: FormaTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addConstraint() {
    final text = _constraintController.text.trim();
    if (text.isEmpty || _constraints.contains(text)) return;
    setState(() {
      _constraints.add(text);
      _constraintController.clear();
    });
  }

  /// Immutable attribute-change history (GET /api/v1/profile/history).
  void _showHistorySheet(AppLocalizations l10n) {
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
                  child: Text(l10n.profileHistory,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<ProfileHistoryItem>>(
                future: ref.read(profileRepositoryProvider).getHistory(),
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: FormaTheme.primaryTeal));
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text('${snap.error}', style: const TextStyle(color: FormaTheme.criticalCrimson)),
                    );
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(l10n.noProfileChanges, style: const TextStyle(color: FormaTheme.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(color: FormaTheme.borderSubtle, height: 1),
                    itemBuilder: (ctx, idx) {
                      final h = items[idx];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_note, color: FormaTheme.textSecondary, size: 20),
                        title: Text(h.attributeName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${h.oldValue ?? '—'} → ${h.newValue ?? '—'}'
                          '${h.effectiveFrom != null ? '\n${h.effectiveFrom!.toLocal().toString().substring(0, 16)}' : ''}'
                          '${h.actor != null ? ' • ${h.actor}' : ''}',
                          style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11),
                        ),
                        isThreeLine: true,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final numeralSystem = ref.watch(numeralSystemProvider);
    final profileAsync = ref.watch(userProfileProvider);

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
                width: 24,
                height: 24,
                cacheWidth: 72,
                cacheHeight: 72,
                errorBuilder: (_, _, _) => const Icon(Icons.person_outline, color: FormaTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Text(l10n.profile),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.profileHistory,
            icon: const Icon(Icons.history),
            onPressed: () => _showHistorySheet(l10n),
          ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: FormaTheme.criticalCrimson, size: 48),
                const SizedBox(height: 12),
                Text(err.toString(), style: const TextStyle(color: FormaTheme.criticalCrimson)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: Text(l10n.retry),
                ),
              ],
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(child: Text(l10n.insufficientTrendData));
            }

            if (!_initialized) {
              _heightController.text = profile.heightCm?.toStringAsFixed(0) ?? '';
              _dobController.text = profile.dateOfBirth;
              _sex = profile.sexForCalculation ?? 'unspecified';
              _activity = profile.activityLevel ?? 'sedentary';
              _experience = profile.experienceLevel;
              _constraints = List.of(profile.constraints);
              _initialized = true;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Overview Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 28,
                                  backgroundColor: FormaTheme.surfaceElevated,
                                  child: Icon(Icons.person, color: FormaTheme.primaryTeal, size: 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.profile,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'DOB: ${formatNumeralString(profile.dateOfBirth, numeralSystem)}',
                                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Metabolic Baseline Glance
                    Consumer(
                      builder: (context, ref, _) {
                        final snapshotAsync = ref.watch(dashboardSnapshotProvider);
                        return snapshotAsync.when(
                          data: (snap) {
                            final bmr = snap.bmr;
                            final tdee = snap.tdee;
                            if (bmr == null && tdee == null) return const SizedBox.shrink();

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.bolt, color: FormaTheme.warningAmber, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            l10n.metabolicSummaryTitle,
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        if (bmr != null)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(l10n.bmrLabel, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${formatNumeralString(bmr.round().toString(), numeralSystem)} kcal',
                                                  style: const TextStyle(color: FormaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (tdee != null)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(l10n.tdeeLabel, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 11)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${formatNumeralString(tdee.round().toString(), numeralSystem)} kcal',
                                                  style: const TextStyle(color: FormaTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Parameters Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.calculationParams,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Date of Birth (drives BMR/TDEE age term)
                            TextFormField(
                              controller: _dobController,
                              decoration: InputDecoration(
                                labelText: l10n.dateOfBirth,
                                prefixIcon: Icon(Icons.cake_outlined, color: FormaTheme.primaryTeal),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return l10n.fillAllFields;
                                final dob = DateTime.tryParse(val.trim());
                                if (dob == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val.trim())) {
                                  return l10n.invalidDobFormat;
                                }
                                final age = DateTime.now().difference(dob).inDays ~/ 365;
                                if (age < 18 || age > 120) return l10n.invalidDobAge;
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Height field
                            TextFormField(
                              key: const Key('profile_height_field'),
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: l10n.heightCmLabel,
                                prefixIcon: const Icon(Icons.height, color: FormaTheme.primaryTeal),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return l10n.fillAllFields;
                                final num = double.tryParse(val.trim());
                                if (num == null || num < 80 || num > 250) {
                                  return l10n.heightValidation;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Biological Sex for calculation
                            DropdownButtonFormField<String>(
                              key: const Key('profile_sex_dropdown'),
                              initialValue: _sex,
                              isExpanded: true,
                              dropdownColor: FormaTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              decoration: InputDecoration(
                                labelText: l10n.sexForCalculation,
                                prefixIcon: Icon(Icons.wc, color: FormaTheme.primaryTeal),
                              ),
                              items: [
                                DropdownMenuItem(value: 'male', child: Text(l10n.sexMale, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'female', child: Text(l10n.sexFemale, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'unspecified', child: Text(l10n.sexUnspecified, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _sex = val);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Activity Level
                            DropdownButtonFormField<String>(
                              key: const Key('profile_activity_dropdown'),
                              initialValue: _activity,
                              isExpanded: true,
                              dropdownColor: FormaTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              decoration: InputDecoration(
                                labelText: l10n.physicalActivityLevel,
                                prefixIcon: Icon(Icons.directions_run, color: FormaTheme.primaryTeal),
                              ),
                              items: [
                                DropdownMenuItem(value: 'sedentary', child: Text(l10n.activitySedentary, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'lightly_active', child: Text(l10n.activityLightly, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'moderately_active', child: Text(l10n.activityModerately, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'very_active', child: Text(l10n.activityVery, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'extra_active', child: Text(l10n.activityExtra, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _activity = val);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Experience Level (feeds assistant context)
                            DropdownButtonFormField<String>(
                              initialValue: _experience,
                              isExpanded: true,
                              dropdownColor: FormaTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(10),
                              decoration: InputDecoration(
                                labelText: l10n.trainingExperience,
                                prefixIcon: Icon(Icons.fitness_center_outlined, color: FormaTheme.primaryTeal),
                              ),
                              items: [
                                DropdownMenuItem(value: 'beginner', child: Text(l10n.experienceBeginner, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'intermediate', child: Text(l10n.experienceIntermediate, overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'advanced', child: Text(l10n.experienceAdvanced, overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _experience = val);
                              },
                            ),
                            const SizedBox(height: 16),

                            // Constraints (injuries/limitations the assistant must respect)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _constraintController,
                                    decoration: InputDecoration(
                                      labelText: l10n.addConstraintHint,
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => _addConstraint(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: FormaTheme.primaryTeal),
                                  onPressed: _addConstraint,
                                ),
                              ],
                            ),
                            if (_constraints.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _constraints
                                    .map((c) => Chip(
                                          label: Text(c, style: const TextStyle(fontSize: 12)),
                                          deleteIcon: const Icon(Icons.close, size: 14),
                                          onDeleted: () => setState(() => _constraints.remove(c)),
                                        ))
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 24),

                            ElevatedButton(
                              key: const Key('profile_save_button'),
                              onPressed: _isSaving ? null : () => _saveProfile(l10n),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : Text(l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
