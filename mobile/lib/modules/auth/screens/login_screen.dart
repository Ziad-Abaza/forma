import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../notifiers/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authStateProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 24,
              height: 24,
              errorBuilder: (_, _, _) => const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal),
            ),
            const SizedBox(width: 8),
            Text(l10n.appTitle),
          ],
        ),
        actions: [
          TextButton.icon(
            key: const Key('login_language_toggle_button'),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 72,
                          height: 72,
                          cacheWidth: 216,
                          cacheHeight: 216,
                          errorBuilder: (_, _, _) => const Icon(Icons.fitness_center, color: FormaTheme.primaryTeal, size: 72),
                        ),
                      ),
                    ),
                    Text(
                      l10n.login,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: FormaTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.signInSubtitle,
                      style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 28),

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
                      key: const Key('login_email_field'),
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
                    const SizedBox(height: 16),

                    TextFormField(
                      key: const Key('login_password_field'),
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
                    const SizedBox(height: 24),

                    ElevatedButton(
                      key: const Key('login_submit_button'),
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(l10n.login, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),

                    TextButton(
                      key: const Key('goto_register_button'),
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              );
                            },
                      child: Text(
                        l10n.dontHaveAccount,
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
