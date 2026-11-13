import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/platform/google_drive_sync_port.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/settings/data/services/google_drive_sync_service.dart';
import 'package:sagelift/features/settings/data/services/sagelift_backup_service.dart';

const String _clientId =
    '123456789012-abcdefg.apps.googleusercontent.com';

void main() {
  test('first connection uploads private backup and enables foreground sync',
      () async {
    final _MemoryStore store = _MemoryStore();
    final _FakeDrivePort port = _FakeDrivePort();
    final Map<String, dynamic> data = <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': '2026-11-13T20:00:00Z',
      'workouts': <dynamic>[<String, dynamic>{'reps': 8}],
      'settings': <String, dynamic>{
        'jason.foodLog.v1': '{"entries":[]}',
        'sagelift.drive.clientId': _clientId,
        'sagelift.drive.fileId': 'private-file',
      },
    };
    final GoogleDriveSyncService service = _service(store, port, data);
    expect(await service.connectAndSync(_clientId), isTrue);
    expect(port.authorizations, 1);
    expect(port.uploads, 1);
    expect(port.lastFilename, GoogleDriveSyncService.fileName);
    final Map<String, dynamic> uploaded =
        jsonDecode(port.lastContents!) as Map<String, dynamic>;
    expect(uploaded['workouts'], data['workouts']);
    final Map<String, dynamic> settings =
        uploaded['settings'] as Map<String, dynamic>;
    expect(settings.containsKey('jason.foodLog.v1'), isTrue);
    expect(settings.keys.where((String key) => key.startsWith('sagelift.drive.')),
        isEmpty);
    expect(await service.autoSyncEnabled, isTrue);
    expect(await service.clientId, _clientId);
    expect(await service.lastSyncedAt,
        DateTime.utc(2026, 11, 14, 0, 0, 0));
  });

  test('unchanged foreground sync skips uploads; changed records replace file',
      () async {
    final _MemoryStore store = _MemoryStore();
    final _FakeDrivePort port = _FakeDrivePort();
    final Map<String, dynamic> data = _data();
    final GoogleDriveSyncService service = _service(store, port, data);
    await service.connectAndSync(_clientId);
    await service.syncIfAuthorized();
    expect(port.uploads, 1);
    data['exportedAt'] = '2026-11-14T23:59:59Z';
    await service.syncIfAuthorized();
    expect(port.uploads, 1);
    data['workouts'] = <dynamic>[<String, dynamic>{'reps': 9}];
    await service.syncIfAuthorized();
    expect(port.uploads, 2);
    expect(port.lastFileId, 'drive-file-1');
  });

  test('no automatic upload without current authorisation or opt-in',
      () async {
    final _MemoryStore store = _MemoryStore();
    final _FakeDrivePort port = _FakeDrivePort();
    final GoogleDriveSyncService service = _service(store, port, _data());
    await service.syncIfAuthorized();
    expect(port.uploads, 0);
    await service.connectAndSync(_clientId);
    await service.setAutoSyncEnabled(false);
    await service.syncIfAuthorized();
    expect(port.uploads, 1);
    await service.setAutoSyncEnabled(true);
    port.authorized = false;
    await service.syncIfAuthorized();
    expect(port.uploads, 1);
  });

  test('failed upload does not silently enable sync or report success',
      () async {
    final _MemoryStore store = _MemoryStore();
    final _FakeDrivePort port = _FakeDrivePort()..failUpload = true;
    final GoogleDriveSyncService service = _service(store, port, _data());
    await expectLater(service.connectAndSync(_clientId), throwsStateError);
    expect(await service.autoSyncEnabled, isFalse);
    expect(await service.lastSyncedAt, isNull);
    expect(await store.read<String>('sagelift.drive.fileId'), isNull);
  });

  test('disconnect forgets credential and metadata but retains other data',
      () async {
    final _MemoryStore store = _MemoryStore();
    await store.write<String>('jason.foodLog.v1', 'keep');
    final _FakeDrivePort port = _FakeDrivePort();
    final GoogleDriveSyncService service = _service(store, port, _data());
    await service.connectAndSync(_clientId);
    await service.disconnect();
    expect(port.authorized, isFalse);
    expect(await service.clientId, isNull);
    expect(await service.autoSyncEnabled, isFalse);
    expect(await service.lastSyncedAt, isNull);
    expect(await store.read<String>('jason.foodLog.v1'), 'keep');
  });

  test('rejects invalid OAuth client ID before contacting Google', () async {
    final _FakeDrivePort port = _FakeDrivePort();
    final GoogleDriveSyncService service =
        _service(_MemoryStore(), port, _data());
    await expectLater(
        service.connectAndSync('not-an-oauth-client'), throwsFormatException);
    expect(port.authorizations, 0);
  });
}

Map<String, dynamic> _data() => <String, dynamic>{
      'schemaVersion': 1,
      'exportedAt': '2026-11-13T20:00:00Z',
      'workouts': <dynamic>[<String, dynamic>{'reps': 8}],
      'settings': <String, dynamic>{'jason.foodLog.v1': '{"entries":[]}'},
    };

GoogleDriveSyncService _service(
  _MemoryStore store,
  _FakeDrivePort port,
  Map<String, dynamic> data,
) =>
    GoogleDriveSyncService(
      store: store,
      createBackup: () => SageLiftBackup(
        filename: 'local-backup.json',
        contents: jsonEncode(data),
      ),
      port: port,
      now: () => DateTime.utc(2026, 11, 14),
    );

class _FakeDrivePort implements GoogleDriveSyncPort {
  bool authorized = false;
  bool failUpload = false;
  int authorizations = 0;
  int uploads = 0;
  String? lastFilename;
  String? lastContents;
  String? lastFileId;

  @override
  bool get isAuthorized => authorized;

  @override
  Future<void> authorize(String clientId) async {
    authorizations++;
    authorized = true;
  }

  @override
  Future<String> uploadBackup({
    required String filename,
    required String contents,
    String? fileId,
  }) async {
    uploads++;
    if (failUpload) throw StateError('Offline');
    lastFilename = filename;
    lastContents = contents;
    lastFileId = fileId;
    return fileId ?? 'drive-file-1';
  }

  @override
  void disconnect() {
    authorized = false;
  }
}

class _MemoryStore implements KeyValueStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<T?> read<T>(String key) async => _values[key] as T?;

  @override
  Future<void> write<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
