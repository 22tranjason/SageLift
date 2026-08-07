import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/features/workouts/data/adapters/workout_hive_adapters.dart';
import 'package:sagelift/features/workouts/data/local/workout_hive_store.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_exercise_repository.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_workout_repository.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
import 'package:sagelift/features/workouts/domain/models/conditioning.dart';
import 'package:sagelift/features/workouts/domain/models/exercise.dart';
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

  test('persists workout data and seeds an empty database once', () async {
    final WorkoutHiveStore store = await WorkoutHiveStore.open();
    final HiveExerciseRepository exerciseRepository = HiveExerciseRepository(
      store.exerciseBox,
    );
    final HiveWorkoutRepository workoutRepository = HiveWorkoutRepository(
      store.workoutBox,
    );

    await WorkoutSeedService(
      exerciseRepository: exerciseRepository,
      workoutRepository: workoutRepository,
    ).seedIfEmpty();

    final List<Exercise> exercises = await exerciseRepository.getAll();
    final List<Workout> workouts = await workoutRepository.getAll();

    expect(exercises, hasLength(48));
    expect(workouts, hasLength(12));
    expect(
      workouts
          .where((Workout workout) => workout.track == WorkoutTrack.crossFit),
      hasLength(6),
    );
    expect(
      workouts
          .singleWhere((Workout workout) => workout.name == 'CrossFit A')
          .conditioningPlan
          ?.prescribedRounds,
      4,
    );
    expect(
      exercises.map((Exercise exercise) => exercise.name),
      isNot(contains('Machine Chest Press')),
    );
    expect(
      exercises.map((Exercise exercise) => exercise.name),
      isNot(contains('Cable Lateral Raise')),
    );

    for (final _ExpectedWorkout expectedWorkout in _expectedWorkouts) {
      final Workout workout = workouts.singleWhere(
        (Workout candidate) => candidate.name == expectedWorkout.name,
      );
      expect(workout.id, expectedWorkout.id);
      expect(
        workout.exerciseIds,
        equals(
          expectedWorkout.prescriptions
              .map(
                (_ExpectedPrescription prescription) => prescription.exerciseId,
              )
              .toList(growable: false),
        ),
      );
      expect(
        workout.sets,
        hasLength(
          expectedWorkout.prescriptions.fold<int>(
            0,
            (int total, _ExpectedPrescription prescription) =>
                total + prescription.setCount,
          ),
        ),
      );

      for (final _ExpectedPrescription prescription
          in expectedWorkout.prescriptions) {
        final List<WorkoutSet> sets = workout.sets
            .where(
              (WorkoutSet set) => set.exerciseId == prescription.exerciseId,
            )
            .toList(growable: false);
        expect(sets, hasLength(prescription.setCount));
        expect(
          sets.map((WorkoutSet set) => set.setNumber),
          equals(
            List<int>.generate(
              prescription.setCount,
              (int index) => index + 1,
            ),
          ),
        );
        expect(
          sets.map((WorkoutSet set) => set.targetReps),
          everyElement(equals(prescription.targetReps)),
        );
        expect(
          sets.map((WorkoutSet set) => set.notes),
          everyElement(equals(prescription.notes)),
        );
      }
    }

    await WorkoutSeedService(
      exerciseRepository: exerciseRepository,
      workoutRepository: workoutRepository,
    ).seedIfEmpty();

    expect(await workoutRepository.getAll(), hasLength(12));

    const Exercise exercise = Exercise(
      id: 'exercise-1',
      name: 'Test press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    final Workout workout = Workout(
      id: 'workout-1',
      name: 'Test workout',
      scheduledDate: DateTime.utc(2026, 7, 30),
      status: WorkoutStatus.planned,
      exerciseIds: const <String>['exercise-1'],
      sets: const <WorkoutSet>[
        WorkoutSet(
          id: 'set-1',
          exerciseId: 'exercise-1',
          setNumber: 1,
          status: WorkoutSetStatus.planned,
          targetReps: 8,
        ),
      ],
    );

    await exerciseRepository.save(exercise);
    await workoutRepository.save(workout);

    expect(await exerciseRepository.getById(exercise.id), exercise);
    expect(await exerciseRepository.searchByName('PRESS'), contains(exercise));
    expect(await workoutRepository.getById(workout.id), workout);
    expect(
      await workoutRepository.getForDate(DateTime(2026, 7, 30, 18)),
      contains(workout),
    );
  });

  test('persists completed workout records with their recorded sets', () async {
    final WorkoutHiveStore store = await WorkoutHiveStore.open();
    final HiveWorkoutRepository workoutRepository = HiveWorkoutRepository(
      store.workoutBox,
    );
    final DateTime startedAt = DateTime.utc(2026, 7, 30, 6, 15);
    final DateTime completedAt = DateTime.utc(2026, 7, 30, 7, 5);
    final Workout completedWorkout = Workout(
      id: 'completed-workout-1',
      name: 'Completed workout',
      scheduledDate: DateTime.utc(2026, 7, 30),
      status: WorkoutStatus.completed,
      exerciseIds: const <String>['exercise-1'],
      sets: const <WorkoutSet>[
        WorkoutSet(
          id: 'completed-set-1',
          exerciseId: 'exercise-1',
          setNumber: 1,
          weightKg: 80,
          reps: 10,
          targetReps: 10,
          status: WorkoutSetStatus.completed,
        ),
      ],
      startedAt: startedAt,
      completedAt: completedAt,
    );

    await workoutRepository.save(completedWorkout);

    expect(
      await workoutRepository.getById(completedWorkout.id),
      completedWorkout,
    );

    await store.workoutBox.close();
    final WorkoutHiveStore reopenedStore = await WorkoutHiveStore.open();
    final HiveWorkoutRepository reopenedRepository = HiveWorkoutRepository(
      reopenedStore.workoutBox,
    );
    expect(
      await reopenedRepository.getById(completedWorkout.id),
      completedWorkout,
    );
  });

  test('persists incomplete CrossFit conditioning results', () async {
    final WorkoutHiveStore store = await WorkoutHiveStore.open();
    final HiveWorkoutRepository repository = HiveWorkoutRepository(
      store.workoutBox,
    );
    final Workout workout = Workout(
      id: 'crossfit-result',
      name: 'CrossFit A',
      scheduledDate: DateTime.utc(2026, 8, 8),
      status: WorkoutStatus.completed,
      track: WorkoutTrack.crossFit,
      completedAt: DateTime.utc(2026, 8, 8, 7),
      conditioningPlan: const ConditioningPlan(
        format: ConditioningFormat.roundsForTime,
        title: '4 rounds for time',
        instructions: 'Test movements',
        prescribedRounds: 4,
      ),
      conditioningResult: const ConditioningResult(
        roundsCompleted: 3,
        additionalReps: 12,
        completionTime: Duration(minutes: 18, seconds: 42),
        weightKg: 10,
        scaling: 'Step-ups and band-assisted pull-ups',
        isCompleted: false,
      ),
    );

    await repository.save(workout);

    expect(await repository.getById(workout.id), workout);
  });
}

