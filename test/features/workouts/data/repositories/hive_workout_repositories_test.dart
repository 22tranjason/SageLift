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
import 'package:sagelift/features/workouts/domain/services/exercise_progression_service.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sagelift_hive_',
    );
    Hive.init(temporaryDirectory.path);
    WorkoutHiveAdapters.registerAll();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('seeds the four strength templates idempotently', () async {
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
    expect(hybridWorkouts, hasLength(4));
    expect(
      hybridWorkouts.map((Workout workout) => workout.name),
      containsAll(<String>[
        'Chest + Triceps',
        'Back + Biceps',
        'Shoulders + Traps',
        'Legs + Calves',
      ]),
    );

    final Workout pushA = hybridWorkouts.singleWhere(
      (Workout workout) => workout.name == 'Chest + Triceps',
    );
    expect(pushA.warmUp, contains('8–10 min'));
    expect(pushA.sessionDurationTarget, 'About 50–60 min including warm-up');
    expect(pushA.exerciseIds, hasLength(4));
    expect(pushA.sets, hasLength(12));
    for (final Workout workout in hybridWorkouts) {
      expect(workout.conditioningPlan, isNull);
      expect(workout.conditioningResult, isNull);
    }
    expect(await repositories.exerciseRepository.getAll(), isNotEmpty);

    await seedService.seedIfEmpty();
    expect(
      (await repositories.workoutRepository.getAll()).where(
        (Workout workout) => workout.track == WorkoutTrack.hybrid,
      ),
      hasLength(4),
    );
  });

  test(
    'four-day migration preserves retired sessions and recorded sets without duplicates',
    () async {
      final _Repositories repositories = await _openRepositories();
      final List<Workout> originals = <Workout>[
        _completedWorkout(
          id: 'seed-workout-push-a-hybrid',
          name: 'Push A Hybrid',
          track: WorkoutTrack.hybrid,
          completedAt: DateTime.utc(2026, 10, 20),
        ),
        _completedWorkout(
          id: 'retired-active',
          name: 'Pull A Hybrid',
          track: WorkoutTrack.hybrid,
          completedAt: DateTime.utc(2026, 10, 21),
        ).copyWith(status: WorkoutStatus.inProgress, completedAt: null),
        _completedWorkout(
          id: 'retired-planned',
          name: 'Legs A Hybrid',
          track: WorkoutTrack.hybrid,
          completedAt: DateTime.utc(2026, 10, 21),
        ).copyWith(status: WorkoutStatus.planned, completedAt: null),
      ];
      for (final Workout workout in originals) {
        await repositories.workoutRepository.save(workout);
      }
      final WorkoutSeedService seed = WorkoutSeedService(
        exerciseRepository: repositories.exerciseRepository,
        workoutRepository: repositories.workoutRepository,
      );
      await seed.seedIfEmpty();
      final List<Workout> first = await repositories.workoutRepository.getAll();
      await seed.seedIfEmpty();
      expect(await repositories.workoutRepository.getAll(), first);
      for (final Workout original in originals) {
        expect(
          await repositories.workoutRepository.getById(original.id),
          original,
        );
      }
      final List<Workout> current = first
          .where(
            (Workout w) => <String>[
              'Chest + Triceps',
              'Back + Biceps',
              'Shoulders + Traps',
              'Legs + Calves',
            ].contains(w.name),
          )
          .toList();
      expect(current, hasLength(4));
      expect(current.map((Workout w) => w.id).toSet(), hasLength(4));
      for (final Workout w in current) {
        expect(w.sets.length, inInclusiveRange(12, 15));
        for (final WorkoutSet set in w.sets) {
          expect(
              const ExerciseProgressionService().repRangeFor(set), isNotNull);
          expect(const ExerciseProgressionService().restGuidanceFor(set),
              isNotNull);
        }
        expect(w.warmUp, contains('2–3 reps in reserve'));
        expect(
          w.sets.every((set) => set.weightKg == null && set.reps == null),
          isTrue,
        );
      }
      final Workout legs = current.singleWhere(
        (Workout w) => w.name == 'Legs + Calves',
      );
      expect(
        legs.exerciseIds,
        contains('seed-exercise-standing-cable-leg-curl'),
      );
      expect(legs.sessionDurationTarget, contains('65–75'));
    },
  );

  test(
    'migration retains legacy PPL and CrossFit completed history verbatim',
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
        (await repositories.workoutRepository.getById(
          legacyCrossFit.id,
        ))
            ?.conditioningResult
            ?.movementResults
            .single
            .actualLoad,
        10,
      );
    },
  );

  test(
    'cleanup preserves completed Hybrid history and stored strength idempotently',
    () async {
      final _Repositories repositories = await _openRepositories();
      final Workout completed = _completedWorkout(
        id: 'old-hybrid-history',
        name: 'Push A Hybrid',
        track: WorkoutTrack.hybrid,
        completedAt: DateTime.utc(2026, 8, 3),
        conditioningResult: ConditioningResult(
          roundsCompleted: 4,
          additionalReps: 0,
          completionTime: const Duration(minutes: 9),
          isCompleted: true,
        ),
      );
      final Workout active = completed.copyWith(
        id: 'old-active-hybrid',
        status: WorkoutStatus.inProgress,
        completedAt: null,
      );
      final Workout planned = completed.copyWith(
        id: 'old-planned-hybrid',
        name: 'Pull A Hybrid',
        status: WorkoutStatus.planned,
        completedAt: null,
      );
      for (final Workout workout in <Workout>[completed, active, planned]) {
        await repositories.workoutRepository.save(workout);
      }
      final WorkoutSeedService seed = WorkoutSeedService(
        exerciseRepository: repositories.exerciseRepository,
        workoutRepository: repositories.workoutRepository,
      );
      await seed.seedIfEmpty();
      await seed.seedIfEmpty();
      expect(
        await repositories.workoutRepository.getById(completed.id),
        completed,
      );
      for (final Workout original in <Workout>[active, planned]) {
        final Workout saved = (await repositories.workoutRepository.getById(
          original.id,
        ))!;
        expect(
          saved,
          original.copyWith(conditioningPlan: null, conditioningResult: null),
        );
        expect(saved.sets.single.weightKg, 80);
        expect(saved.sets.single.reps, 8);
      }
    },
  );

  test(
    'persists completed workout records across a repository reload',
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
    },
  );

  test(
    'decodes legacy generic conditioning data without movement records',
    () async {
      final _Repositories repositories = await _openRepositories();
      await repositories.store.workoutBox.put(
        'legacy-crossfit-generic',
        WorkoutHiveModel(
          id: 'legacy-crossfit-generic',
          name: 'CrossFit B',
          scheduledDateMilliseconds: DateTime.utc(
            2026,
            8,
            1,
          ).millisecondsSinceEpoch,
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
          completionTimeMilliseconds: const Duration(
            minutes: 30,
          ).inMilliseconds,
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
    },
  );
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
