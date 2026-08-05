import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/deployment_version_source.dart';
import '../providers/backup_restore_controller.dart';
import '../providers/deployment_update_controller.dart';

/// Offers offline backup, restore, and app build information.
class SettingsScreen extends ConsumerWidget {
  /// Creates the Settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onTap: () => _backup(context, ref),
          ),
          ListTile(
            title: const Text('Restore SageLift Data'),
            subtitle:
                const Text('Replace local data from a SageLift JSON backup'),
            leading: const Icon(Icons.upload_file_outlined),
            onTap: () => _restore(context, ref),
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

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(backupRestoreControllerProvider).backup();
      if (!context.mounted) return;
      _showMessage(context, 'Backup download started.');
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context, 'Unable to create a backup on this device.');
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
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
