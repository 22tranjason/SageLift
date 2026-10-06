import '../models/workout.dart';
import '../models/workout_set.dart';

/// Finds the latest completed session with recorded sets for an exercise.
/// Historical views exclude the viewed session, later sessions, and ambiguous
/// equal timestamps. New and active sessions use the latest completed result.
Workout? previousExerciseWorkout({
  required Iterable<Workout> workouts,
  required String exerciseId,
  Workout? viewedWorkout,
}) {
  final DateTime? before = viewedWorkout?.status == WorkoutStatus.completed
      ? _completionDate(viewedWorkout!)
      : null;
  final List<Workout> candidates = workouts
      .where((Workout workout) =>
          workout.status == WorkoutStatus.completed &&
          workout.id != viewedWorkout?.id &&
          (before == null || _completionDate(workout).isBefore(before)) &&
          workout.sets.any((WorkoutSet set) =>
              set.exerciseId == exerciseId &&
              set.status == WorkoutSetStatus.completed))
      .toList();
  candidates.sort((Workout first, Workout second) {
    final int date = _completionDate(second).compareTo(_completionDate(first));
    return date == 0 ? first.id.compareTo(second.id) : date;
  });
  return candidates.isEmpty ? null : candidates.first;
}

DateTime _completionDate(Workout workout) =>
    workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
