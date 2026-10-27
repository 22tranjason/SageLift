import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/equipment_program_update.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';
import 'package:sagelift/features/workouts/presentation/providers/empty_workout_cancellation_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_completion_controller.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_draft_controller.dart';

import 'package:sagelift/features/workouts/presentation/screens/today_screen.dart';

import '../../../../support/workout_draft_fakes.dart';

void main() {
  late ProviderContainer container;
  late _Store store;
  late _Workouts workouts;
  final Workout current =
      WorkoutSeedService.defaultTemplateFor('Chest + Triceps')!;
  final Workout old = current.copyWith(
    status: WorkoutStatus.inProgress,
    startedAt: DateTime.utc(2026, 10, 27, 21),
    exerciseIds: current.exerciseIds
        .where((String id) => id != EquipmentProgramUpdate.pushdown)
        .map((String id) => id == EquipmentProgramUpdate.dumbbellFly
            ? EquipmentProgramUpdate.cableFly
            : id)
        .toList(),
    sets: current.sets
        .where(
            (WorkoutSet s) => s.exerciseId != EquipmentProgramUpdate.pushdown)
        .map((WorkoutSet s) =>
            s.exerciseId == EquipmentProgramUpdate.dumbbellFly
                ? s.copyWith(exerciseId: EquipmentProgramUpdate.cableFly)
                : s)
        .toList(),
  );
  final Workout history = current.copyWith(
      id: 'history',
      status: WorkoutStatus.completed,
      completedAt: DateTime.utc(2026, 10, 25));
  final Workout other = WorkoutSeedService.defaultTemplateFor('Back + Biceps')!;
  void open([Workout? session]) {
    store = _Store();
    workouts = _Workouts(<Workout>[session ?? old, history, other]);
    container = ProviderContainer(overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store),
      workoutRepositoryProvider.overrideWithValue(workouts),
      exerciseRepositoryProvider.overrideWithValue(DraftExerciseRepository()),
      workoutClockProvider
          .overrideWithValue(() => DateTime.utc(2026, 10, 28, 8)),
    ]);
    addTearDown(container.dispose);
  }

  Future<Workout> cancel() =>
      container.read(emptyWorkoutCancellationProvider).cancel(old.id);

  test(
      'cancel empty old session across midnight preserves IDs/history/rotation and starts latest plan',
      () async {
    open();
    final draft = container.read(workoutDraftRepositoryProvider);
    await draft.save(WorkoutDraft(workoutId: old.id));
    final String recommendation =
        WorkoutProgram.recommendedNextWorkoutName(await workouts.getAll());
    final Workout result = await cancel();
    expect(result.id, old.id);
    expect(result.status, WorkoutStatus.planned);
    expect(result.startedAt, isNull);
    expect(result.exerciseIds, current.exerciseIds);
    expect(result.sets, hasLength(15));
    expect(result.sets.take(12).map((WorkoutSet s) => s.id),
        old.sets.map((WorkoutSet s) => s.id));
    expect(result.sets.map((WorkoutSet s) => s.id).toSet(), hasLength(15));
    expect(store.values.containsKey('workouts.draft.v1.${old.id}'), isFalse);
    expect(
        (await container.read(workoutDraftControllerProvider(old.id).future))
            .sets,
        isEmpty);
    expect(workouts.values['history'], history);
    expect(workouts.values[other.id], other);
    expect(WorkoutProgram.recommendedNextWorkoutName(await workouts.getAll()),
        recommendation);
    final Workout? started = await container
        .read(workoutCompletionControllerProvider)
        .startWorkout(result);
    expect(started?.exerciseIds, current.exerciseIds);
    expect(started?.startedAt, DateTime.utc(2026, 10, 28, 8));
  });

  test('latest default can be cancelled without replacing its set IDs',
      () async {
    final Workout active = current.copyWith(
        status: WorkoutStatus.inProgress,
        startedAt: DateTime.utc(2026, 10, 27));
    open(active);
    final Workout reset = await cancel();
    expect(reset.sets, active.sets);
    expect(reset.id, active.id);
    expect(reset.status, WorkoutStatus.planned);
    expect(reset.startedAt, isNull);
  });

  test(
      'entered drafts, unknown fields/version, corrupt drafts and conditioning are refused',
      () async {
    for (final String kind in <String>[
      'weight',
      'reps',
      'unknown',
      'extra',
      'corrupt',
      'conditioning'
    ]) {
      open();
      final drafts = container.read(workoutDraftRepositoryProvider);
      await drafts.save(WorkoutDraft(
        workoutId: old.id,
        sets: kind == 'weight' || kind == 'reps'
            ? <String, WorkoutSetProgress>{
                old.sets.first.id: WorkoutSetProgress(
                    weight: kind == 'weight' ? '0' : '',
                    reps: kind == 'reps' ? 'invalid' : '')
              }
            : <String, WorkoutSetProgress>{},
        conditioning: kind == 'conditioning'
            ? WorkoutConditioningProgress(scaling: 'saved note')
            : null,
      ));
      final String key = 'workouts.draft.v1.${old.id}';
      if (kind == 'unknown') store.values[key] = '{"version":99}';
      if (kind == 'corrupt') store.values[key] = 'not json';
      if (kind == 'extra') {
        final Map<String, dynamic> json =
            jsonDecode(store.values[key]! as String) as Map<String, dynamic>;
        json['futureField'] = 'keep me';
        store.values[key] = jsonEncode(json);
      }
      final Object? before = store.values[key];
      await expectLater(cancel(), throwsA(anything));
      expect(workouts.values[old.id], old);
      expect(store.values[key], before);
      expect(container.read(workoutDraftFinishingProvider(old.id)), isFalse);
    }
  });

  test('recorded sets, custom plans and completed sessions are refused',
      () async {
    for (final Workout value in <Workout>[
      old.copyWith(sets: <WorkoutSet>[
        old.sets.first.copyWith(weightKg: 0.0),
        ...old.sets.skip(1)
      ]),
      old.copyWith(sets: <WorkoutSet>[
        old.sets.first.copyWith(targetWeightKg: 25.0),
        ...old.sets.skip(1),
      ]),
      old.copyWith(exerciseIds: old.exerciseIds.reversed.toList()),
      old.copyWith(warmUp: 'My plan'),
      old.copyWith(sets: <WorkoutSet>[
        old.sets.first.copyWith(notes: 'Custom'),
        ...old.sets.skip(1)
      ]),
      old.copyWith(
          status: WorkoutStatus.completed,
          completedAt: DateTime.utc(2026, 10, 27)),
    ]) {
      open(value);
      await expectLater(cancel(), throwsStateError);
      expect(workouts.values[value.id], value);
    }
  });

  test(
      'pending entered writes are flushed and block cancellation; repeated/finish/start actions are locked',
      () async {
    open();
    await container.read(workoutDraftControllerProvider(old.id).future);
    store.writeGate = Completer<void>();
    container
        .read(workoutDraftControllerProvider(old.id).notifier)
        .updateWeight(old.sets.first.id, '25');
    final Future<Workout> pending = cancel();
    await expectLater(cancel(), throwsStateError);
    expect(
        await container
            .read(workoutCompletionControllerProvider)
            .finishWorkout(old.id),
        isNull);
    await expectLater(
        container.read(workoutCompletionControllerProvider).startWorkout(old),
        throwsStateError);
    container
        .read(workoutDraftControllerProvider(old.id).notifier)
        .updateReps(old.sets.first.id, '99');
    final Future<void> rejected = expectLater(pending, throwsStateError);
    store.writeGate!.complete();
    await rejected;
    expect(workouts.values[old.id], old);
    final WorkoutDraft saved =
        await container.read(workoutDraftRepositoryProvider).load(old.id);
    expect(saved.sets[old.sets.first.id]?.weight, '25');
    expect(saved.sets[old.sets.first.id]?.reps, '');
  });

  test('record changed during validation is rechecked before cleanup',
      () async {
    open();
    await container
        .read(workoutDraftRepositoryProvider)
        .save(WorkoutDraft(workoutId: old.id));
    await container.read(workoutDraftControllerProvider(old.id).future);
    final Workout changed = old.copyWith(notes: 'Changed while checking');
    workouts.reads = 0;
    workouts.onSecondRead = () {
      workouts.values[old.id] = changed;
    };
    await expectLater(cancel(), throwsStateError);
    expect(workouts.values[old.id], changed);
    expect(store.values.containsKey('workouts.draft.v1.${old.id}'), isTrue);
  });

  test('write and cleanup failures leave active record and allow safe retry',
      () async {
    for (final bool failDelete in <bool>[true, false]) {
      open();
      await container
          .read(workoutDraftRepositoryProvider)
          .save(WorkoutDraft(workoutId: old.id));
      store.failDeletes = failDelete;
      workouts.failPlanned = !failDelete;
      await expectLater(cancel(), throwsStateError);
      expect(workouts.values[old.id], old);
      expect(workouts.values['history'], history);
      store.failDeletes = false;
      workouts.failPlanned = false;
      expect((await cancel()).exerciseIds, current.exerciseIds);
      await expectLater(cancel(), throwsStateError);
    }
  });

  testWidgets(
      'Cancel Workout requires confirmation; keeping session leaves every record untouched',
      (WidgetTester tester) async {
    open();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: TodayScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Resume Workout'), findsOneWidget);
    await tester.tap(find.text('Cancel Workout'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel empty workout?'), findsOneWidget);
    await tester.tap(find.text('Keep workout'));
    await tester.pumpAndSettle();
    expect(workouts.values[old.id], old);
    await tester.tap(find.text('Cancel Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel empty workout'));
    await tester.pumpAndSettle();
    expect(find.text('Start Workout'), findsOneWidget);
    expect(find.text('Resume Workout'), findsNothing);
    expect(workouts.values[old.id]?.exerciseIds, current.exerciseIds);
    expect(workouts.values['history'], history);
    expect(workouts.values[other.id], other);
  });

  test(
      'failed pending draft writes refuse cancellation without removing entries',
      () async {
    open();
    await container.read(workoutDraftControllerProvider(old.id).future);
    store.failWrites = true;
    container
        .read(workoutDraftControllerProvider(old.id).notifier)
        .updateReps(old.sets.first.id, '8');
    await Future<void>.delayed(Duration.zero);
    await expectLater(cancel(), throwsStateError);
    expect(workouts.values[old.id], old);
    expect(
        container
            .read(workoutDraftControllerProvider(old.id))
            .requireValue
            .sets[old.sets.first.id]
            ?.reps,
        '8');
  });

  test(
      'use last set fills only blank editable draft fields and persists without completion',
      () async {
    open();
    await container.read(workoutDraftControllerProvider(old.id).future);
    final controller =
        container.read(workoutDraftControllerProvider(old.id).notifier);
    final WorkoutSet previous = old.sets.first
        .copyWith(status: WorkoutSetStatus.completed, weightKg: 22.5, reps: 12);
    controller.updateWeight(old.sets.first.id, '30');
    controller.useLastSet(old.sets.first.id, previous);
    await container.read(workoutDraftRepositoryProvider).flush();
    WorkoutDraft saved =
        await container.read(workoutDraftRepositoryProvider).load(old.id);
    expect(saved.sets[old.sets.first.id]?.weight, '30');
    expect(saved.sets[old.sets.first.id]?.reps, '12');
    controller.updateReps(old.sets.first.id, '11');
    controller.useLastSet(old.sets.first.id, previous);
    await container.read(workoutDraftRepositoryProvider).flush();
    saved = await container.read(workoutDraftRepositoryProvider).load(old.id);
    expect(saved.sets[old.sets.first.id]?.reps, '11');
    expect(workouts.values[old.id], old);
    controller.useLastSet(
        old.sets[1].id, previous.copyWith(weightKg: null, reps: null));
    controller.useLastSet(
        old.sets[1].id, previous.copyWith(status: WorkoutSetStatus.planned));
    expect(
        container
            .read(workoutDraftControllerProvider(old.id))
            .requireValue
            .sets
            .containsKey(old.sets[1].id),
        isFalse);
    store.failWrites = true;
    controller.useLastSet(old.sets[1].id, previous);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(workoutDraftSaveProvider(old.id)).hasError, isTrue);
    expect(
        container
            .read(workoutDraftControllerProvider(old.id))
            .requireValue
            .sets[old.sets[1].id]
            ?.weight,
        '22.5');
    store.failWrites = false;
    await controller.retrySave();
    expect(
        (await container.read(workoutDraftRepositoryProvider).load(old.id))
            .sets[old.sets[1].id]
            ?.weight,
        '22.5');
  });
}

class _Store extends DraftMemoryStore {
  bool failDeletes = false;
  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('delete failed');
    await super.delete(key);
  }
}

class _Workouts extends DraftWorkoutRepository {
  _Workouts(super.workouts);
  bool failPlanned = false;
  VoidCallback? onSecondRead;
  int reads = 0;
  @override
  Future<Workout?> getById(String id) async {
    if (++reads == 2) onSecondRead?.call();
    return super.getById(id);
  }

  @override
  Future<void> save(Workout workout) async {
    if (failPlanned && workout.status == WorkoutStatus.planned) {
      throw StateError('save failed');
    }
    await super.save(workout);
  }
}
