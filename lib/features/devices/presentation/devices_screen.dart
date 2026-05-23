import 'package:flutter/material.dart';

import '../../../core/sync/multi_device_sync_service.dart';
import '../../../core/sync/sync_state.dart';
import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _syncService = MultiDeviceSyncService();
  var _syncStatus = SyncStatus.idle;
  var _conflictResolutionMode = 'lww'; // 'lww' (Last-Write-Wins) or 'manual'

  final List<Map<String, dynamic>> _trustedDevices = [
    {
      'name': 'Google Pixel 8',
      'type': 'Mobile (Android)',
      'isCurrent': true,
      'lastSynced': 'Just now',
    },
    {
      'name': 'Apple iPad Pro',
      'type': 'Tablet (iOS)',
      'isCurrent': false,
      'lastSynced': '2 hours ago',
    },
    {
      'name': 'MacBook Pro 16"',
      'type': 'Desktop (macOS)',
      'isCurrent': false,
      'lastSynced': 'Yesterday',
    },
  ];

  Future<void> _triggerSync() async {
    setState(() => _syncStatus = SyncStatus.syncing);
    final result = await _syncService.syncNow();
    
    if (!mounted) return;
    
    setState(() {
      _syncStatus = result;
      if (result == SyncStatus.synced) {
        _trustedDevices[0]['lastSynced'] = 'Just now';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              result == SyncStatus.synced ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              result == SyncStatus.synced
                  ? 'Multi-device sync completed successfully!'
                  : 'Sync failed. Local backup active.',
            ),
          ],
        ),
        backgroundColor: result == SyncStatus.synced
            ? AikoColors.successGreen
            : AikoColors.dangerRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AikoColors.appBackgroundLight,
      appBar: AppBar(
        title: const Text('Device Workspace & Sync'),
        actions: [
          IconButton(
            icon: _syncStatus == SyncStatus.syncing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AikoColors.white),
                  )
                : const Icon(Icons.sync),
            onPressed: _syncStatus == SyncStatus.syncing ? null : _triggerSync,
            tooltip: 'Sync Now',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Live Sync Status Card
          FinanceCard(
            title: 'Cloud Sync Status',
            icon: Icons.sync_lock_outlined,
            accentColor: AikoColors.premiumPurple,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Synchronization Channel',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _syncStatus == SyncStatus.syncing
                                    ? AikoColors.warningOrange
                                    : _syncStatus == SyncStatus.synced
                                        ? AikoColors.successGreen
                                        : AikoColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _syncStatus == SyncStatus.syncing
                                  ? 'Syncing changes...'
                                  : _syncStatus == SyncStatus.synced
                                      ? 'Fully Synced with Cloud'
                                      : 'Connected (Idle)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_syncStatus != SyncStatus.syncing)
                      FilledButton.icon(
                        onPressed: _triggerSync,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Sync Now', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AikoColors.premiumPurple,
                        ),
                      )
                    else
                      const OutlinedButton(
                        onPressed: null,
                        child: Text('Syncing...'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trusted Devices List
          FinanceCard(
            title: 'Trusted Devices',
            icon: Icons.devices_outlined,
            accentColor: AikoColors.deepBlue,
            child: Column(
              children: [
                for (final dev in _trustedDevices) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      dev['isCurrent'] as bool
                          ? Icons.phone_android
                          : Icons.tablet_mac_outlined,
                      color: AikoColors.deepBlue,
                    ),
                    title: Row(
                      children: [
                        Text(
                          dev['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (dev['isCurrent'] as bool) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AikoColors.deepBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'This Device',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AikoColors.deepBlue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('${dev['type']} | Last Synced: ${dev['lastSynced']}'),
                    trailing: dev['isCurrent'] as bool
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AikoColors.dangerRed, size: 20),
                            onPressed: () {
                              setState(() {
                                _trustedDevices.remove(dev);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Device session revoked.')),
                              );
                            },
                          ),
                  ),
                  if (dev != _trustedDevices.last) const Divider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CRDT Sync Conflicts Panel
          FinanceCard(
            title: 'Conflict Resolution Settings',
            icon: Icons.sync_problem_outlined,
            accentColor: AikoColors.warningOrange,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose how merge conflicts are handled between multiple offline active sessions.',
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 12),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Last-Write-Wins (Recommended)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Automatic conflict resolution utilizing cryptographic timestamps. Ensures 100% zero-effort data integration.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: 'lww',
                  groupValue: _conflictResolutionMode,
                  activeColor: AikoColors.warningOrange,
                  onChanged: (val) => setState(() => _conflictResolutionMode = val!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Manual Conflict Review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Prompts a manual review overlay where you choose which balance or transaction history to retain.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: 'manual',
                  groupValue: _conflictResolutionMode,
                  activeColor: AikoColors.warningOrange,
                  onChanged: (val) => setState(() => _conflictResolutionMode = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
