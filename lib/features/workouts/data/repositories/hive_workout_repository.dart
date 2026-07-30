import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../mappers/workout_hive_mapper.dart';
import '../models/workout_hive_model.dart';

/// Hive-backed implementation of [WorkoutRepository].
class HiveWorkoutRepository implements WorkoutRepository {
  /// Creates a repository over the supplied typed workout box.
  const HiveWorkoutRepository(this._box);

  final Box<WorkoutHiveModel> _box;

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<List<Workout>> getAll() async {
    return _box.values
        .map((WorkoutHiveModel workout) => workout.toDomain())
        .toList(growable: false);
  }

  @override
  Future<Workout?> getById(String id) async => _box.get(id)?.toDomain();

  @override
  Future<List<Workout>> getForDate(DateTime date) async {
    return _box.values
        .map((WorkoutHiveModel workout) => workout.toDomain())
        .where((Workout workout) =>
            _isSameCalendarDay(workout.scheduledDate, date))
        .toList(growable: false);
  }

  @override
  Future<void> save(Workout workout) =>
      _box.put(workout.id, workout.toHiveModel());

  bool _isSameCalendarDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
