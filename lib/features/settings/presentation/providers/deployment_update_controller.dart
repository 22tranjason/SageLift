import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/deployment_version_source.dart';
import '../../../workouts/presentation/providers/workout_draft_controller.dart';

/// Compares monotonically increasing GitHub Actions build identifiers.
bool isNewerBuildId({
  required String currentBuildId,
  required String latestBuildId,
}) {
  if (currentBuildId == latestBuildId) return false;
  final int? currentNumber = _buildNumber(currentBuildId);
  final int? latestNumber = _buildNumber(latestBuildId);
  if (currentNumber != null && latestNumber != null) {
    return latestNumber > currentNumber;
  }
  return false;
}

int? _buildNumber(String value) => int.tryParse(value.split('-').first);

/// Provides the platform-specific deployed-version source.
final Provider<DeploymentVersionSource> deploymentVersionSourceProvider =
    Provider<DeploymentVersionSource>(
        (Ref ref) => createDeploymentVersionSource());

/// Exposes a newer build ID only when a prompt should be shown.
final NotifierProvider<DeploymentUpdateController, String?>
    deploymentUpdateControllerProvider =
    NotifierProvider<DeploymentUpdateController, String?>(
  DeploymentUpdateController.new,
);

/// Checks for new deployments without affecting local Hive data.
class DeploymentUpdateController extends Notifier<String?> {
  final Set<String> _dismissedBuildIds = <String>{};

  @override
  String? build() => null;

  /// Checks the deployed version file and exposes a prompt for newer builds.
  Future<void> checkForUpdate() async {
    final DeploymentVersionSource source = ref.read(
      deploymentVersionSourceProvider,
    );
    final String? latestBuildId = await source.fetchLatestBuildId();
    if (latestBuildId == null || _dismissedBuildIds.contains(latestBuildId)) {
      return;
    }
    if (isNewerBuildId(
      currentBuildId: source.currentBuildId,
      latestBuildId: latestBuildId,
    )) {
      state = latestBuildId;
    }
  }

  /// Hides the prompt until a distinct deployment becomes available.
  void dismiss() {
    final String? buildId = state;
    if (buildId != null) _dismissedBuildIds.add(buildId);
    state = null;
  }

  /// Reloads with a cache-busting build query; it never clears browser storage.
  Future<void> updateNow() async {
    final String? buildId = state;
    if (buildId == null) return;
    await ref.read(workoutDraftRepositoryProvider).flush();
    ref.read(deploymentVersionSourceProvider).reloadForBuild(buildId);
  }
}
