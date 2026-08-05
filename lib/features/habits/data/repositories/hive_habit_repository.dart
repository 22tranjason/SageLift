import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/habit.dart';
import '../../domain/repositories/habit_repository.dart';
import '../mappers/habit_hive_mapper.dart';
import '../models/habit_hive_model.dart';

/// Hive-backed implementation of [HabitRepository].
class HiveHabitRepository implements HabitRepository {
  /// Creates a repository over the supplied typed habit box.
  const HiveHabitRepository(this._box);

  final Box<HabitHiveModel> _box;

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<List<Habit>> getActive() async {
    return _box.values
        .where((HabitHiveModel habit) => habit.isActive)
        .map((HabitHiveModel habit) => habit.toDomain())
        .toList(growable: false);
  }

  @override
  Future<List<Habit>> getAll() async {
    return _box.values
        .map((HabitHiveModel habit) => habit.toDomain())
        .toList(growable: false);
  }

  @override
  Future<Habit?> getById(String id) async => _box.get(id)?.toDomain();

  @override
  Future<void> save(Habit habit) => _box.put(habit.id, habit.toHiveModel());
}
