import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/features/workouts/data/adapters/workout_hive_adapters.dart';
import 'package:sagelift/features/workouts/data/local/workout_hive_store.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_exercise_repository.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_workout_repository.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
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

    expect(await exerciseRepository.getAll(), hasLength(9));
    expect(await workoutRepository.getAll(), hasLength(6));

    await WorkoutSeedService(
      exerciseRepository: exerciseRepository,
      workoutRepository: workoutRepository,
    ).seedIfEmpty();

    expect(await workoutRepository.getAll(), hasLength(6));

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
}
