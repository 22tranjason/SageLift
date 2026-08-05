import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/json_file_port.dart';
import '../../data/services/sagelift_backup_service.dart';

/// Provides the local data backup implementation at the app composition root.
final Provider<SageLiftBackupService> sageLiftBackupServiceProvider =
    Provider<SageLiftBackupService>((Ref ref) {
  throw UnimplementedError(
      'SageLiftBackupService must be provided at startup.');
});

/// Provides browser-safe download and file selection operations.
final Provider<JsonFilePort> jsonFilePortProvider = Provider<JsonFilePort>(
  (Ref ref) => createJsonFilePort(),
);

/// Coordinates backup download and validated restore without leaking I/O into widgets.
class BackupRestoreController {
  /// Creates the settings presentation controller.
  const BackupRestoreController({
    required SageLiftBackupService backupService,
    required JsonFilePort filePort,
  })  : _backupService = backupService,
        _filePort = filePort;

  final SageLiftBackupService _backupService;
  final JsonFilePort _filePort;

  /// Builds and downloads a complete local-data backup file.
  Future<void> backup() {
    final SageLiftBackup backup = _backupService.createBackup();
    return _filePort.downloadJson(
      filename: backup.filename,
      contents: backup.contents,
    );
  }

  /// Lets the user select a JSON backup, or returns null when selection is cancelled.
  Future<String?> selectBackup() => _filePort.pickJson();

  /// Validates and restores selected [contents] after the user has confirmed.
  Future<void> restore(String contents) => _backupService.restore(contents);
}

/// Exposes backup actions to the Settings screen.
final Provider<BackupRestoreController> backupRestoreControllerProvider =
    Provider<BackupRestoreController>((Ref ref) {
  return BackupRestoreController(
    backupService: ref.watch(sageLiftBackupServiceProvider),
    filePort: ref.watch(jsonFilePortProvider),
  );
});
