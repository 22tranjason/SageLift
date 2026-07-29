import '../models/challenge.dart';

/// Contract for offline storage and retrieval of challenge aggregates.
abstract interface class ChallengeRepository {
  /// Returns every stored challenge.
  Future<List<Challenge>> getAll();

  /// Returns challenges currently in the active lifecycle state.
  Future<List<Challenge>> getActive();

  /// Returns the challenge with [id], or null when no matching record exists.
  Future<Challenge?> getById(String id);

  /// Inserts [challenge] or replaces the existing record with the same stable ID.
  Future<void> save(Challenge challenge);

  /// Deletes the challenge with [id].
  ///
  /// This operation is idempotent and succeeds when no matching record exists.
  Future<void> delete(String id);
}
