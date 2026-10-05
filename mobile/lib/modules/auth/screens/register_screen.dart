import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../notifiers/auth_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController(text: '1995-01-01');
  final _heightController = TextEditingController(text: '175');

  String _sexForCalculation = 'unspecified';
  bool _termsConsent = false;
  bool _healthConsent = false;
  bool _aiConsent = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool _isUnderage(String dobStr) {
    try {
      final dob = DateTime.parse(dobStr);
      final today = DateTime.now();
      var age = today.year - dob.year;
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
      return age < 18;
    } catch (_) {
      return true;
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = DateTime.tryParse(_dobController.text.trim()) ?? DateTime(1995, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dobController.text = '$y-$m-$d';
      });
    }
  }

  void _submit(AppLocalizations l10n) {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_termsConsent || !_healthConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.consentRequired),
          backgroundColor: FormaTheme.criticalCrimson,
        ),
      );
      return;
    }

    if (_isUnderage(_dobController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.ageGateError),
          backgroundColor: FormaTheme.criticalCrimson,
        ),
      );
      return;
    }

    final height = double.tryParse(_heightController.text.trim()) ?? 175.0;

    ref.read(authStateProvider.notifier).register(
          email: _emailController.text,
          password: _passwordController.text,
          dateOfBirth: _dobController.text.trim(),
          heightCm: height,
          sexForCalculation: _sexForCalculation,
          termsConsent: _termsConsent,
          healthConsent: _healthConsent,
          aiConsent: _aiConsent,
        );
  }

  Widget _buildDropdownSelectedValue(BuildContext context, String text, IconData icon) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FormaTheme.primaryTeal),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: FormaTheme.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenuItem(BuildContext context, String text, IconData icon, bool isSelected) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isSelected ? FormaTheme.primaryTeal : FormaTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: isSelected ? FormaTheme.primaryTeal : FormaTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (isSelected)
          const Icon(
            Icons.check,
            size: 18,
            color: FormaTheme.secondaryMint,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.loading;

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
                errorBuilder: (_, _, _) => const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.register,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: TextButton.icon(
              key: const Key('register_language_toggle_button'),
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
                style: const TextStyle(color: FormaTheme.primaryTeal, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 64,
                          height: 64,
                          cacheWidth: 192,
                          cacheHeight: 192,
                          errorBuilder: (_, _, _) => const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal, size: 64),
                        ),
                      ),
                    ),
                    Text(
                      l10n.register,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: FormaTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tagline,
                      style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),

                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FormaTheme.criticalCrimson.withValues(alpha: 0.15),
                          border: Border.all(color: FormaTheme.criticalCrimson.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: FormaTheme.criticalCrimson, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      key: const Key('register_email_field'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.email,
                        prefixIcon: const Icon(Icons.email_outlined, color: FormaTheme.primaryTeal),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return l10n.fillAllFields;
                        if (!val.contains('@') || !val.contains('.')) return l10n.invalidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      key: const Key('register_password_field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        prefixIcon: const Icon(Icons.lock_outline, color: FormaTheme.primaryTeal),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: FormaTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return l10n.fillAllFields;
                        if (val.length < 8) return l10n.passwordTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      key: const Key('register_dob_field'),
                      controller: _dobController,
                      decoration: InputDecoration(
                        labelText: '${l10n.dateOfBirth} (YYYY-MM-DD)',
                        prefixIcon: const Icon(Icons.calendar_today_outlined, color: FormaTheme.primaryTeal),
                        suffixIcon: IconButton(
                          key: const Key('register_dob_picker_button'),
                          icon: const Icon(Icons.edit_calendar_outlined, color: FormaTheme.primaryTeal),
                          tooltip: l10n.selectDate,
                          onPressed: () => _pickDate(context),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return l10n.fillAllFields;
                        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(val.trim())) {
                          return l10n.invalidDateFormat;
                        }
                        if (_isUnderage(val.trim())) {
                          return l10n.ageGateError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isTwoColumn = constraints.maxWidth >= 500;

                        final heightField = TextFormField(
                          key: const Key('register_height_field'),
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: '${l10n.height} (cm)',
                            prefixIcon: const Icon(Icons.height, color: FormaTheme.primaryTeal),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return l10n.fillAllFields;
                            final n = double.tryParse(val);
                            if (n == null || n < 80 || n > 260) return l10n.invalidHeightRange;
                            return null;
                          },
                        );

                        final sexField = DropdownButtonFormField<String>(
                          key: const Key('register_sex_dropdown'),
                          initialValue: _sexForCalculation,
                          isExpanded: true,
                          dropdownColor: FormaTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          elevation: 4,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: FormaTheme.primaryTeal),
                          decoration: InputDecoration(
                            labelText: l10n.sexForCalculation,
                            prefixIcon: const Icon(Icons.wc, color: FormaTheme.primaryTeal),
                          ),
                          selectedItemBuilder: (BuildContext context) {
                            return [
                              _buildDropdownSelectedValue(context, l10n.sexMale, Icons.male),
                              _buildDropdownSelectedValue(context, l10n.sexFemale, Icons.female),
                              _buildDropdownSelectedValue(context, l10n.sexUnspecified, Icons.person_outline),
                            ];
                          },
                          items: [
                            DropdownMenuItem(
                              value: 'male',
                              child: _buildDropdownMenuItem(context, l10n.sexMale, Icons.male, _sexForCalculation == 'male'),
                            ),
                            DropdownMenuItem(
                              value: 'female',
                              child: _buildDropdownMenuItem(context, l10n.sexFemale, Icons.female, _sexForCalculation == 'female'),
                            ),
                            DropdownMenuItem(
                              value: 'unspecified',
                              child: _buildDropdownMenuItem(context, l10n.sexUnspecified, Icons.person_outline, _sexForCalculation == 'unspecified'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _sexForCalculation = val);
                          },
                        );

                        if (!isTwoColumn) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              heightField,
                              const SizedBox(height: 14),
                              sexField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: heightField),
                            const SizedBox(width: 12),
                            Expanded(child: sexField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Consent Checkboxes
                    CheckboxListTile(
                      key: const Key('consent_terms_checkbox'),
                      value: _termsConsent,
                      onChanged: (val) => setState(() => _termsConsent = val ?? false),
                      title: Text(l10n.termsConsent, style: const TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      key: const Key('consent_health_checkbox'),
                      value: _healthConsent,
                      onChanged: (val) => setState(() => _healthConsent = val ?? false),
                      title: Text(l10n.healthConsent, style: const TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      key: const Key('consent_ai_checkbox'),
                      value: _aiConsent,
                      onChanged: (val) => setState(() => _aiConsent = val ?? true),
                      title: Text(l10n.aiConsent, style: const TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      key: const Key('register_submit_button'),
                      onPressed: isLoading ? null : () => _submit(l10n),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(l10n.register, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      key: const Key('goto_login_button'),
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      child: Text(
                        l10n.alreadyHaveAccount,
                        style: const TextStyle(color: FormaTheme.primaryTeal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
