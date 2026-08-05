// Browser-native file APIs are intentionally isolated behind this conditional port.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html';

/// Browser file transfer contract used by backup and restore presentation code.
abstract interface class JsonFilePort {
  /// Downloads [contents] using [filename] when the platform supports it.
  Future<void> downloadJson(
      {required String filename, required String contents});

  /// Lets the user select a JSON text file, or returns null when cancelled.
  Future<String?> pickJson();
}

/// Creates a browser-native JSON download and file-picker implementation.
JsonFilePort createJsonFilePort() => const _WebJsonFilePort();

class _WebJsonFilePort implements JsonFilePort {
  const _WebJsonFilePort();

  @override
  Future<void> downloadJson({
    required String filename,
    required String contents,
  }) async {
    final Blob blob = Blob(<Object>[contents], 'application/json');
    final String url = Url.createObjectUrlFromBlob(blob);
    AnchorElement(href: url)
      ..download = filename
      ..click();
    Url.revokeObjectUrl(url);
  }

  @override
  Future<String?> pickJson() async {
    final FileUploadInputElement input = FileUploadInputElement()
      ..accept = 'application/json,.json';
    input.click();
    await input.onChange.first;
    final File? file = input.files?.firstOrNull;
    if (file == null) return null;
    final FileReader reader = FileReader()..readAsText(file);
    await reader.onLoadEnd.first;
    return reader.result as String?;
  }
}
