import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/features/workouts/data/adapters/workout_hive_adapters.dart';
import 'package:sagelift/features/workouts/data/local/workout_hive_store.dart';
import 'package:sagelift/features/workouts/data/models/workout_hive_model.dart';
import 'package:sagelift/features/workouts/data/models/workout_set_hive_model.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_exercise_repository.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_workout_repository.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
import 'package:sagelift/features/workouts/domain/models/conditioning.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('sagelift_hive_');
    Hive.init(temporaryDirectory.path);
    WorkoutHiveAdapters.registerAll();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('seeds the six Hybrid templates idempotently', () async {
    final _Repositories repositories = await _openRepositories();
    final WorkoutSeedService seedService = WorkoutSeedService(
      exerciseRepository: repositories.exerciseRepository,
      workoutRepository: repositories.workoutRepository,
    );

    await seedService.seedIfEmpty();

    final List<Workout> workouts =
        await repositories.workoutRepository.getAll();
    final List<Workout> hybridWorkouts = workouts
        .where((Workout workout) => workout.track == WorkoutTrack.hybrid)
        .toList(growable: false);
    expect(hybridWorkouts, hasLength(6));
    expect(
      hybridWorkouts.map((Workout workout) => workout.name),
      containsAll(<String>[
        'Push A Hybrid',
        'Pull A Hybrid',
        'Legs A Hybrid',
        'Push B Hybrid',
        'Pull B Hybrid',
        'Legs B Hybrid',
      ]),
    );

    final Workout pushA = hybridWorkouts.singleWhere(
      (Workout workout) => workout.name == 'Push A Hybrid',
    );
    expect(pushA.warmUp, contains('5 min'));
    expect(pushA.sessionDurationTarget, 'Up to about 60 min');
    expect(pushA.exerciseIds, hasLength(5));
    expect(pushA.sets, hasLength(16));
    expect(pushA.conditioningPlan?.format, ConditioningFormat.roundsForTime);
    expect(pushA.conditioningPlan?.prescribedRounds, 4);
    expect(
      pushA.conditioningPlan?.movements.map(
        (ConditioningMovement movement) => movement.name,
      ),
      equals(<String>[
        'Kettlebell Swings',
        'Alternating Kettlebell Reverse Lunges',
        'Step-ups',
        'Run',
      ]),
    );
    expect(await repositories.exerciseRepository.getAll(), isNotEmpty);

    await seedService.seedIfEmpty();
    expect(
      (await repositories.workoutRepository.getAll())
          .where((Workout workout) => workout.track == WorkoutTrack.hybrid),
      hasLength(6),
    );
  });

  test('migration retains legacy PPL and CrossFit completed history verbatim',
      () async {
    final _Repositories repositories = await _openRepositories();
    final Workout legacyPpl = _completedWorkout(
      id: 'legacy-ppl-history',
      name: 'Push A',
      track: WorkoutTrack.strengthPpl,
      completedAt: DateTime.utc(2026, 8, 1, 7),
    );
    final Workout legacyCrossFit = _completedWorkout(
      id: 'legacy-crossfit-history',
      name: 'CrossFit A',
      track: WorkoutTrack.crossFit,
      completedAt: DateTime.utc(2026, 8, 2, 7),
      conditioningResult: ConditioningResult(
        roundsCompleted: 3,
        additionalReps: 5,
        completionTime: Duration(minutes: 18),
        scaling: 'Step-ups',
        isCompleted: false,
        movementResults: <ConditioningMovementResult>[
          ConditioningMovementResult(
            movementId: 'legacy-swing',
            actualLoad: 10,
          ),
        ],
      ),
    );
    await repositories.workoutRepository.save(legacyPpl);
    await repositories.workoutRepository.save(legacyCrossFit);

    await WorkoutSeedService(
      exerciseRepository: repositories.exerciseRepository,
      workoutRepository: repositories.workoutRepository,
    ).seedIfEmpty();

    expect(
      await repositories.workoutRepository.getById(legacyPpl.id),
      legacyPpl,
    );
    expect(
      await repositories.workoutRepository.getById(legacyCrossFit.id),
      legacyCrossFit,
    );
    expect(
      (await repositories.workoutRepository.getById(legacyCrossFit.id))
          ?.conditioningResult
          ?.movementResults
          .single
          .actualLoad,
      10,
    );
  });

  test('persists completed workout records across a repository reload',
      () async {
    final _Repositories repositories = await _openRepositories();
    final Workout completedWorkout = _completedWorkout(
      id: 'completed-workout-1',
      name: 'Push A Hybrid',
      track: WorkoutTrack.hybrid,
      completedAt: DateTime.utc(2026, 7, 30, 7, 5),
    );

    await repositories.workoutRepository.save(completedWorkout);
    await repositories.store.workoutBox.close();
    final WorkoutHiveStore reopenedStore = await WorkoutHiveStore.open();
    final HiveWorkoutRepository reopenedRepository = HiveWorkoutRepository(
      reopenedStore.workoutBox,
    );

    expect(
      await reopenedRepository.getById(completedWorkout.id),
      completedWorkout,
    );
  });

  test('decodes legacy generic conditioning data without movement records',
      () async {
    final _Repositories repositories = await _openRepositories();
    await repositories.store.workoutBox.put(
      'legacy-crossfit-generic',
      WorkoutHiveModel(
        id: 'legacy-crossfit-generic',
        name: 'CrossFit B',
        scheduledDateMilliseconds:
            DateTime.utc(2026, 8, 1).millisecondsSinceEpoch,
        exerciseIds: const <String>[],
        sets: const <WorkoutSetHiveModel>[],
        statusIndex: WorkoutStatus.completed.index,
        trackIndex: WorkoutTrack.crossFit.index,
        conditioningFormatIndex: ConditioningFormat.roundsForTime.index,
        conditioningTitle: '4 rounds for time',
        conditioningInstructions: 'Legacy instructions',
        prescribedRounds: 4,
        roundsCompleted: 4,
        additionalReps: 0,
        completionTimeMilliseconds: const Duration(minutes: 30).inMilliseconds,
        conditioningScaling: '15 kg goblet lunges; step-ups.',
        conditioningCompleted: true,
      ),
    );

    final Workout? decoded = await repositories.workoutRepository.getById(
      'legacy-crossfit-generic',
    );
    expect(decoded?.track, WorkoutTrack.crossFit);
    expect(decoded?.conditioningResult?.movementResults, isEmpty);
    expect(decoded?.conditioningResult?.scaling, contains('goblet lunges'));
  });
}

