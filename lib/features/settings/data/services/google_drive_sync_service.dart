import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/google_drive_sync_port.dart';
import '../../../../core/storage/key_value_store.dart';
import '../../presentation/providers/backup_restore_controller.dart';
import 'sagelift_backup_service.dart';

/// Owns opt-in private cloud uploads; local records are always authoritative.
class GoogleDriveSyncService {
  /// Injected boundaries make sync fully testable without Google or a browser.
  GoogleDriveSyncService({
    required KeyValueStore store,
    required SageLiftBackup Function() createBackup,
    required GoogleDriveSyncPort port,
    DateTime Function()? now,
  })  : _store = store,
        _createBackup = createBackup,
        _port = port,
        _now = now ?? DateTime.now;

  /// Friendly name of the single cloud backup file.
  /// Stable filename to make one backup easy to locate in Drive.
  static const String fileName = 'SageLift - Latest Backup.json';
  static const String _prefix = 'sagelift.drive.';
  static const String _clientIdKey = '${_prefix}clientId';
  static const String _enabledKey = '${_prefix}autoSync';
  static const String _fileIdKey = '${_prefix}fileId';
  static const String _lastSyncedKey = '${_prefix}lastSyncedAt';

  final KeyValueStore _store;
  final SageLiftBackup Function() _createBackup;
  final GoogleDriveSyncPort _port;
  final DateTime Function() _now;
  String? _lastSnapshot;
  bool _busy = false;

  /// Google authorisation is session-only: never persist access tokens.
  bool get isAuthorized => _port.isAuthorized;

  /// Reads the locally saved (public) OAuth client identifier.
  Future<String?> get clientId => _store.read<String>(_clientIdKey);

  /// Auto-sync runs only while the web app is open with valid authorisation.
  Future<bool> get autoSyncEnabled async =>
      await _store.read<bool>(_enabledKey) ?? false;

  /// Timestamp of the last successful upload, if known.
  Future<DateTime?> get lastSyncedAt async {
    final String? value = await _store.read<String>(_lastSyncedKey);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// A tap-initiated sign-in, followed by an initial upload.
  Future<bool> connectAndSync(String inputClientId) async {
    final String id = inputClientId.trim();
    if (!RegExp(r'^[0-9]+-[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$')
        .hasMatch(id)) {
      throw const FormatException('Enter a Google OAuth web client ID.');
    }

    // This call must start inside the button gesture for popup blockers.
    await _port.authorize(id);
    await _store.write<String>(_clientIdKey, id);
    final bool uploaded = await _sync();
    await _store.write<bool>(_enabledKey, true);
    return uploaded;
  }

  /// User-requested upload; requires a new tap to reauthorise if expired.
  Future<bool> syncNow(String inputClientId) =>
      connectAndSync(inputClientId);

  /// Runs opportunistically in the foreground; never opens a sign-in popup.
  Future<void> syncIfAuthorized() async {
    if (_busy || !_port.isAuthorized || !(await autoSyncEnabled)) return;
    try {
      await _sync();
    } catch (_) {
      // Local logging continues unaffected; manual Sync reports failures.
    }
  }

  /// Enables or disables periodic uploads without changing local records.
  /// Changes the opt-in foreground sync preference without uploading.
  Future<void> setAutoSyncEnabled(bool value) =>
      _store.write<bool>(_enabledKey, value);

  /// Disconnects this browser without deleting cloud data or local workouts.
  Future<void> disconnect() async {
    _port.disconnect();
    _lastSnapshot = null;
    await _store.delete(_clientIdKey);
    await _store.delete(_fileIdKey);
    await _store.delete(_lastSyncedKey);
    await _store.write<bool>(_enabledKey, false);
  }

  Future<bool> _sync() async {
    if (_busy) throw StateError('A Google Drive sync is already running.');
    _busy = true;
    try {
      final SageLiftBackup backup = _createBackup();
      final Map<String, dynamic> json =
          jsonDecode(backup.contents) as Map<String, dynamic>;
      final Map<String, dynamic> settings =
          Map<String, dynamic>.from(json['settings'] as Map);
      settings.removeWhere((String key, dynamic value) =>
          key.startsWith(_prefix));
      json['settings'] = settings;

      // exportedAt and cloud metadata change without a workout changing.
      final Map<String, dynamic> comparison =
          Map<String, dynamic>.from(json)..remove('exportedAt');
      final String snapshot = jsonEncode(comparison);
      final String? fileId = await _store.read<String>(_fileIdKey);
      if (_lastSnapshot == snapshot && fileId != null) return false;

      final String uploadedId = await _port.uploadBackup(
        filename: fileName,
        contents: const JsonEncoder.withIndent('  ').convert(json),
        fileId: fileId,
      );
      if (uploadedId.isEmpty) {
        throw StateError('Google Drive did not return a file ID.');
      }
      await _store.write<String>(_fileIdKey, uploadedId);
      await _store.write<String>(
        _lastSyncedKey,
        _now().toUtc().toIso8601String(),
      );
      _lastSnapshot = snapshot;
      return true;
    } finally {
      _busy = false;
    }
  }
}

/// One long-lived service instance is shared by Settings and foreground sync.
final Provider<GoogleDriveSyncPort> googleDriveSyncPortProvider =
    Provider<GoogleDriveSyncPort>(
  (Ref ref) => createGoogleDriveSyncPort(),
);

/// Uses the existing complete, versioned SageLift JSON backup.
final Provider<GoogleDriveSyncService> googleDriveSyncServiceProvider =
    Provider<GoogleDriveSyncService>((Ref ref) {
  return GoogleDriveSyncService(
    store: ref.watch(keyValueStoreProvider),
    createBackup: () => ref.read(sageLiftBackupServiceProvider).createBackup(),
    port: ref.watch(googleDriveSyncPortProvider),
  );
});
