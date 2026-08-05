// Browser-native deployment checks are intentionally isolated behind this port.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html';

/// Platform boundary for checking an optionally deployed web build identifier.
abstract interface class DeploymentVersionSource {
  /// Build identifier compiled into the currently running application.
  String get currentBuildId;

  /// Reads the latest deployed identifier, or null when unavailable/offline.
  Future<String?> fetchLatestBuildId();

  /// Reloads into the supplied deployed build without clearing local storage.
  void reloadForBuild(String buildId);
}

/// Creates the browser implementation used by GitHub Pages deployments.
DeploymentVersionSource createDeploymentVersionSource() =>
    const _WebDeploymentVersionSource();

class _WebDeploymentVersionSource implements DeploymentVersionSource {
  const _WebDeploymentVersionSource();

  @override
  String get currentBuildId => const String.fromEnvironment(
        'SAGELIFT_BUILD_ID',
        defaultValue: 'development',
      );

  @override
  Future<String?> fetchLatestBuildId() async {
    try {
      final Uri versionUri = Uri.base.resolve('version.json').replace(
        queryParameters: <String, String>{
          'cacheBust': DateTime.now().microsecondsSinceEpoch.toString(),
        },
      );
      final String response =
          await HttpRequest.getString(versionUri.toString());
      final Object? decoded = jsonDecode(response);
      if (decoded is! Map<String, dynamic>) return null;
      final Object? buildId = decoded['buildId'];
      return buildId is String && buildId.isNotEmpty ? buildId : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void reloadForBuild(String buildId) {
    final Uri current = Uri.base;
    final Map<String, String> query = Map<String, String>.from(
      current.queryParameters,
    )..['sagelift-build'] = buildId;
    window.location.replace(current.replace(queryParameters: query).toString());
  }
}
