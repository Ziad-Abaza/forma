import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../modules/auth/notifiers/auth_state.dart';
import '../../modules/ai/repositories/ai_config_repository.dart';
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
            ? 'Connection to $_selectedProvider verified successfully'
            : 'Connection test failed';
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
    final key = _apiKeyController.text.trim();
    if (key.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key must be at least 8 characters long'),
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
            content: Text('API key securely encrypted and stored for $_selectedProvider'),
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
    try {
      await ref.read(aiConfigRepositoryProvider).deleteCredential(provider);
      ref.invalidate(aiConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Credential for $provider revoked and erased'),
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
                    const SnackBar(content: Text('Export JSON copied to clipboard')),
                  );
                },
                child: const Text('Copy JSON'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
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
            content: Text('Export failed: $e'),
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
                      content: Text('Account purge failed: $e'),
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
                          Text(
                            l10n.language,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Language Toggle
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('App Language / لغة التطبيق'),
                        subtitle: Text(currentLocale.languageCode == 'en' ? 'English (LTR)' : 'العربية (RTL)'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            if (currentLocale.languageCode == 'en') {
                              updateAppLocale(ref, const Locale('ar'));
                              updateAppNumeralSystem(ref, 'eastern_arabic');
                            } else {
                              updateAppLocale(ref, const Locale('en'));
                              updateAppNumeralSystem(ref, 'western');
                            }
                          },
                          child: Text(currentLocale.languageCode == 'en' ? 'العربية' : 'English'),
                        ),
                      ),
                      const Divider(color: FormaTheme.borderSubtle),
                      // Numeral System Toggle
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Digits / الأرقام'),
                        subtitle: Text(numeralSystem == 'western' ? 'Western (1, 2, 3)' : 'Eastern Arabic (١، ٢، ٣)'),
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
                  subtitle: const Text('Height, age, biological sex, activity level'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FormaTheme.textSecondary),
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
                          const Text(
                            'AI Companion & Provider Configuration',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Configure system models or bring your own API key (BYOK) stored under client-side write-only encryption.',
                        style: TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
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
                          'Unable to load AI config: $err',
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
                                decoration: const InputDecoration(labelText: 'Active AI Provider'),
                                items: config.availableProviders.map((p) {
                                  final hasKey = config.hasCredentialFor(p);
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Row(
                                      children: [
                                        Text(p.toUpperCase()),
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
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedProvider = val);
                                },
                              ),
                              const SizedBox(height: 16),

                              // Active credentials status
                              if (config.credentials.isNotEmpty) ...[
                                const Text(
                                  'Stored Provider Credentials (Encrypted):',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...config.credentials.map((cred) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      leading: const Icon(Icons.key, color: FormaTheme.primaryTeal, size: 20),
                                      title: Text(cred.provider.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('Fingerprint: ${cred.keyFingerprint} (AES-256-GCM)'),
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
                                  labelText: 'Enter Custom API Key for ${_selectedProvider.toUpperCase()}',
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

                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    key: const Key('test_ai_connection_button'),
                                    onPressed: _isTestingKey ? null : _testConnection,
                                    icon: const Icon(Icons.network_check, size: 16),
                                    label: _isTestingKey
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Text('Test Connection'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    key: const Key('save_ai_key_button'),
                                    onPressed: _isSavingKey ? null : _saveKey,
                                    icon: const Icon(Icons.save, size: 16),
                                    label: _isSavingKey
                                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                        : const Text('Save Key'),
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
                          Text(
                            l10n.privacyControls,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.privacyControlsDescription,
                        style: const TextStyle(color: FormaTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_outlined, color: FormaTheme.primaryTeal),
                        title: Text(l10n.exportUserData, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Machine-readable portable JSON format'),
                        trailing: ElevatedButton(
                          key: const Key('settings_export_button'),
                          onPressed: () => _showExportDataDialog(l10n),
                          child: Text(l10n.exportUserData),
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
                        subtitle: const Text('Irreversibly purge all personal records, models and media'),
                        trailing: OutlinedButton(
                          key: const Key('settings_delete_account_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FormaTheme.criticalCrimson,
                            side: const BorderSide(color: FormaTheme.criticalCrimson),
                          ),
                          onPressed: () => _confirmDeleteAccount(l10n),
                          child: Text(l10n.purgeAccount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Account Info & Logout
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
                                const Text('Signed In As', style: TextStyle(color: FormaTheme.textSecondary, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  authState.user?.email ?? 'user@forma.local',
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
