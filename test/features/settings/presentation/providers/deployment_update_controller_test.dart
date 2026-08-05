import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/platform/deployment_version_source.dart';
import 'package:sagelift/features/settings/presentation/providers/deployment_update_controller.dart';

void main() {
  test('compares deployment build IDs by their GitHub Actions build number',
      () {
    expect(
      isNewerBuildId(currentBuildId: '18-old', latestBuildId: '19-new'),
      isTrue,
    );
    expect(
      isNewerBuildId(currentBuildId: '19-current', latestBuildId: '19-current'),
      isFalse,
    );
    expect(
      isNewerBuildId(currentBuildId: '19-current', latestBuildId: '18-old'),
      isFalse,
    );
  });

  test('prompts only for newer builds and reload leaves local state untouched',
      () async {
    final _FakeDeploymentVersionSource source = _FakeDeploymentVersionSource(
      currentBuildId: '18-current',
      latestBuildId: '19-new',
    );
    final Map<String, String> localData = <String, String>{'workout': 'saved'};
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        deploymentVersionSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    expect(container.read(deploymentUpdateControllerProvider), '19-new');
    container.read(deploymentUpdateControllerProvider.notifier).updateNow();
    expect(source.reloadedBuildId, '19-new');
    expect(localData['workout'], 'saved');

    source.latestBuildId = '18-current';
    container.read(deploymentUpdateControllerProvider.notifier).dismiss();
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    expect(container.read(deploymentUpdateControllerProvider), isNull);
  });
}

class _FakeDeploymentVersionSource implements DeploymentVersionSource {
  _FakeDeploymentVersionSource({
    required this.currentBuildId,
    required this.latestBuildId,
  });

  @override
  final String currentBuildId;

  String? latestBuildId;
  String? reloadedBuildId;

  @override
  Future<String?> fetchLatestBuildId() async => latestBuildId;

  @override
  void reloadForBuild(String buildId) {
    reloadedBuildId = buildId;
  }
}
