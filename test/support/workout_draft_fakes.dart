import 'dart:async';

import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/domain/models/conditioning.dart';
import 'package:sagelift/features/workouts/domain/models/exercise.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/repositories/exercise_repository.dart';
import 'package:sagelift/features/workouts/domain/repositories/workout_repository.dart';

/// Local storage with controllable write failures and latency.
class DraftMemoryStore implements KeyValueStore {
  /// Stored values survive recreation of providers and repository objects.
  final Map<String, Object?> values = <String, Object?>{};

  /// When set, writes fail without altering existing data.
  bool failWrites = false;

  /// Optional gate allowing tests to check reload/write ordering.
  Completer<void>? writeGate;

  @override
  Future<void> initialize() async {}

  @override
  Future<T?> read<T>(String key) async => values[key] as T?;

  @override
  Future<void> write<T>(String key, T value) async {
    await writeGate?.future;
    if (failWrites) throw StateError('Storage write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Shared prescription for timer and movement entry tests.
final ConditioningPlan draftTestPlan = ConditioningPlan(
  format: ConditioningFormat.roundsForTime,
  title: 'Three rounds',
  instructions: 'Complete the circuit.',
  prescribedRounds: 3,
  movements: const <ConditioningMovement>[
    ConditioningMovement(
        id: 'snatch', name: 'Dumbbell snatch', prescribedReps: 10),
    ConditioningMovement(id: 'squat', name: 'Goblet squat', prescribedReps: 12),
  ],
);

/// Minimal session containing both strength and conditioning.
Workout draftTestWorkout({
  String id = 'push',
  String name = 'Push A Hybrid',
  WorkoutStatus status = WorkoutStatus.inProgress,
  WorkoutTrack track = WorkoutTrack.crossFit,
}) =>
    Workout(
      id: id,
      name: name,
      scheduledDate: DateTime.utc(2026, 9, 21),
      status: status,
      track: track,
      exerciseIds: const <String>['press'],
      sets: <WorkoutSet>[
        WorkoutSet(
          id: 'set-1',
          exerciseId: 'press',
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
        ),
      ],
      conditioningPlan: draftTestPlan,
    );

/// Workout repository that can fail or delay completed-history persistence.
class DraftWorkoutRepository implements WorkoutRepository {
  /// Creates a repository with independently addressable sessions.
  DraftWorkoutRepository(List<Workout> workouts)
      : values = <String, Workout>{for (final Workout w in workouts) w.id: w};

  /// Stored sessions.
  final Map<String, Workout> values;

  /// Simulates a failed completed-history write.
  bool failCompletion = false;

  /// Blocks completed-history writes until explicitly released.
  Completer<void>? completionGate;

  @override
  Future<List<Workout>> getAll() async => values.values.toList();

  @override
  Future<Workout?> getById(String id) async => values[id];

  @override
  Future<List<Workout>> getForDate(DateTime date) async =>
      values.values.where((Workout w) => w.scheduledDate == date).toList();

  @override
  Future<void> save(Workout workout) async {
    if (workout.status == WorkoutStatus.completed) {
      await completionGate?.future;
      if (failCompletion) throw StateError('Completed write failed');
    }
    values[workout.id] = workout;
  }

  @override
  Future<void> delete(String id) async => values.remove(id);
}

/// Minimal catalogue for exercise-screen tests.
class DraftExerciseRepository implements ExerciseRepository {
  static const Exercise _exercise = Exercise(
    id: 'press',
    name: 'Press',
    category: ExerciseCategory.strength,
    equipment: Equipment.barbell,
  );

  @override
  Future<List<Exercise>> getAll() async => <Exercise>[_exercise];

  @override
  Future<Exercise?> getById(String id) async =>
      id == _exercise.id ? _exercise : null;

  @override
  Future<List<Exercise>> searchByName(String query) => getAll();

  @override
  Future<void> save(Exercise exercise) async {}

  @override
  Future<void> delete(String id) async {}
}
