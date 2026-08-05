import '../models/workout.dart';
import '../models/workout_set.dart';

/// Calculates factual post-workout inputs for future adaptive coaching.
class WorkoutCompletionInsightsService {
  /// Creates a completion-insights calculator.
  const WorkoutCompletionInsightsService();

  /// Builds coaching inputs from a completed [workout] without persisting
  /// derived values.
  WorkoutCompletionInsights analyze(Workout workout) {
    final List<WorkoutSet> completedSets = workout.sets
        .where((WorkoutSet set) => set.status == WorkoutSetStatus.completed)
        .toList(growable: false);
    final List<WorkoutSet> skippedSets = workout.sets
        .where((WorkoutSet set) => set.status == WorkoutSetStatus.skipped)
        .toList(growable: false);
    final Set<String> completedExerciseIds =
        completedSets.map((WorkoutSet set) => set.exerciseId).toSet();
    final List<String> skippedExerciseIds = workout.exerciseIds
        .where((String id) => !completedExerciseIds.contains(id))
        .toList(growable: false);
    final DateTime endedAt =
        workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
    final DateTime startedAt = workout.startedAt ?? endedAt;
    final int totalSets = workout.sets.length;

    return WorkoutCompletionInsights(
      duration: endedAt.difference(startedAt),
      skippedExerciseIds: skippedExerciseIds,
      skippedSets: skippedSets.length,
      skippedReps: skippedSets.fold<int>(
        0,
        (int total, WorkoutSet set) => total + (set.targetReps ?? 0),
      ),
      completedPercentage:
          totalSets == 0 ? 0 : (completedSets.length / totalSets) * 100,
    );
  }
}

/// Factual completion data that a future coaching feature can consume.
class WorkoutCompletionInsights {
  /// Creates immutable coaching inputs for one completed workout.
  WorkoutCompletionInsights({
    required this.duration,
    required List<String> skippedExerciseIds,
    required this.skippedSets,
    required this.skippedReps,
    required this.completedPercentage,
  }) : _skippedExerciseIds = List<String>.unmodifiable(skippedExerciseIds);

  /// Elapsed time between the recorded workout start and finish.
  final Duration duration;

  final List<String> _skippedExerciseIds;

  /// Exercises for which no sets were completed.
  List<String> get skippedExerciseIds => _skippedExerciseIds;

  /// Number of prescribed sets skipped during the completed workout.
  final int skippedSets;

  /// Sum of prescribed repetitions for skipped sets with targets.
  final int skippedReps;

  /// Percentage of prescribed sets that were completed.
  final double completedPercentage;
}
