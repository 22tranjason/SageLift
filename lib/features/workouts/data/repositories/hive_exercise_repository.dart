import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../mappers/exercise_hive_mapper.dart';
import '../models/exercise_hive_model.dart';

/// Hive-backed implementation of [ExerciseRepository].
class HiveExerciseRepository implements ExerciseRepository {
  /// Creates a repository over the supplied typed exercise box.
  const HiveExerciseRepository(this._box);

  final Box<ExerciseHiveModel> _box;

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<List<Exercise>> getAll() async {
    return _box.values
        .map((ExerciseHiveModel exercise) => exercise.toDomain())
        .toList(growable: false);
  }

  @override
  Future<List<Exercise>> searchByName(String query) async {
    final String normalizedQuery = query.trim().toLowerCase();
    return _box.values
        .where((ExerciseHiveModel exercise) {
          return exercise.name.toLowerCase().contains(normalizedQuery);
        })
        .map((ExerciseHiveModel exercise) => exercise.toDomain())
        .toList(growable: false);
  }

  @override
  Future<Exercise?> getById(String id) async => _box.get(id)?.toDomain();

  @override
  Future<void> save(Exercise exercise) =>
      _box.put(exercise.id, exercise.toHiveModel());
}
