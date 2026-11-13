/// Small remote-storage contract, allowing offline and unit-test fakes.
abstract interface class GoogleDriveSyncPort {
  /// Whether a usable Google OAuth token is currently held in memory.
  bool get isAuthorized;

  /// Requests user consent through Google Identity Services.
  Future<void> authorize(String clientId);

  /// Creates or replaces one private Google Drive JSON file.
  Future<String> uploadBackup({
    required String filename,
    required String contents,
    String? fileId,
  });

  /// Forgets the access token held by this app instance.
  void disconnect();
}

/// Non-browser platforms retain all local features without Drive access.
GoogleDriveSyncPort createGoogleDriveSyncPort() =>
    const _UnsupportedGoogleDriveSyncPort();

class _UnsupportedGoogleDriveSyncPort implements GoogleDriveSyncPort {
  const _UnsupportedGoogleDriveSyncPort();

  @override
  bool get isAuthorized => false;

  @override
  Future<void> authorize(String clientId) =>
      Future<void>.error(UnsupportedError('Google Drive sync needs the web app.'));

  @override
  Future<String> uploadBackup({
    required String filename,
    required String contents,
    String? fileId,
  }) =>
      Future<String>.error(UnsupportedError('Google Drive sync needs the web app.'));

  @override
  void disconnect() {}
}
