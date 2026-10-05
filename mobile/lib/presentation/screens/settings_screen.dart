import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/auth/models/session_model.dart';
import '../../modules/auth/notifiers/auth_state.dart';
import '../../modules/auth/repositories/auth_repository.dart';
import '../../modules/ai/models/ai_config_model.dart';
import '../../modules/ai/repositories/ai_config_repository.dart';
import '../../modules/privacy/models/consent_model.dart';
import '../../modules/privacy/repositories/privacy_repository.dart';
import '../../modules/profile/screens/profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'google';
  bool _obscureKey = true;
  bool _isTestingKey = false;
  bool _isSavingKey = false;
  String? _testStatusMessage;
  bool _testSuccess = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final key = _apiKeyController.text.trim();
    setState(() {
      _isTestingKey = true;
      _testStatusMessage = null;
    });

    try {
      final success = await ref.read(aiConfigRepositoryProvider).testConnection(
            provider: _selectedProvider,
            apiKey: key.isNotEmpty ? key : null,
          );
      setState(() {
        _testSuccess = success;
        _testStatusMessage = success
            ? l10n.connectionVerified(_selectedProvider)
            : l10n.connectionFailed;
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testStatusMessage = e.toString().replaceAll('ApiException(400): ', '');
      });
    } finally {
      setState(() => _isTestingKey = false);
    }
  }

  void _saveKey() async {
    final l10n = AppLocalizations.of(context)!;
    final key = _apiKeyController.text.trim();
    if (key.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.apiKeyTooShort),
          backgroundColor: FormaTheme.criticalCrimson,
        ),
      );
      return;
    }

    setState(() => _isSavingKey = true);
    try {
      await ref.read(aiConfigRepositoryProvider).storeCredential(
            provider: _selectedProvider,
            apiKey: key,
          );
      _apiKeyController.clear();
      ref.invalidate(aiConfigProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.apiKeySaved(_selectedProvider)),
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
      if (mounted) setState(() => _isSavingKey = false);
    }
  }

  void _deleteKey(String provider) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(aiConfigRepositoryProvider).deleteCredential(provider);
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.credentialRevoked(provider)),
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
    }
  }

  void _showExportDataDialog(AppLocalizations l10n) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
      ),
    );

    try {
      final data = await ref.read(privacyRepositoryProvider).exportUserData();
      if (mounted) Navigator.of(context).pop(); // dismiss loading

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.exportUserData),
            content: SizedBox(
              width: double.maxFinite,
              height: 320,
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonString,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.exportJsonCopied)),
                  );
                },
                child: Text(l10n.copyJson),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.close),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.exportFailed(e.toString())),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    }
  }

  /// Formats a timestamp for list subtitles; '—' when absent so we never
  /// fabricate a date.
  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '—';
    final s = dt.toLocal().toString();
    return s.length >= 16 ? s.substring(0, 16) : s;
  }

  String _consentPolicyLabel(AppLocalizations l10n, String policyType) {
    switch (policyType) {
      case 'terms_of_service':
        return l10n.consentPolicyTermsOfService;
      case 'health_data_processing':
        return l10n.consentPolicyHealthData;
      case 'ai_third_party_processing':
        return l10n.consentPolicyAiThirdParty;
      default:
        return policyType.isEmpty ? l10n.unknown : policyType;
    }
  }

  Future<void> _revokeSession(SessionInfo session) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      ref.invalidate(sessionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sessionRevokedSuccess),
            backgroundColor: FormaTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sessionActionFailed(formatApiErrorMessage(e))),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    }
  }

  void _confirmSignOutAll(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.signOutAllConfirmTitle),
        content: Text(
          l10n.signOutAllConfirmBody,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(authRepositoryProvider).logoutAll();
                // All sessions revoked server-side — the next authenticated
                // request hits the session-expired path and routes to login.
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.signOutAllSuccess),
                      backgroundColor: FormaTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.sessionActionFailed(formatApiErrorMessage(e))),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.signOutAllDevices, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(AppLocalizations l10n) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool isSubmitting = false;
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.changePassword),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('current_password_field'),
                  controller: currentController,
                  obscureText: obscureCurrent,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    labelText: l10n.currentPasswordLabel,
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('new_password_field'),
                  controller: newController,
                  obscureText: obscureNew,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    labelText: l10n.newPasswordLabel,
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              key: const Key('change_password_submit'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final current = currentController.text;
                      final next = newController.text;
                      if (current.isEmpty || next.isEmpty) {
                        setDialogState(() => errorText = l10n.fillAllFields);
                        return;
                      }
                      if (next.length < 8) {
                        setDialogState(() => errorText = l10n.passwordTooShort);
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      try {
                        final message = await ref.read(authRepositoryProvider).changePassword(
                              currentPassword: current,
                              newPassword: next,
                            );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        // Backend revoked all sessions — the session-expired
                        // path routes to login. Do not navigate manually.
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message ?? l10n.changePasswordSuccessFallback),
                              backgroundColor: FormaTheme.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = l10n.changePasswordFailed(formatApiErrorMessage(e));
                        });
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.changePassword),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _withdrawConsent(ConsentInfo consent) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.consentWithdrawButton),
        content: Text(
          l10n.consentWithdrawConfirm,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.consentWithdrawButton, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(privacyRepositoryProvider).withdrawConsent(consent.policyType);
      ref.invalidate(consentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.consentWithdrawnSuccess),
            backgroundColor: FormaTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.consentWithdrawFailed(formatApiErrorMessage(e))),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    }
  }

  Future<void> _selectAiModel(AIConfigModel config, String modelId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final model = config.selectableModels.where((m) => m.id == modelId).firstOrNull;
      await ref.read(aiConfigRepositoryProvider).updatePreferences(
            preferredModel: modelId,
            // Current backend requires activeProvider — prefer the model's
            // own provider when none is configured yet.
            activeProvider: config.activeProvider ?? model?.provider,
          );
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.aiModelUpdated),
            backgroundColor: FormaTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.aiModelUpdateFailed(formatApiErrorMessage(e))),
            backgroundColor: FormaTheme.criticalCrimson,
          ),
        );
      }
    }
  }

  void _confirmDeleteAccount(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l10n.purgeAccount,
          style: const TextStyle(color: FormaTheme.criticalCrimson),
        ),
        content: Text(
          l10n.purgeConfirmation,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FormaTheme.criticalCrimson),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(privacyRepositoryProvider).purgeAccount();
                await ref.read(authStateProvider.notifier).logout();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.purgeFailed(e.toString())),
                      backgroundColor: FormaTheme.criticalCrimson,
                    ),
                  );
                }
              }
            },
            child: Text(l10n.purgeAccount, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final numeralSystem = ref.watch(numeralSystemProvider);
    final authState = ref.watch(authStateProvider);
    final aiConfigAsync = ref.watch(aiConfigProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final consentsAsync = ref.watch(consentsProvider);

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
                errorBuilder: (_, _, _) => const Icon(Icons.settings, color: FormaTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Text(l10n.settings),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Language & Regional Formats
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.language, color: FormaTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.language,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Language Toggle
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.appLanguageTitle),
                        subtitle: Text(currentLocale.languageCode == 'en' ? 'English (LTR)' : 'العربية (RTL)'),
                        trailing: ElevatedButton(
                          // Language and numeral system are independent
                          // choices — switching language must not override
                          // the user's numeral preference.
                          onPressed: () {
                            if (currentLocale.languageCode == 'en') {
                              updateAppLocale(ref, const Locale('ar'));
                            } else {
                              updateAppLocale(ref, const Locale('en'));
                            }
                          },
                          child: Text(currentLocale.languageCode == 'en' ? 'العربية' : 'English'),
                        ),
                      ),
                      const Divider(color: FormaTheme.borderSubtle),
                      // Numeral System Toggle
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.digitsTitle),
                        subtitle: Text(numeralSystem == 'western' ? l10n.digitsWestern : l10n.digitsEasternArabic),
                        trailing: DropdownButton<String>(
                          value: numeralSystem,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'western', child: Text('1 2 3')),
                            DropdownMenuItem(value: 'eastern_arabic', child: Text('١ ٢ ٣')),
                          ],
                          onChanged: (val) {
                            if (val != null) updateAppNumeralSystem(ref, val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Health Profile Navigation
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline, color: FormaTheme.primaryTeal),
                  title: Text(l10n.profile, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(l10n.healthProfileSubtitle),
                  trailing: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.arrow_back_ios_new
                        : Icons.arrow_forward_ios,
                    size: 16,
                    color: FormaTheme.textSecondary,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // 3. AI Provider & BYOK Configuration (Blueprint §10, §20.5, ADR-018)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_outlined, color: FormaTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.aiProviderConfigTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.aiProviderConfigDescription,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      aiConfigAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
                          ),
                        ),
                        error: (err, _) => Text(
                          l10n.aiConfigLoadError(err.toString()),
                          style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
                        ),
                        data: (config) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Provider selection
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: config.availableProviders.contains(_selectedProvider)
                                    ? _selectedProvider
                                    : config.availableProviders.firstOrNull ?? 'google',
                                decoration: InputDecoration(labelText: l10n.activeAiProvider),
                                items: config.availableProviders.map((p) {
                                  final hasKey = config.hasCredentialFor(p);
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(p.toUpperCase(), overflow: TextOverflow.ellipsis),
                                        ),
                                        if (hasKey) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: FormaTheme.primaryTeal.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('BYOK', style: TextStyle(fontSize: 10, color: FormaTheme.primaryTeal)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() => _selectedProvider = val);
                                    try {
                                      await ref.read(aiConfigRepositoryProvider).updateActiveProvider(val);
                                      ref.invalidate(aiConfigProvider);
                                    } catch (_) {}
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Preferred model picker — only eval-approved
                              // models (falls back to all when none are marked).
                              if (config.selectableModels.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  key: const Key('ai_model_dropdown'),
                                  isExpanded: true,
                                  initialValue: config.selectableModels
                                          .any((m) => m.id == config.preferredModel)
                                      ? config.preferredModel
                                      : null,
                                  decoration: InputDecoration(labelText: l10n.aiModelLabel),
                                  items: config.selectableModels.map((m) {
                                    return DropdownMenuItem(
                                      value: m.id,
                                      child: Text(
                                        m.displayName.isNotEmpty ? m.displayName : m.id,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null && val != config.preferredModel) {
                                      _selectAiModel(config, val);
                                    }
                                  },
                                ),
                              const SizedBox(height: 16),

                              // Active credentials status
                              if (config.credentials.isNotEmpty) ...[
                                Text(
                                  l10n.storedCredentialsTitle,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...config.credentials.map((cred) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(Icons.key, color: FormaTheme.primaryTeal, size: 20),
                                      title: Text(cred.provider.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(l10n.credentialFingerprint(cred.keyFingerprint)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline, color: FormaTheme.alertCoral, size: 20),
                                        onPressed: () => _deleteKey(cred.provider),
                                      ),
                                    )),
                                const SizedBox(height: 12),
                              ],

                              // API Key entry
                              TextFormField(
                                key: const Key('byok_api_key_field'),
                                controller: _apiKeyController,
                                obscureText: _obscureKey,
                                decoration: InputDecoration(
                                  labelText: l10n.enterCustomApiKey(_selectedProvider.toUpperCase()),
                                  prefixIcon: const Icon(Icons.vpn_key_outlined, color: FormaTheme.primaryTeal),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (_testStatusMessage != null) ...[
                                Text(
                                  _testStatusMessage!,
                                  style: TextStyle(
                                    color: _testSuccess ? FormaTheme.successGreen : FormaTheme.criticalCrimson,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    key: const Key('test_ai_connection_button'),
                                    onPressed: _isTestingKey ? null : _testConnection,
                                    icon: const Icon(Icons.network_check, size: 16),
                                    label: _isTestingKey
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Text(l10n.testConnection),
                                  ),
                                  ElevatedButton.icon(
                                    key: const Key('save_ai_key_button'),
                                    onPressed: _isSavingKey ? null : _saveKey,
                                    icon: const Icon(Icons.save, size: 16),
                                    label: _isSavingKey
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                        : Text(l10n.saveKey),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Privacy & Data Ownership (Blueprint §21, J10)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: FormaTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.privacyControls,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.privacyControlsDescription,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Consent & Privacy — live consent records from the backend
                      Text(
                        l10n.consentsTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.consentsSubtitle,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      consentsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
                          ),
                        ),
                        error: (err, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.consentsLoadError(formatApiErrorMessage(err)),
                              style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(consentsProvider),
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                        data: (consents) {
                          if (consents.isEmpty) {
                            return Text(
                              l10n.consentsEmpty,
                              style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                            );
                          }
                          return Column(
                            children: consents.map((consent) {
                              final statusLine = consent.withdrawnAt != null
                                  ? l10n.consentWithdrawnOn(_formatTimestamp(consent.withdrawnAt))
                                  : l10n.consentGrantedOn(_formatTimestamp(consent.grantedAt));
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: Icon(
                                  consent.isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                                  color: consent.isActive ? FormaTheme.successGreen : FormaTheme.textTertiary,
                                  size: 20,
                                ),
                                title: Text(
                                  consent.version != null && consent.version!.isNotEmpty
                                      ? '${_consentPolicyLabel(l10n, consent.policyType)} · ${l10n.consentVersionLabel(consent.version!)}'
                                      : _consentPolicyLabel(l10n, consent.policyType),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                subtitle: Text(
                                  consent.isWithdrawable
                                      ? statusLine
                                      : '$statusLine — ${l10n.consentRequiresDeletion}',
                                  style: const TextStyle(fontSize: 12, color: FormaTheme.textSecondary),
                                ),
                                trailing: (consent.isWithdrawable && consent.isActive)
                                    ? TextButton(
                                        onPressed: () => _withdrawConsent(consent),
                                        child: Text(
                                          l10n.consentWithdrawButton,
                                          style: const TextStyle(color: FormaTheme.alertCoral),
                                        ),
                                      )
                                    : null,
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const Divider(color: FormaTheme.borderSubtle),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined, color: FormaTheme.primaryTeal),
                        title: Text(l10n.exportUserData, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(l10n.exportSubtitle),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: ElevatedButton(
                          key: const Key('settings_export_button'),
                          onPressed: () => _showExportDataDialog(l10n),
                          child: Text(l10n.exportData),
                        ),
                      ),
                      const Divider(color: FormaTheme.borderSubtle),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_forever, color: FormaTheme.criticalCrimson),
                        title: Text(
                          l10n.purgeAccount,
                          style: const TextStyle(color: FormaTheme.criticalCrimson, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(l10n.purgeAccountSubtitle),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: OutlinedButton(
                          key: const Key('settings_delete_account_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FormaTheme.criticalCrimson,
                            side: const BorderSide(color: FormaTheme.criticalCrimson),
                          ),
                          onPressed: () => _confirmDeleteAccount(l10n),
                          child: Text(l10n.deleteAccount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Security & Sessions — password rotation + device management
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_outline, color: FormaTheme.primaryTeal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.securitySectionTitle,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.securitySectionSubtitle,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Change password entry point
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.password_outlined, color: FormaTheme.primaryTeal),
                        title: Text(l10n.changePassword, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(l10n.changePasswordSubtitle),
                        trailing: Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_ios_new
                              : Icons.arrow_forward_ios,
                          size: 16,
                          color: FormaTheme.textSecondary,
                        ),
                        onTap: () => _showChangePasswordDialog(l10n),
                      ),
                      const Divider(color: FormaTheme.borderSubtle),

                      // Signed-in sessions
                      Text(
                        l10n.sessionsListTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      sessionsAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
                          ),
                        ),
                        error: (err, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.sessionsLoadError(formatApiErrorMessage(err)),
                              style: const TextStyle(color: FormaTheme.criticalCrimson, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(sessionsProvider),
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                        data: (sessions) {
                          if (sessions.isEmpty) {
                            return Text(
                              l10n.sessionsEmpty,
                              style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                            );
                          }
                          return Column(
                            children: sessions.map((session) {
                              final revoked = session.isRevoked == true;
                              final deviceSummary = session.deviceSummary;
                              return Opacity(
                                opacity: revoked ? 0.5 : 1.0,
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(
                                    Icons.devices_outlined,
                                    color: revoked ? FormaTheme.textTertiary : FormaTheme.primaryTeal,
                                    size: 20,
                                  ),
                                  title: Text(
                                    deviceSummary.isNotEmpty
                                        ? deviceSummary
                                        : l10n.sessionUnknownDevice,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    l10n.sessionCreatedLabel(_formatTimestamp(session.createdAt)),
                                    style: const TextStyle(fontSize: 12, color: FormaTheme.textSecondary),
                                  ),
                                  trailing: revoked
                                      ? Text(
                                          l10n.sessionRevokedBadge,
                                          style: const TextStyle(color: FormaTheme.textTertiary, fontSize: 12),
                                        )
                                      : TextButton(
                                          onPressed: () => _revokeSession(session),
                                          child: Text(
                                            l10n.revokeSession,
                                            style: const TextStyle(color: FormaTheme.alertCoral),
                                          ),
                                        ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: OutlinedButton.icon(
                          key: const Key('settings_sign_out_all_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FormaTheme.criticalCrimson,
                            side: const BorderSide(color: FormaTheme.criticalCrimson),
                          ),
                          icon: const Icon(Icons.logout, size: 16),
                          onPressed: () => _confirmSignOutAll(l10n),
                          label: Text(l10n.signOutAllDevices),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Account Info & Logout
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.signedInAs, style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  authState.user?.email ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const Key('settings_logout_button'),
                            icon: const Icon(Icons.logout, size: 16),
                            label: Text(l10n.logout),
                            onPressed: () => ref.read(authStateProvider.notifier).logout(),
                          ),
                        ],
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
}
