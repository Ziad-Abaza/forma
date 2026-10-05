import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../modules/privacy/repositories/privacy_repository.dart';
import '../../modules/integrations/repositories/integrations_repository.dart';
import '../../modules/auth/notifiers/auth_state.dart';

class DeviceIntegration {
  final String id;
  final IconData icon;
  final bool isConnected;
  final DateTime? lastSyncedAt;
  final bool isSyncing;
  final bool isToggling;

  const DeviceIntegration({
    required this.id,
    required this.icon,
    required this.isConnected,
    this.lastSyncedAt,
    this.isSyncing = false,
    this.isToggling = false,
  });

  DeviceIntegration copyWith({
    bool? isConnected,
    DateTime? lastSyncedAt,
    bool clearLastSynced = false,
    bool? isSyncing,
    bool? isToggling,
  }) {
    return DeviceIntegration(
      id: id,
      icon: icon,
      isConnected: isConnected ?? this.isConnected,
      lastSyncedAt: clearLastSynced ? null : (lastSyncedAt ?? this.lastSyncedAt),
      isSyncing: isSyncing ?? this.isSyncing,
      isToggling: isToggling ?? this.isToggling,
    );
  }
}

class DeviceIntegrationsState {
  final List<DeviceIntegration> devices;
  final bool isLoading;
  final Object? loadError;

  const DeviceIntegrationsState({
    this.devices = const [],
    this.isLoading = false,
    this.loadError,
  });

  DeviceIntegrationsState copyWith({
    List<DeviceIntegration>? devices,
    bool? isLoading,
    Object? loadError,
    bool clearLoadError = false,
  }) {
    return DeviceIntegrationsState(
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
    );
  }
}

final deviceIntegrationsProvider =
    StateNotifierProvider<DeviceIntegrationsNotifier, DeviceIntegrationsState>((ref) {
  final isAuth = ref.watch(authStateProvider).isAuthenticated;
  final repository = isAuth ? ref.watch(integrationsRepositoryProvider) : null;
  return DeviceIntegrationsNotifier(repository: repository);
});

class DeviceIntegrationsNotifier extends StateNotifier<DeviceIntegrationsState> {
  final IntegrationsRepository? repository;

  DeviceIntegrationsNotifier({this.repository})
      : super(const DeviceIntegrationsState(isLoading: true)) {
    unawaited(loadConnections());
  }

  static const Map<String, IconData> _providerIcons = {
    'health_connect': Icons.favorite_border,
    'apple_health': Icons.apple,
    'garmin': Icons.watch,
    'withings': Icons.monitor_weight_outlined,
    'oura': Icons.circle_outlined,
    'fitbit': Icons.fitness_center,
  };

  Future<void> loadConnections() async {
    final repo = repository;
    if (repo == null) {
      state = const DeviceIntegrationsState();
      return;
    }

    state = state.copyWith(isLoading: true, clearLoadError: true);
    try {
      // Provider catalog and connection state are both server-issued.
      final providers = await repo.getProviders();
      final connections = await repo.getConnections();
      final byProvider = {for (final c in connections) c.provider: c};

      if (!mounted) return;
      state = DeviceIntegrationsState(
        devices: [
          for (final provider in providers)
            DeviceIntegration(
              id: provider,
              icon: _providerIcons[provider] ?? Icons.devices_other,
              isConnected: byProvider[provider]?.isConnected ?? false,
              lastSyncedAt: byProvider[provider]?.lastSyncedAt != null
                  ? DateTime.tryParse(byProvider[provider]!.lastSyncedAt!)
                  : null,
            ),
        ],
      );
    } catch (e) {
      if (mounted) {
        state = DeviceIntegrationsState(devices: const [], loadError: e);
      }
    }
  }

  /// Returns true only when the backend confirmed the state change.
  Future<bool> toggleConnection(String id) async {
    final repo = repository;
    if (repo == null) return false;

    final current = state.devices.where((d) => d.id == id).firstOrNull;
    if (current == null || current.isToggling) return false;

    _updateDevice(id, (d) => d.copyWith(isToggling: true));
    try {
      if (current.isConnected) {
        await repo.disconnectProvider(id);
      } else {
        await repo.connectProvider(id);
      }
      // Reflect the server's view of the world after a confirmed change.
      await loadConnections();
      return true;
    } catch (_) {
      _updateDevice(id, (d) => d.copyWith(isToggling: false));
      return false;
    }
  }

  /// Returns true only when the backend confirmed the sync completed.
  Future<bool> syncDevice(String id) async {
    final repo = repository;
    if (repo == null) return false;

    _updateDevice(id, (d) => d.copyWith(isSyncing: true));
    try {
      // No device bridge is installed yet — sync pushes only real records.
      await repo.syncProvider(id, records: const []);
      await loadConnections();
      return true;
    } catch (_) {
      _updateDevice(id, (d) => d.copyWith(isSyncing: false));
      return false;
    }
  }

