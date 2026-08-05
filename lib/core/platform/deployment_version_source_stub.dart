/// Platform boundary for checking an optionally deployed web build identifier.
abstract interface class DeploymentVersionSource {
  /// Build identifier compiled into the currently running application.
  String get currentBuildId;

  /// Reads the latest deployed identifier, or null when unavailable/offline.
  Future<String?> fetchLatestBuildId();

  /// Reloads into the supplied deployed build without clearing local storage.
  void reloadForBuild(String buildId);
}

/// Creates the non-web source, which simply skips remote update checks.
DeploymentVersionSource createDeploymentVersionSource() =>
    const _UnsupportedDeploymentVersionSource();

class _UnsupportedDeploymentVersionSource implements DeploymentVersionSource {
  const _UnsupportedDeploymentVersionSource();

  @override
  String get currentBuildId => const String.fromEnvironment(
        'SAGELIFT_BUILD_ID',
        defaultValue: 'development',
      );

  @override
  Future<String?> fetchLatestBuildId() async => null;

  @override
  void reloadForBuild(String buildId) {}
}
