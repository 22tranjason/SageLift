import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_program.dart';

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

/// Changes whenever workout persistence mutates, refreshing dependent views.
final StateProvider<int> workoutDataRevisionProvider = StateProvider<int>(
  (Ref ref) => 0,
);

/// Loads the active or next planned programme workout for the Today screen.
final FutureProvider<TodayWorkout?> todayWorkoutProvider =
    FutureProvider<TodayWorkout?>((Ref ref) async {
  ref.watch(workoutDataRevisionProvider);
  final WorkoutRepository workoutRepository = ref.watch(
    workoutRepositoryProvider,
  );
  final ExerciseRepository exerciseRepository = ref.watch(
    exerciseRepositoryProvider,
  );
  final List<Workout> workouts = await workoutRepository.getAll();
  final Workout? workout = WorkoutProgram.nextIncompleteWorkout(workouts);
  if (workout == null) return null;
  final List<Exercise> exercises = <Exercise>[];
  for (final String exerciseId in workout.exerciseIds) {
    final Exercise? exercise = await exerciseRepository.getById(exerciseId);
    if (exercise != null) exercises.add(exercise);
  }
  return TodayWorkout(
    workout: workout,
    exercises: exercises,
    isRecommended: workout.status != WorkoutStatus.inProgress,
    recommendedWorkoutName: WorkoutProgram.recommendedNextWorkoutName(workouts),
  );
});

/// Loads the most recently completed workout for the Today screen.
final FutureProvider<Workout?> lastCompletedWorkoutProvider =
    FutureProvider<Workout?>((Ref ref) async {
  ref.watch(workoutDataRevisionProvider);
  final WorkoutRepository workoutRepository = ref.watch(
    workoutRepositoryProvider,
  );
  final List<Workout> completedWorkouts = (await workoutRepository.getAll())
      .where((Workout workout) => workout.status == WorkoutStatus.completed)
      .toList()
    ..sort(_compareByCompletionDateDescending);
  return completedWorkouts.isEmpty ? null : completedWorkouts.first;
});

int _compareByCompletionDateDescending(Workout first, Workout second) {
  return _completionDate(second).compareTo(_completionDate(first));
}

DateTime _completionDate(Workout workout) {
  return workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
}

/// Presentation-ready workout data with exercises retained in workout order.
class TodayWorkout {
  /// Creates Today data from a workout and its resolved exercises.
  TodayWorkout({
    required this.workout,
    required List<Exercise> exercises,
    required this.isRecommended,
    required this.recommendedWorkoutName,
  }) : _exercises = List<Exercise>.unmodifiable(exercises);

  /// Workout selected for the current day.
  final Workout workout;

  /// Whether [workout] is the automatic program recommendation rather than an
  /// already active manually selected session.
  final bool isRecommended;

  /// Program name inferred solely from the latest valid completion.
  final String recommendedWorkoutName;

  final List<Exercise> _exercises;

  /// Catalogue exercises in the order defined by [workout].
  List<Exercise> get exercises => _exercises;
}
