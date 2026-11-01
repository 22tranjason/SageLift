import '../models/workout.dart';
import '../models/workout_set.dart';

/// One completed session, retaining actual sets behind its chart point.
class ExerciseProgressPoint {
  /// Creates a session point without persisting derived statistics.
  const ExerciseProgressPoint(
      this.workout, this.date, this.sets, this.weightKg);

  /// Factual source session.
  final Workout workout;

  /// Completion date, falling back to start/scheduled dates for legacy records.
  final DateTime date;

  /// Actual completed sets, including explicitly marked warm-up sets for detail.
  final List<WorkoutSet> sets;

  /// Heaviest recorded non-warm-up set load; null means no plottable load.
  final double? weightKg;
}

/// Builds an all-history load series without ranking performance or mixing IDs.
class ExerciseProgressHistory {
  ExerciseProgressHistory._();

  /// Only explicit leading warm-up labels are recognised; no load inference.
  static bool isWarmUp(WorkoutSet set) =>
      RegExp(r'^warm[- ]?up\b', caseSensitive: false)
          .hasMatch(set.notes?.trim() ?? '');

  /// Includes all completed sessions with actual exercise entries, oldest first.
  static List<ExerciseProgressPoint> points(
      List<Workout> workouts, String exerciseId) {
    final List<ExerciseProgressPoint> result = <ExerciseProgressPoint>[];
    for (final Workout workout in workouts) {
      if (workout.status != WorkoutStatus.completed) continue;
      final List<WorkoutSet> sets = workout.sets
          .where((WorkoutSet s) =>
              s.exerciseId == exerciseId &&
              s.status == WorkoutSetStatus.completed &&
              (s.weightKg != null || s.reps != null))
          .toList()
        ..sort(
            (WorkoutSet a, WorkoutSet b) => a.setNumber.compareTo(b.setNumber));
      if (sets.isEmpty) continue;
      final List<double> loads = sets
          .where((WorkoutSet s) => !isWarmUp(s))
          .map((WorkoutSet s) => s.weightKg)
          .whereType<double>()
          .where((double w) => w.isFinite && w >= 0)
          .toList();
      result.add(ExerciseProgressPoint(
          workout,
          (workout.completedAt ?? workout.startedAt ?? workout.scheduledDate)
              .toLocal(),
          List<WorkoutSet>.unmodifiable(sets),
          loads.isEmpty
              ? null
              : loads.reduce((double a, double b) => a > b ? a : b)));
    }
    result.sort((ExerciseProgressPoint a, ExerciseProgressPoint b) {
      final int byDate = a.date.compareTo(b.date);
      return byDate == 0 ? a.workout.id.compareTo(b.workout.id) : byDate;
    });
    return List<ExerciseProgressPoint>.unmodifiable(result);
  }
}