const List<_ExpectedWorkout> _expectedWorkouts = <_ExpectedWorkout>[
  _ExpectedWorkout(
    id: 'seed-workout-push-a',
    name: 'Push A',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-barbell-bench-press', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-incline-dumbbell-press', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-seated-dumbbell-shoulder-press', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-dumbbell-lateral-raise', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-cable-triceps-pushdown', 15,
          'Target 10–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-overhead-rope-triceps-extension', 15,
          'Target 10-15 reps; rest 60-90 sec',
          setCount: 1),
    ],
  ),
  _ExpectedWorkout(
    id: 'seed-workout-pull-a',
    name: 'Pull A',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-barbell-bent-over-row', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-one-arm-dumbbell-row', 12,
          'Target 8–12 reps per side; rest 90 sec'),
      _ExpectedPrescription('seed-exercise-cable-lat-pulldown', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-dumbbell-rear-delt-fly', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-dumbbell-hammer-curl', 15,
          'Target 10–15 reps; rest 60–90 sec'),
    ],
  ),
  _ExpectedWorkout(
    id: 'seed-workout-legs-a',
    name: 'Legs A',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-barbell-back-squat', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-romanian-deadlift', 12,
          'Target 8–12 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-dumbbell-reverse-lunge', 12,
          'Target 8–12 reps per leg; rest 90 sec'),
      _ExpectedPrescription('seed-exercise-standing-dumbbell-calf-raise', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription(
          'seed-exercise-plank', 45, 'Hold for 30–45 seconds; rest 60 sec'),
    ],
  ),
  _ExpectedWorkout(
    id: 'seed-workout-push-b',
    name: 'Push B',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-incline-barbell-bench-press', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-flat-dumbbell-bench-press', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-standing-barbell-overhead-press', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-dumbbell-lateral-raise', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-overhead-dumbbell-triceps-extension',
          15, 'Target 10–15 reps; rest 60–90 sec'),
    ],
  ),
  _ExpectedWorkout(
    id: 'seed-workout-pull-b',
    name: 'Pull B',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-conventional-deadlift', 8,
          'Target 5–8 reps; rest 3 min'),
      _ExpectedPrescription('seed-exercise-chest-supported-dumbbell-row', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription(
          'seed-exercise-cable-seated-row', 12, 'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-cable-face-pull', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-alternating-dumbbell-curl', 15,
          'Target 10–15 reps per arm; rest 60–90 sec'),
    ],
  ),
  _ExpectedWorkout(
    id: 'seed-workout-legs-b',
    name: 'Legs B',
    prescriptions: <_ExpectedPrescription>[
      _ExpectedPrescription('seed-exercise-barbell-front-squat', 10,
          'Target 6–10 reps; rest 2–3 min'),
      _ExpectedPrescription('seed-exercise-barbell-hip-thrust', 12,
          'Target 8–12 reps; rest 2 min'),
      _ExpectedPrescription('seed-exercise-dumbbell-bulgarian-split-squat', 12,
          'Target 8–12 reps per leg; rest 90 sec'),
      _ExpectedPrescription('seed-exercise-standing-dumbbell-calf-raise', 15,
          'Target 12–15 reps; rest 60–90 sec'),
      _ExpectedPrescription('seed-exercise-lying-leg-raise', 15,
          'Target 10–15 reps; rest 60 sec'),
    ],
  ),
];

class _ExpectedWorkout {
  const _ExpectedWorkout({
    required this.id,
    required this.name,
    required this.prescriptions,
  });

  final String id;
  final String name;
  final List<_ExpectedPrescription> prescriptions;
}

class _ExpectedPrescription {
  const _ExpectedPrescription(
    this.exerciseId,
    this.targetReps,
    this.notes, {
    this.setCount = 3,
  });

  final String exerciseId;
  final int targetReps;
  final String notes;
  final int setCount;
}
