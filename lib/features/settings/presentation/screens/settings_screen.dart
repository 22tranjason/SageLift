import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/deployment_version_source.dart';
import '../../data/services/google_drive_sync_service.dart';
import '../providers/backup_restore_controller.dart';
import '../providers/deployment_update_controller.dart';

/// Offline backups plus optional private Google Drive sync.
class SettingsScreen extends ConsumerStatefulWidget {
  /// Creates the Settings screen.
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _clientId = TextEditingController();
  bool _driveLoading = true;
  bool _driveBusy = false;
  bool _driveAutoSync = false;
  DateTime? _lastSyncedAt;
  String? _driveMessage;

  @override
  void initState() {
    super.initState();
    _loadDriveSettings();
  }

  @override
  void dispose() {
    _clientId.dispose();
    super.dispose();
  }

  Future<void> _loadDriveSettings() async {
    try {
      final GoogleDriveSyncService service =
          ref.read(googleDriveSyncServiceProvider);
      final String? id = await service.clientId;
      final bool enabled = await service.autoSyncEnabled;
      final DateTime? last = await service.lastSyncedAt;
      if (!mounted) return;
      setState(() {
        _clientId.text = id ?? '';
        _driveAutoSync = enabled;
        _lastSyncedAt = last;
        _driveLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _driveLoading = false;
        _driveMessage = 'Could not read local Drive sync settings.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String buildId = ref.watch(
      deploymentVersionSourceProvider.select(
        (DeploymentVersionSource source) => source.currentBuildId,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Backup SageLift Data'),
            subtitle:
                const Text('Save a JSON copy of data stored on this device'),
            leading: const Icon(Icons.download_outlined),
            onTap: () => _backup(context),
          ),
          ListTile(
            title: const Text('Restore SageLift Data'),
            subtitle:
                const Text('Replace local data from a SageLift JSON backup'),
            leading: const Icon(Icons.upload_file_outlined),
            onTap: () => _restore(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.cloud_upload_outlined),
            title: Text('Private Google Drive sync'),
            subtitle: Text(
              'Optional: keep one latest SageLift JSON backup in your Drive.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _clientId,
              enabled: !_driveLoading && !_driveBusy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Google OAuth web client ID',
                hintText: '123456-abc.apps.googleusercontent.com',
                border: OutlineInputBorder(),
                helperText: 'Create a web OAuth client for this SageLift site.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed:
                      _driveBusy || _driveLoading ? null : _connectAndSync,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(_driveBusy ? 'Syncing…' : 'Connect & Sync now'),
                ),
                OutlinedButton(
                  onPressed: _driveBusy || _driveLoading ? null : _disconnectDrive,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Automatic sync while app is open'),
            subtitle: const Text('Checks every 3 minutes while signed in.'),
            value: _driveAutoSync,
            onChanged: _driveLoading || _driveBusy || _clientId.text.isEmpty
                ? null
                : _toggleAutoSync,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _driveMessage ??
                  (_lastSyncedAt == null
                      ? 'Not synced yet.'
                      : 'Last uploaded: ${_lastSyncedAt!.toLocal().toString().split('.').first}'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Google sign-in is required again after reopening the app or '
              'when your access expires. No background sync runs while the '
              'app is closed. Local workouts and food logs always work offline. '
              'The backup includes all SageLift profiles and stays private '
              'in the Google account you choose.',
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('App Version'),
            trailing: Text(buildId),
          ),
        ],
      ),
    );
  }

  Future<void> _connectAndSync() async {
    // Call authorization directly from this tap so popup blockers allow it.
    setState(() {
      _driveBusy = true;
      _driveMessage = null;
    });
    try {
      final GoogleDriveSyncService service =
          ref.read(googleDriveSyncServiceProvider);
      final bool uploaded =
          await service.connectAndSync(_clientId.text);
      final DateTime? last = await service.lastSyncedAt;
      if (!mounted) return;
      setState(() {
        _lastSyncedAt = last;
        _driveAutoSync = true;
        _driveMessage = uploaded
            ? 'Backup uploaded privately to your Google Drive.'
            : 'Your SageLift records are already up to date.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _driveMessage = error.toString();
      });
    } finally {
      if (mounted) setState(() => _driveBusy = false);
    }
  }

  Future<void> _toggleAutoSync(bool enabled) async {
    try {
      await ref
          .read(googleDriveSyncServiceProvider)
          .setAutoSyncEnabled(enabled);
      if (!mounted) return;
      setState(() => _driveAutoSync = enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _driveMessage = 'Could not update sync preference.');
    }
  }

  Future<void> _disconnectDrive() async {
    try {
      await ref.read(googleDriveSyncServiceProvider).disconnect();
      if (!mounted) return;
      setState(() {
        _clientId.clear();
        _lastSyncedAt = null;
        _driveAutoSync = false;
        _driveMessage = 'Disconnected. Your Drive backup was not deleted.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _driveMessage = 'Could not disconnect Drive.');
    }
  }

  Future<void> _backup(BuildContext context) async {
    try {
      await ref.read(backupRestoreControllerProvider).backup();
      if (!context.mounted) return;
      _showMessage(context, 'Backup download started.');
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Unable to create a backup on this device.');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final String? contents =
          await ref.read(backupRestoreControllerProvider).selectBackup();
      if (contents == null || !context.mounted) return;
      final bool confirmed = await _confirmRestore(context);
      if (!confirmed || !context.mounted) return;
      await ref.read(backupRestoreControllerProvider).restore(contents);
      if (!context.mounted) return;
      _showMessage(context, 'SageLift data restored successfully.');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'Restore failed: $error');
    }
  }

  Future<bool> _confirmRestore(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Replace local data?'),
            content: const Text(
              'Restoring replaces the SageLift data currently stored on this device. '
              'Create a backup first if you need to keep it.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
