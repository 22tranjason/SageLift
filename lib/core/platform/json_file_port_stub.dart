/// Browser file transfer contract used by backup and restore presentation code.
abstract interface class JsonFilePort {
  /// Downloads [contents] using [filename] when the platform supports it.
  Future<void> downloadJson(
      {required String filename, required String contents});

  /// Lets the user select a JSON text file, or returns null when cancelled.
  Future<String?> pickJson();
}

/// Creates the non-web fallback, which reports unsupported file operations.
JsonFilePort createJsonFilePort() => const _UnsupportedJsonFilePort();

class _UnsupportedJsonFilePort implements JsonFilePort {
  const _UnsupportedJsonFilePort();

  @override
  Future<void> downloadJson({
    required String filename,
    required String contents,
  }) {
    return Future<void>.error(
      UnsupportedError('Backup download is available in the web app.'),
    );
  }

  @override
  Future<String?> pickJson() {
    return Future<String?>.error(
      UnsupportedError('Backup restore is available in the web app.'),
    );
  }
}
