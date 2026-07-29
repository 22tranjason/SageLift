import '../models/exercise.dart';

/// Contract for offline storage and retrieval of exercise catalogue entries.
abstract interface class ExerciseRepository {
  /// Returns every stored exercise, including archived entries.
  Future<List<Exercise>> getAll();

  /// Returns the exercise with [id], or null when no matching record exists.
  Future<Exercise?> getById(String id);

  /// Returns exercises whose names match [query].
  Future<List<Exercise>> searchByName(String query);

  /// Inserts [exercise] or replaces the existing record with the same stable ID.
  Future<void> save(Exercise exercise);

  /// Deletes the exercise with [id].
  ///
  /// This operation is idempotent and succeeds when no matching record exists.
  Future<void> delete(String id);
}
