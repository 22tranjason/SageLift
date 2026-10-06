import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/data/repositories/local_workout_draft_repository.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_completion_controller.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_draft_controller.dart';

import '../../../../support/workout_draft_fakes.dart';

void main() {
  late DraftMemoryStore store;
  late DraftWorkoutRepository workouts;
  late ProviderContainer container;
  late DateTime now;

  ProviderContainer createContainer() => ProviderContainer(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(store),
          workoutRepositoryProvider.overrideWithValue(workouts),
          workoutClockProvider.overrideWithValue(() => now),
        ],
      );

  Future<WorkoutDraftController> load([String id = 'push']) async {
    await container.read(workoutDraftControllerProvider(id).future);
    return container.read(workoutDraftControllerProvider(id).notifier);
  }

  Future<void> recreate() async {
    await container.read(workoutDraftRepositoryProvider).flush();
    container.dispose();
    container = createContainer();
  }

  setUp(() {
    store = DraftMemoryStore();
    workouts = DraftWorkoutRepository(<Workout>[
      draftTestWorkout(),
      draftTestWorkout(
          id: 'pull', name: 'Pull A Hybrid', status: WorkoutStatus.planned),
    ]);
    now = DateTime.utc(2026, 9, 21, 8);
    container = createContainer();
  });

  tearDown(() => container.dispose());

  test(
      'old Hybrid draft retires a running timer and preserves strength on retry',
      () async {
    final WorkoutDraftController old = await load();
    old.updateWeight('set-1', '82.5');
    old.updateReps('set-1', '8');
    old.startTimer(now);
    await container.read(workoutDraftRepositoryProvider).flush();
    workouts.values['push'] = draftTestWorkout(track: WorkoutTrack.hybrid);
    await recreate();
    final WorkoutDraft draft =
        await container.read(workoutDraftControllerProvider('push').future);
    expect(draft.sets['set-1']!.weight, '82.5');
    expect(draft.conditioning.timer.isRunning, isFalse);
    expect(draft.conditioning.movements, isEmpty);
    workouts.failCompletion = true;
    await expectLater(
        container
            .read(workoutCompletionControllerProvider)
            .finishWorkout('push'),
        throwsStateError);
    await recreate();
    workouts.failCompletion = false;
    final Workout? completed = await container
        .read(workoutCompletionControllerProvider)
        .finishWorkout('push');
    expect(completed!.sets.single.weightKg, 82.5);
    expect(completed.sets.single.reps, 8);
    expect(completed.conditioningPlan, isNull);
    expect(completed.conditioningResult, isNull);
    expect(store.values.containsKey('workouts.draft.v1.push'), isFalse);
  });

  test('strength entries survive provider and repository recreation', () async {
    final WorkoutDraftController controller = await load();
    controller.updateWeight('set-1', '82.5');
    controller.updateReps('set-1', '8');
    await recreate();
    final WorkoutDraft draft =
        await container.read(workoutDraftControllerProvider('push').future);
    expect(draft.sets['set-1']!.weight, '82.5');
    expect(draft.sets['set-1']!.reps, '8');
    expect(workouts.values['push']!.status, WorkoutStatus.inProgress);
    expect(workouts.values['push']!.sets.single.weightKg, isNull);
  });

  test('conditioning values, separate movement loads and scaling survive',
      () async {
    final WorkoutDraftController controller = await load();
    controller.updateConditioning(WorkoutConditioningProgress(
      rounds: '3',
      additionalReps: '7',
      minutes: '4',
      seconds: '08',
      hasManualTime: true,
      scaling: 'Shortened circuit',
      isCompleted: true,
    ));
    controller.updateMovement(
        'snatch',
        const ConditioningMovementProgress(
          load: '17.5',
          implementCount: '1',
          modification: 'Hang snatch',
        ));
    controller.updateMovement(
        'squat',
        const ConditioningMovementProgress(
          load: '24',
          implementCount: '1',
          modification: 'Box squat',
        ));
    await recreate();
    final WorkoutConditioningProgress progress =
        (await container.read(workoutDraftControllerProvider('push').future))
            .conditioning;
    expect(progress.rounds, '3');
    expect(progress.additionalReps, '7');
    expect(progress.minutes, '4');
    expect(progress.seconds, '08');
    expect(progress.hasManualTime, isTrue);
    expect(progress.scaling, 'Shortened circuit');
    expect(progress.isCompleted, isTrue);
    expect(progress.movements['snatch']!.load, '17.5');
    expect(progress.movements['snatch']!.implementCount, '1');
    expect(progress.movements['snatch']!.modification, 'Hang snatch');
    expect(progress.movements['squat']!.load, '24');
    expect(progress.movements['squat']!.modification, 'Box squat');
  });

  test('running timer catches up after recreation and resumed accumulation',
      () async {
    final WorkoutDraftController controller = await load();
    controller.startTimer(now);
    now = now.add(const Duration(seconds: 20));
    controller.pauseTimer(now);
    now = now.add(const Duration(minutes: 1));
    controller.startTimer(now);
    await recreate();
    now = now.add(const Duration(minutes: 4, seconds: 5));
    final WorkoutDraft draft =
        await container.read(workoutDraftControllerProvider('push').future);
    expect(draft.conditioning.timer.isRunning, isTrue);
    expect(draft.conditioning.timer.elapsedAt(now),
        const Duration(minutes: 4, seconds: 25));
  });

  test('paused timer stays paused and never counts time away', () async {
    final WorkoutDraftController controller = await load();
    controller.startTimer(now);
    now = now.add(const Duration(seconds: 85));
    controller.pauseTimer(now);
    await recreate();
    now = now.add(const Duration(days: 2));
    final WorkoutDraft draft =
        await container.read(workoutDraftControllerProvider('push').future);
    expect(draft.conditioning.timer.isRunning, isFalse);
    expect(
        draft.conditioning.timer.elapsedAt(now), const Duration(seconds: 85));
  });

  test('switching sessions and returning restores only that sessions entries',
      () async {
    workouts.values['push'] = draftTestWorkout(track: WorkoutTrack.hybrid);
    workouts.values['pull'] = draftTestWorkout(
        id: 'pull',
        name: 'Pull A Hybrid',
        status: WorkoutStatus.planned,
        track: WorkoutTrack.hybrid);
    (await load()).updateWeight('set-1', '80');
    await container
        .read(workoutCompletionControllerProvider)
        .startSelectedWorkout('Pull A Hybrid', replaceInProgress: true);
    (await load('pull')).updateWeight('set-1', '50');
    await recreate();
    await container
        .read(workoutCompletionControllerProvider)
        .startSelectedWorkout('Push A Hybrid', replaceInProgress: true);
    final WorkoutDraft push =
        await container.read(workoutDraftControllerProvider('push').future);
    final WorkoutDraft pull =
        await container.read(workoutDraftControllerProvider('pull').future);
    expect(push.sets['set-1']!.weight, '80');
    expect(pull.sets['set-1']!.weight, '50');
  });

  test('completion persists history before deleting only its own draft',
      () async {
    final WorkoutDraftController controller = await load();
    controller.updateWeight('set-1', '80');
    controller.updateReps('set-1', '10');
    (await load('pull')).updateWeight('set-1', '40');
    await container.read(workoutDraftRepositoryProvider).flush();
    workouts.completionGate = Completer<void>();
    final Future<Workout?> completion = container
        .read(workoutCompletionControllerProvider)
        .finishWorkout('push');
    await Future<void>.delayed(Duration.zero);
    expect(store.values.containsKey('workouts.draft.v1.push'), isTrue);
    workouts.completionGate!.complete();
    final Workout? saved = await completion;
    expect(saved!.sets.single.weightKg, 80);
    expect(saved.sets.single.reps, 10);
    expect(store.values.containsKey('workouts.draft.v1.push'), isFalse);
    expect(store.values.containsKey('workouts.draft.v1.pull'), isTrue);
    await recreate();
    expect(
        (await container.read(workoutDraftControllerProvider('push').future))
            .sets,
        isEmpty);
  });

  test('failed completion retains a recoverable finalized draft', () async {
    final WorkoutDraftController controller = await load();
    controller.updateWeight('set-1', '90');
    controller.startTimer(now);
    now = now.add(const Duration(seconds: 77));
    workouts.failCompletion = true;
    await expectLater(
      container.read(workoutCompletionControllerProvider).finishWorkout('push'),
      throwsStateError,
    );
    await recreate();
    final WorkoutDraft restored =
        await container.read(workoutDraftControllerProvider('push').future);
    expect(restored.sets['set-1']!.weight, '90');
    expect(restored.conditioning.timer.elapsed, const Duration(seconds: 77));
    expect(restored.conditioning.timer.isRunning, isFalse);
    expect(workouts.values['push']!.status, WorkoutStatus.inProgress);
    workouts.failCompletion = false;
    expect(
        await container
            .read(workoutCompletionControllerProvider)
            .finishWorkout('push'),
        isNotNull);
  });

  for (final bool paused in <bool>[false, true]) {
    test(
        '${paused ? "paused" : "running"} timer is finalized by Finish Workout',
        () async {
      final WorkoutDraftController controller = await load();
      controller.startTimer(now);
      now = now.add(const Duration(minutes: 3, seconds: 17));
      if (paused) controller.pauseTimer(now);
      await recreate();
      now = now.add(const Duration(minutes: 2));
      final Workout? saved = await container
          .read(workoutCompletionControllerProvider)
          .finishWorkout('push');
      expect(saved!.conditioningResult!.completionTime,
          Duration(minutes: paused ? 3 : 5, seconds: 17));
    });
  }

  test('manual correction survives restart and takes precedence at completion',
      () async {
    final WorkoutDraftController controller = await load();
    controller.startTimer(now);
    controller.updateConditioning(
      container
          .read(workoutDraftControllerProvider('push'))
          .requireValue
          .conditioning
          .copyWith(minutes: '2', seconds: '34', hasManualTime: true),
    );
    await recreate();
    now = now.add(const Duration(minutes: 8));
    final Workout? saved = await container
        .read(workoutCompletionControllerProvider)
        .finishWorkout('push');
    expect(saved!.conditioningResult!.completionTime,
        const Duration(minutes: 2, seconds: 34));
  });

  test('storage failure is visible, retains edits and flush can retry',
      () async {
    final WorkoutDraftController controller = await load();
    store.failWrites = true;
    controller.updateWeight('set-1', '105');
    await expectLater(container.read(workoutDraftRepositoryProvider).flush(),
        throwsStateError);
    expect(container.read(workoutDraftSaveProvider('push')).hasError, isTrue);
    expect(
        container
            .read(workoutDraftControllerProvider('push'))
            .requireValue
            .sets['set-1']!
            .weight,
        '105');
    store.failWrites = false;
    await recreate();
    expect(
        (await container.read(workoutDraftControllerProvider('push').future))
            .sets['set-1']!
            .weight,
        '105');
  });

  test('failed draft write prevents completed-history write', () async {
    await load();
    store.failWrites = true;
    await expectLater(
        container
            .read(workoutCompletionControllerProvider)
            .finishWorkout('push'),
        throwsStateError);
    expect(workouts.values['push']!.status, WorkoutStatus.inProgress);
  });

  test('invalid stored draft is not silently replaced by an empty draft',
      () async {
    store.values['workouts.draft.v1.push'] = '{"version":99}';
    await expectLater(
        container.read(workoutDraftControllerProvider('push').future),
        throwsFormatException);
    expect(store.values['workouts.draft.v1.push'], '{"version":99}');
  });

  test('queued writes cannot recreate a draft after removal', () async {
    final LocalWorkoutDraftRepository repository =
        LocalWorkoutDraftRepository(store);
    store.writeGate = Completer<void>();
    final Future<void> write = repository.save(WorkoutDraft(workoutId: 'push'));
    final Future<void> remove = repository.remove('push');
    store.writeGate!.complete();
    await write;
    await remove;
    await repository.flush();
    expect(store.values, isEmpty);
  });
}
