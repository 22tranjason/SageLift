import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';

/// Supplies the workout repository to workout presentation code.
final Provider<WorkoutRepository> workoutRepositoryProvider =
    Provider<WorkoutRepository>((Ref ref) {
  throw UnimplementedError(
      'WorkoutRepository must be provided during bootstrap.');
});

/// Supplies the exercise repository to workout presentation code.
final Provider<ExerciseRepository> exerciseRepositoryProvider =
    Provider<ExerciseRepository>((Ref ref) {
  throw UnimplementedError(
      'ExerciseRepository must be provided during bootstrap.');
});

/// Loads the workout and ordered exercise list to show on the Today screen.
final FutureProvider<TodayWorkout?> todayWorkoutProvider =
    FutureProvider<TodayWorkout?>((Ref ref) async {
  final WorkoutRepository workoutRepository = ref.watch(
    workoutRepositoryProvider,
  );
  final ExerciseRepository exerciseRepository = ref.watch(
    exerciseRepositoryProvider,
  );
  final List<Workout> scheduledWorkouts = await workoutRepository.getForDate(
    DateTime.now(),
  );
  final List<Workout> availableWorkouts = scheduledWorkouts.isNotEmpty
      ? scheduledWorkouts
      : await workoutRepository.getAll();
  if (availableWorkouts.isEmpty) return null;

  final Workout workout = availableWorkouts.first;
  final List<Exercise> exercises = <Exercise>[];
  for (final String exerciseId in workout.exerciseIds) {
    final Exercise? exercise = await exerciseRepository.getById(exerciseId);
    if (exercise != null) exercises.add(exercise);
  }
  return TodayWorkout(workout: workout, exercises: exercises);
});

/// Presentation-ready workout data with exercises retained in workout order.
class TodayWorkout {
  /// Creates Today data from a workout and its resolved exercises.
  TodayWorkout({required this.workout, required List<Exercise> exercises})
      : _exercises = List<Exercise>.unmodifiable(exercises);

  /// Workout selected for the current day.
  final Workout workout;

  final List<Exercise> _exercises;

  /// Catalogue exercises in the order defined by [workout].
  List<Exercise> get exercises => _exercises;
}
