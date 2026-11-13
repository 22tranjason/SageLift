// Google Identity Services and Google Drive REST are browser-only.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'dart:js' as js;
import 'dart:js_util' as js_util;

/// Browser Google Drive API adapter; no OAuth tokens are persisted.
abstract interface class GoogleDriveSyncPort {
  /// True only while the short-lived Google token is still usable.
  bool get isAuthorized;

  /// Asks for consent via Google's official account chooser.
  Future<void> authorize(String clientId);

  /// Uploads a single private JSON file or replaces its existing contents.
  Future<String> uploadBackup({
    required String filename,
    required String contents,
    String? fileId,
  });

  /// Clears the access token held only in this browser tab.
  void disconnect();
}

/// Uses Google's restricted-to-app-created-files drive.file permission.
GoogleDriveSyncPort createGoogleDriveSyncPort() => _WebGoogleDriveSyncPort();

class _WebGoogleDriveSyncPort implements GoogleDriveSyncPort {
  static const String _scope = 'https://www.googleapis.com/auth/drive.file';
  String? _token;
  DateTime? _expiresAt;

  @override
  bool get isAuthorized =>
      _token != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  @override
  Future<void> authorize(String clientId) {
    if (!js_util.hasProperty(window, 'google')) {
      return Future<void>.error(
        StateError('Google sign-in is still loading. Try again shortly.'),
      );
    }

    final Completer<void> pending = Completer<void>();
    try {
      final dynamic google = js_util.getProperty(window, 'google');
      final dynamic accounts = js_util.getProperty(google, 'accounts');
      final dynamic oauth2 = js_util.getProperty(accounts, 'oauth2');
      final dynamic tokenClient = js_util.callMethod(
        oauth2,
        'initTokenClient',
        <Object>[
          js_util.jsify(<String, Object?>{
            'client_id': clientId,
            'scope': _scope,
            'callback': js.allowInterop((dynamic response) {
              if (pending.isCompleted) return;
              final String? error = js_util.hasProperty(response, 'error')
                  ? js_util.getProperty(response, 'error') as String?
                  : null;
              final String? token =
                  js_util.hasProperty(response, 'access_token')
                      ? js_util.getProperty(response, 'access_token') as String?
                      : null;
              final String scopes = js_util.hasProperty(response, 'scope')
                  ? (js_util.getProperty(response, 'scope') as String? ?? '')
                  : '';
              if (error != null || token == null ||
                  !scopes.split(' ').contains(_scope)) {
                pending.completeError(
                  StateError('Google Drive permission was not granted.'),
                );
                return;
              }
              final dynamic expiry = js_util.getProperty(response, 'expires_in');
              final int seconds = int.tryParse('$expiry') ?? 3600;
              _token = token;
              _expiresAt =
                  DateTime.now().add(Duration(seconds: seconds > 90 ? seconds - 60 : 30));
              pending.complete();
            }),
            'error_callback': js.allowInterop((dynamic error) {
              if (!pending.isCompleted) {
                pending.completeError(
                  StateError('Google sign-in closed or was blocked.'),
                );
              }
            }),
          }),
        ],
      );
      // Call directly from a user click; a timer cannot open Google's popup.
      js_util.callMethod<void>(tokenClient, 'requestAccessToken', <Object>[]);
    } catch (_) {
      if (!pending.isCompleted) {
        pending.completeError(
          StateError('Could not start Google sign-in. Check your client ID.'),
        );
      }
    }
    return pending.future;
  }

  @override
  Future<String> uploadBackup({
    required String filename,
    required String contents,
    String? fileId,
  }) async {
    if (!isAuthorized) {
      throw StateError('Google sign-in has expired. Reconnect to sync.');
    }

    final String? existing = fileId ?? await _findBackup(filename);
    if (existing != null) {
      final Map<String, dynamic> result = await _request(
        'PATCH',
        'https://www.googleapis.com/upload/drive/v3/files/$existing'
            '?uploadType=media&fields=id',
        contentType: 'application/json; charset=UTF-8',
        body: contents,
      );
      return result['id'] as String? ?? existing;
    }

    // Drive's multipart upload sets a fixed friendly filename and JSON media.
    const String boundary = 'sagelift_drive_backup_boundary';
    final String metadata =
        jsonEncode(<String, String>{'name': filename, 'mimeType': 'application/json'});
    final String multipart = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$contents\r\n'
        '--$boundary--';
    final Map<String, dynamic> result = await _request(
      'POST',
      'https://www.googleapis.com/upload/drive/v3/files'
          '?uploadType=multipart&fields=id',
      contentType: 'multipart/related; boundary=$boundary',
      body: multipart,
    );
    final String? id = result['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('Google Drive did not return the uploaded file ID.');
    }
    return id;
  }

  Future<String?> _findBackup(String filename) async {
    // drive.file allows listing only files this OAuth application created.
    final String query = "name = '${filename.replaceAll("'", "\\'")}'"
        ' and trashed = false';
    final Uri url = Uri.https('www.googleapis.com', '/drive/v3/files',
        <String, String>{
          'q': query,
          'fields': 'files(id,name),nextPageToken',
          'pageSize': '20',
        });
    final Map<String, dynamic> response = await _request('GET', url.toString());
    final List<dynamic> files = response['files'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic item in files) {
      final Map<String, dynamic> file = item as Map<String, dynamic>;
      if (file['name'] == filename && file['id'] is String) {
        return file['id'] as String;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String url, {
    String? contentType,
    String? body,
  }) async {
    if (!isAuthorized) {
      throw StateError('Google sign-in has expired. Reconnect to sync.');
    }
    try {
      final Map<String, String> headers = <String, String>{
        'Authorization': 'Bearer $_token',
        if (contentType != null) 'Content-Type': contentType,
      };
      final HttpRequest response = await HttpRequest.request(
        url,
        method: method,
        requestHeaders: headers,
        sendData: body,
      );
      return jsonDecode(response.responseText ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      throw StateError(
        'Google Drive upload failed. Check your connection and Drive permission.',
      );
    }
  }

  @override
  void disconnect() {
    _token = null;
    _expiresAt = null;
  }
}
