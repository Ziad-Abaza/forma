import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../analytics/repositories/analytics_repository.dart';
import '../repositories/profile_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _heightController;
  String _sex = 'unspecified';
  String _activity = 'sedentary';
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController();
  }

  @override
  void dispose() {
    _heightController.dispose();
    super.dispose();
  }

  void _saveProfile(AppLocalizations l10n) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final height = double.tryParse(_heightController.text.trim());
    if (height == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            heightCm: height,
            sexForCalculation: _sex,
            activityLevel: _activity,
          );
      ref.invalidate(userProfileProvider);
      ref.invalidate(dashboardSnapshotProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
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
              _heightController.text = profile.heightCm.toStringAsFixed(0);
              _sex = profile.sexForCalculation;
              _activity = profile.activityLevel;
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
                    const SizedBox(height: 20),

                    // Parameters Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculation-Relevant Parameters',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),

                            // Height field
                            TextFormField(
                              key: const Key('profile_height_field'),
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '${l10n.value} (Height in cm)',
                                prefixIcon: const Icon(Icons.height, color: FormaTheme.primaryTeal),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return l10n.fillAllFields;
                                final num = double.tryParse(val.trim());
                                if (num == null || num < 80 || num > 250) {
                                  return 'Enter a valid height between 80 and 250 cm';
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
                              decoration: const InputDecoration(
                                labelText: 'Sex for Calculation',
                                prefixIcon: Icon(Icons.wc, color: FormaTheme.primaryTeal),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'female', child: Text('Female', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'unspecified', child: Text('Unspecified', overflow: TextOverflow.ellipsis)),
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
                              decoration: const InputDecoration(
                                labelText: 'Physical Activity Level',
                                prefixIcon: Icon(Icons.directions_run, color: FormaTheme.primaryTeal),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'sedentary', child: Text('Sedentary (Little/no exercise)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'lightly_active', child: Text('Lightly Active (1-3 days/wk)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'moderately_active', child: Text('Moderately Active (3-5 days/wk)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'very_active', child: Text('Very Active (6-7 days/wk)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'extra_active', child: Text('Extra Active (Hard training)', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _activity = val);
                              },
                            ),
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