Future<_Repositories> _openRepositories() async {
  final WorkoutHiveStore store = await WorkoutHiveStore.open();
  return _Repositories(
    store: store,
    exerciseRepository: HiveExerciseRepository(store.exerciseBox),
    workoutRepository: HiveWorkoutRepository(store.workoutBox),
  );
}

class _Repositories {
  const _Repositories({
    required this.store,
    required this.exerciseRepository,
    required this.workoutRepository,
  });

  final WorkoutHiveStore store;
  final HiveExerciseRepository exerciseRepository;
  final HiveWorkoutRepository workoutRepository;
}

Workout _completedWorkout({
  required String id,
  required String name,
  required WorkoutTrack track,
  required DateTime completedAt,
  ConditioningResult? conditioningResult,
}) {
  return Workout(
    id: id,
    name: name,
    scheduledDate: DateTime.utc(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    ),
    status: WorkoutStatus.completed,
    track: track,
    exerciseIds: const <String>['exercise-1'],
    sets: const <WorkoutSet>[
      WorkoutSet(
        id: 'completed-set-1',
        exerciseId: 'exercise-1',
        setNumber: 1,
        weightKg: 80,
        reps: 8,
        status: WorkoutSetStatus.completed,
      ),
    ],
    startedAt: completedAt.subtract(const Duration(minutes: 45)),
    completedAt: completedAt,
    conditioningPlan: conditioningResult == null
        ? null
        : ConditioningPlan(
            format: ConditioningFormat.roundsForTime,
            title: '4 rounds for time',
            instructions: 'Recorded legacy conditioning',
            prescribedRounds: 4,
          ),
    conditioningResult: conditioningResult,
  );
}
