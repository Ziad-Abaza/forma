import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';

class DeviceIntegration {
  final String id;
  final String nameKey;
  final IconData icon;
  final bool isConnected;
  final String? lastSynced;
  final bool isSyncing;

  const DeviceIntegration({
    required this.id,
    required this.nameKey,
    required this.icon,
    required this.isConnected,
    this.lastSynced,
    this.isSyncing = false,
  });

  DeviceIntegration copyWith({
    bool? isConnected,
    String? lastSynced,
    bool? isSyncing,
  }) {
    return DeviceIntegration(
      id: id,
      nameKey: nameKey,
      icon: icon,
      isConnected: isConnected ?? this.isConnected,
      lastSynced: lastSynced ?? this.lastSynced,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final deviceIntegrationsProvider = StateNotifierProvider<DeviceIntegrationsNotifier, List<DeviceIntegration>>((ref) {
  return DeviceIntegrationsNotifier();
});

class DeviceIntegrationsNotifier extends StateNotifier<List<DeviceIntegration>> {
  DeviceIntegrationsNotifier()
      : super([
          const DeviceIntegration(
            id: 'health_connect',
            nameKey: 'healthConnect',
            icon: Icons.favorite_border,
            isConnected: true,
            lastSynced: '10 mins ago',
          ),
          const DeviceIntegration(
            id: 'apple_health',
            nameKey: 'appleHealth',
            icon: Icons.apple,
            isConnected: false,
          ),
          const DeviceIntegration(
            id: 'garmin',
            nameKey: 'garmin',
            icon: Icons.watch,
            isConnected: false,
          ),
          const DeviceIntegration(
            id: 'withings',
            nameKey: 'withings',
            icon: Icons.monitor_weight_outlined,
            isConnected: false,
          ),
          const DeviceIntegration(
            id: 'oura',
            nameKey: 'oura',
            icon: Icons.circle_outlined,
            isConnected: false,
          ),
        ]);

  void toggleConnection(String id) {
    state = state.map((device) {
      if (device.id == id) {
        final nowConnected = !device.isConnected;
        return device.copyWith(
          isConnected: nowConnected,
          lastSynced: nowConnected ? 'Just now' : null,
          isSyncing: false,
        );
      }
      return device;
    }).toList();
  }

  Future<void> syncDevice(String id) async {
    state = state.map((device) {
      if (device.id == id) {
        return device.copyWith(isSyncing: true);
      }
      return device;
    }).toList();

    await Future.delayed(const Duration(milliseconds: 600));

    state = state.map((device) {
      if (device.id == id) {
        return device.copyWith(isSyncing: false, lastSynced: 'Just now');
      }
      return device;
    }).toList();
  }
}

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  String _getDeviceDisplayName(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'healthConnect':
        return l10n.healthConnect;
      case 'appleHealth':
        return l10n.appleHealth;
      case 'garmin':
        return l10n.garmin;
      case 'withings':
        return l10n.withings;
      case 'oura':
        return l10n.oura;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final devices = ref.watch(deviceIntegrationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.syncScreenTitle),
        actions: [
          IconButton(
            key: const Key('sync_all_button'),
            tooltip: l10n.syncNow,
            icon: const Icon(Icons.sync),
            onPressed: () {
              for (final d in devices) {
                if (d.isConnected) {
                  ref.read(deviceIntegrationsProvider.notifier).syncDevice(d.id);
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.syncing)),
              );
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

          // 2. Connected Devices List
          ...devices.map((device) {
            final displayName = _getDeviceDisplayName(context, device.nameKey);
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: device.isConnected
                            ? FormaTheme.primaryTeal.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        device.icon,
                        color: device.isConnected
                            ? FormaTheme.primaryTeal
                            : FormaTheme.textSecondary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: FormaTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
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
                              Text(
                                device.isConnected
                                    ? l10n.connectedStatus
                                    : l10n.disconnectedStatus,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: device.isConnected
                                      ? FormaTheme.primaryTeal
                                      : FormaTheme.textSecondary,
                                ),
                              ),
                              if (device.isConnected && device.lastSynced != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  l10n.lastSynced(device.lastSynced!),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: FormaTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (device.isConnected) ...[
                      IconButton(
                        key: Key('sync_button_${device.id}'),
                        tooltip: l10n.syncNow,
                        icon: device.isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 20, color: FormaTheme.primaryTeal),
                        onPressed: device.isSyncing
                            ? null
                            : () => ref.read(deviceIntegrationsProvider.notifier).syncDevice(device.id),
                      ),
                    ],
                    OutlinedButton(
                      key: Key('toggle_button_${device.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: device.isConnected ? Colors.redAccent : FormaTheme.primaryTeal,
                        side: BorderSide(
                          color: device.isConnected ? Colors.redAccent : FormaTheme.primaryTeal,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ref.read(deviceIntegrationsProvider.notifier).toggleConnection(device.id);
                      },
                      child: Text(
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
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.actionConfirmed),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
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
