import '../models/habit.dart';

/// Contract for offline storage and retrieval of habit definitions.
abstract interface class HabitRepository {
  /// Returns every stored habit, including inactive habits.
  Future<List<Habit>> getAll();

  /// Returns habits currently available for new daily check-ins.
  Future<List<Habit>> getActive();

  /// Returns the habit with [id], or null when no matching record exists.
  Future<Habit?> getById(String id);

  /// Inserts [habit] or replaces the existing record with the same stable ID.
  Future<void> save(Habit habit);

  /// Deletes the habit with [id].
  ///
  /// This operation is idempotent and succeeds when no matching record exists.
  Future<void> delete(String id);
}