  void _updateDevice(String id, DeviceIntegration Function(DeviceIntegration) update) {
    if (!mounted) return;
    state = state.copyWith(
      devices: [
        for (final d in state.devices) d.id == id ? update(d) : d,
      ],
    );
  }
}

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  String _getDeviceDisplayName(BuildContext context, String provider) {
    final l10n = AppLocalizations.of(context)!;
    switch (provider) {
      case 'health_connect':
        return l10n.healthConnect;
      case 'apple_health':
        return l10n.appleHealth;
      case 'garmin':
        return l10n.garmin;
      case 'withings':
        return l10n.withings;
      case 'oura':
        return l10n.oura;
      case 'fitbit':
        return l10n.fitbit;
      default:
        return provider;
    }
  }

  String _formatSyncedAt(BuildContext context, DateTime value) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final integrationsState = ref.watch(deviceIntegrationsProvider);
    final devices = integrationsState.devices;

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
                errorBuilder: (_, _, _) => const Icon(Icons.sync, color: FormaTheme.primaryTeal),
              ),
              const SizedBox(width: 8),
              Text(l10n.syncScreenTitle),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('sync_all_button'),
            tooltip: l10n.syncNow,
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final notifier = ref.read(deviceIntegrationsProvider.notifier);
              var failures = 0;
              for (final d in devices) {
                if (d.isConnected) {
                  final ok = await notifier.syncDevice(d.id);
                  if (!ok) failures++;
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      failures == 0 ? l10n.syncing : l10n.syncFailed,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Epistemic Precedence & Conflict Resolution Card
          Card(
            color: FormaTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: FormaTheme.primaryTeal.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: FormaTheme.primaryTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.epistemicResolutionHeader,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: FormaTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.epistemicResolutionDesc,
                    style: const TextStyle(
                      fontSize: 13,
                      color: FormaTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Connected Devices List — server-driven state only
          if (integrationsState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (integrationsState.loadError != null)
            Card(
              color: FormaTheme.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      l10n.integrationsLoadError,
                      style: const TextStyle(color: FormaTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: const Key('integrations_retry_button'),
                      onPressed: () => ref
                          .read(deviceIntegrationsProvider.notifier)
                          .loadConnections(),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          else if (devices.isEmpty)
            Card(
              color: FormaTheme.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.noIntegrationsAvailable,
                  style: const TextStyle(color: FormaTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...devices.map((device) {
              final displayName = _getDeviceDisplayName(context, device.id);
              return Card(
                key: Key('device_card_${device.id}'),
                margin: const EdgeInsets.only(bottom: 12),
                color: FormaTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: device.isConnected
                        ? FormaTheme.primaryTeal.withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: device.isConnected
                              ? FormaTheme.primaryTeal.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          device.icon,
                          color: device.isConnected
                              ? FormaTheme.primaryTeal
                              : FormaTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: FormaTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: device.isConnected
                                            ? FormaTheme.primaryTeal
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        device.isConnected
                                            ? l10n.connectedStatus
                                            : l10n.disconnectedStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: device.isConnected
                                              ? FormaTheme.primaryTeal
                                              : FormaTheme.textSecondary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (device.isConnected && device.lastSyncedAt != null)
                                  Text(
                                    l10n.lastSynced(_formatSyncedAt(context, device.lastSyncedAt!)),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: FormaTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (device.isConnected) ...[
                        IconButton(
                          key: Key('sync_button_${device.id}'),
                          tooltip: l10n.syncNow,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: const EdgeInsets.all(4),
                          icon: device.isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 18, color: FormaTheme.primaryTeal),
                          onPressed: device.isSyncing
                              ? null
                              : () async {
                                  final ok = await ref
                                      .read(deviceIntegrationsProvider.notifier)
                                      .syncDevice(device.id);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.syncFailed)),
                                    );
                                  }
                                },
                        ),
                      ],
                      OutlinedButton(
                        key: Key('toggle_button_${device.id}'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor:
                              device.isConnected ? Colors.redAccent : FormaTheme.primaryTeal,
                          side: BorderSide(
                            color: device.isConnected ? Colors.redAccent : FormaTheme.primaryTeal,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        onPressed: device.isToggling
                            ? null
                            : () async {
                                final ok = await ref
                                    .read(deviceIntegrationsProvider.notifier)
                                    .toggleConnection(device.id);
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.connectionUpdateFailed)),
                                  );
                                }
                              },
                        child: device.isToggling
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                device.isConnected ? l10n.disconnect : l10n.connect,
                                style: const TextStyle(fontSize: 12),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          // 3. Privacy & Data Rights Section (Blueprint §32 Invariant 6, §31.1 Gate 7)
          Text(
            l10n.privacyDataSection,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: FormaTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            color: FormaTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    key: const Key('export_data_tile'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_download_outlined, color: FormaTheme.primaryTeal),
                    title: Text(
                      l10n.exportUserData,
                      style: const TextStyle(color: FormaTheme.textPrimary, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: FormaTheme.textSecondary),
                    onTap: () {
                      final isAuth = ref.read(authStateProvider).isAuthenticated;
                      if (isAuth) {
                        ref.read(privacyRepositoryProvider).exportUserData().catchError((_) => <String, dynamic>{});
                      }
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.exportUserData),
                          content: Text(l10n.exportSuccess),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.save),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    key: const Key('purge_account_tile'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                    title: Text(
                      l10n.purgeAccount,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: FormaTheme.textSecondary),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.purgeAccount),
                          content: Text(l10n.purgeConfirmation),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.cancel),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.actionConfirmed),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                final isAuth = ref.read(authStateProvider).isAuthenticated;
                                if (isAuth) {
                                  try {
                                    await ref.read(privacyRepositoryProvider).purgeAccount();
                                    await ref.read(authStateProvider.notifier).logout();
                                  } catch (_) {}
                                }
                              },
                              child: Text(l10n.confirmAction),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
