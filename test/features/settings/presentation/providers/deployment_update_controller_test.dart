import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/platform/deployment_version_source.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/settings/presentation/providers/deployment_update_controller.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_draft_controller.dart';

import '../../../../support/workout_draft_fakes.dart';

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
        keyValueStoreProvider.overrideWithValue(DraftMemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    expect(container.read(deploymentUpdateControllerProvider), '19-new');
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .updateNow();
    expect(source.reloadedBuildId, '19-new');
    expect(localData['workout'], 'saved');

    source.latestBuildId = '18-current';
    container.read(deploymentUpdateControllerProvider.notifier).dismiss();
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    expect(container.read(deploymentUpdateControllerProvider), isNull);
  });

  test('Update now awaits pending draft writes before reloading', () async {
    final DraftMemoryStore store = DraftMemoryStore();
    final _FakeDeploymentVersionSource source = _FakeDeploymentVersionSource(
      currentBuildId: '18-current',
      latestBuildId: '19-new',
    );
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store),
      deploymentVersionSourceProvider.overrideWithValue(source),
    ]);
    addTearDown(container.dispose);
    await container.read(workoutDraftControllerProvider('push').future);
    store.writeGate = Completer<void>();
    container
        .read(workoutDraftControllerProvider('push').notifier)
        .updateWeight('set', '92.5');
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    final Future<void> updating =
        container.read(deploymentUpdateControllerProvider.notifier).updateNow();
    await Future<void>.delayed(Duration.zero);
    expect(source.reloadedBuildId, isNull);
    store.writeGate!.complete();
    await updating;
    expect(source.reloadedBuildId, '19-new');
    final ProviderContainer restored = ProviderContainer(overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(restored.dispose);
    final WorkoutDraft draft =
        await restored.read(workoutDraftControllerProvider('push').future);
    expect(draft.sets['set']!.weight, '92.5');
  });

  test('failed draft flush prevents reload and can be retried', () async {
    final DraftMemoryStore store = DraftMemoryStore();
    final _FakeDeploymentVersionSource source = _FakeDeploymentVersionSource(
      currentBuildId: '18-current',
      latestBuildId: '19-new',
    );
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store),
      deploymentVersionSourceProvider.overrideWithValue(source),
    ]);
    addTearDown(container.dispose);
    await container.read(workoutDraftControllerProvider('push').future);
    store.failWrites = true;
    container
        .read(workoutDraftControllerProvider('push').notifier)
        .updateReps('set', '12');
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .checkForUpdate();
    await expectLater(
      container.read(deploymentUpdateControllerProvider.notifier).updateNow(),
      throwsStateError,
    );
    expect(source.reloadedBuildId, isNull);
    store.failWrites = false;
    await container
        .read(deploymentUpdateControllerProvider.notifier)
        .updateNow();
    expect(source.reloadedBuildId, '19-new');
    expect(store.values.values.single, contains('"reps":"12"'));
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
