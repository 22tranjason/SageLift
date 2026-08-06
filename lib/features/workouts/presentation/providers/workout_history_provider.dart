import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import 'today_workout_provider.dart';
import 'workout_completion_controller.dart';

/// Loads completed workouts sorted from most recently completed to oldest.
final FutureProvider<List<WorkoutHistoryItem>> completedWorkoutHistoryProvider =
    FutureProvider<List<WorkoutHistoryItem>>((Ref ref) async {
  ref.watch(workoutDataRevisionProvider);
  final WorkoutRepository workoutRepository = ref.watch(
    workoutRepositoryProvider,
  );
  final List<Workout> completedWorkouts = (await workoutRepository.getAll())
      .where((Workout workout) => workout.status == WorkoutStatus.completed)
      .toList()
    ..sort(_compareByCompletionDateDescending);

  return completedWorkouts
      .map(
        (Workout workout) => WorkoutHistoryItem(
          workout: workout,
          summary: WorkoutSummary.fromWorkout(
            workout: workout,
            exercises: const <Exercise>[],
          ),
        ),
      )
      .toList(growable: false);
});

/// Loads the details required to inspect one persisted completed workout.
final FutureProviderFamily<CompletedWorkoutDetails?, String>
    completedWorkoutDetailsProvider =
    FutureProvider.family<CompletedWorkoutDetails?, String>(
  (Ref ref, String workoutId) async {
    ref.watch(workoutDataRevisionProvider);
    final WorkoutRepository workoutRepository = ref.watch(
      workoutRepositoryProvider,
    );
    final ExerciseRepository exerciseRepository = ref.watch(
      exerciseRepositoryProvider,
    );
    final Workout? workout = await workoutRepository.getById(workoutId);
    if (workout == null || workout.status != WorkoutStatus.completed) {
      return null;
    }

    final List<Exercise> exercises = <Exercise>[];
    for (final String exerciseId in workout.exerciseIds) {
      final Exercise? exercise = await exerciseRepository.getById(exerciseId);
      if (exercise != null) exercises.add(exercise);
    }
    final Map<String, String> exerciseNamesById = <String, String>{
      for (final Exercise exercise in exercises) exercise.id: exercise.name,
    };
    final List<CompletedSetDetail> completedSets = workout.sets
        .where((WorkoutSet set) => set.status == WorkoutSetStatus.completed)
        .map(
          (WorkoutSet set) => CompletedSetDetail(
            exerciseName: exerciseNamesById[set.exerciseId] ?? set.exerciseId,
            set: set,
          ),
        )
        .toList(growable: false);

    return CompletedWorkoutDetails(
      summary: WorkoutSummary.fromWorkout(
        workout: workout,
        exercises: exercises,
      ),
      completedSets: completedSets,
    );
  },
);

/// Loads the latest persisted completed sets for an exercise.
final FutureProviderFamily<PreviousExercisePerformance?, String>
    previousExercisePerformanceProvider =
    FutureProvider.family<PreviousExercisePerformance?, String>(
  (Ref ref, String exerciseId) async {
    ref.watch(workoutDataRevisionProvider);
    final WorkoutRepository workoutRepository = ref.watch(
      workoutRepositoryProvider,
    );
    final List<Workout> completedWorkouts = (await workoutRepository.getAll())
        .where((Workout workout) => workout.status == WorkoutStatus.completed)
        .toList()
      ..sort(_compareByCompletionDateDescending);

    for (final Workout workout in completedWorkouts) {
      final List<WorkoutSet> completedSets = workout.sets
          .where(
            (WorkoutSet set) =>
                set.exerciseId == exerciseId &&
                set.status == WorkoutSetStatus.completed,
          )
          .toList(growable: false);
      if (completedSets.isNotEmpty) {
        return PreviousExercisePerformance(
          workout: workout,
          sets: completedSets,
        );
      }
    }
    return null;
  },
);

/// A completed workout and its calculated history-list statistics.
class WorkoutHistoryItem {
  /// Creates an item representing one persisted completed workout.
  const WorkoutHistoryItem({required this.workout, required this.summary});

  /// Persisted completed workout used as the source for history facts.
  final Workout workout;

  /// Calculated statistics displayed in the history list.
  final WorkoutSummary summary;
}

/// Complete persisted workout details for the history-detail screen.
class CompletedWorkoutDetails {
  /// Creates details from a summary and the recorded completed sets.
  CompletedWorkoutDetails({
    required this.summary,
    required List<CompletedSetDetail> completedSets,
  }) : _completedSets = List<CompletedSetDetail>.unmodifiable(completedSets);

  /// Calculated summary facts for the completed workout.
  final WorkoutSummary summary;

  final List<CompletedSetDetail> _completedSets;

  /// Recorded completed sets in their stored workout order.
  List<CompletedSetDetail> get completedSets => _completedSets;
}

/// One recorded set resolved with its display exercise name.
class CompletedSetDetail {
  /// Creates details for a completed [set].
  const CompletedSetDetail({required this.exerciseName, required this.set});

  /// Exercise name resolved from the persisted exercise catalogue.
  final String exerciseName;

  /// Recorded completed set values.
  final WorkoutSet set;
}

/// The most recent recorded completed sets for one exercise.
class PreviousExercisePerformance {
  /// Creates prior performance from its source [workout] and recorded [sets].
  PreviousExercisePerformance({
    required this.workout,
    required List<WorkoutSet> sets,
  }) : _sets = List<WorkoutSet>.unmodifiable(sets);

  /// Completed workout containing the previous exercise performance.
  final Workout workout;

  final List<WorkoutSet> _sets;

  /// Completed sets for the requested exercise, in their stored order.
  List<WorkoutSet> get sets => _sets;
}

int _compareByCompletionDateDescending(Workout first, Workout second) {
  return _completionDate(second).compareTo(_completionDate(first));
}

DateTime _completionDate(Workout workout) {
  return workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
}
