import '../models/workout.dart';

/// Contract for offline storage and retrieval of workout aggregates.
abstract interface class WorkoutRepository {
  /// Returns every stored workout.
  Future<List<Workout>> getAll();

  /// Returns the workout with [id], or null when no matching record exists.
  Future<Workout?> getById(String id);

  /// Returns workouts scheduled on the calendar day represented by [date].
  ///
  /// Implementations compare calendar days and ignore the time-of-day component.
  Future<List<Workout>> getForDate(DateTime date);

  /// Inserts [workout] or replaces the existing record with the same stable ID.
  Future<void> save(Workout workout);

  /// Deletes the workout with [id].
  ///
  /// This operation is idempotent and succeeds when no matching record exists.
  Future<void> delete(String id);
}
