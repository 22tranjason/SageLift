import '../../domain/models/habit.dart';
import '../models/habit_hive_model.dart';

/// Converts habit persistence records into framework-independent models.
extension HabitHiveMapper on HabitHiveModel {
  /// Creates the equivalent [Habit].
  Habit toDomain() {
    return Habit(
      id: id,
      name: name,
      targetType: HabitTargetType.values[targetTypeIndex],
      targetValue: targetValue,
      unit: HabitUnit.values[unitIndex],
      activeDays:
          activeDayIndexes.map((int index) => Weekday.values[index]).toSet(),
      isActive: isActive,
    );
  }
}

/// Converts habit domain models into persistence records.
extension HabitDomainMapper on Habit {
  /// Creates the Hive-specific representation of this habit.
  HabitHiveModel toHiveModel() {
    return HabitHiveModel(
      id: id,
      name: name,
      targetTypeIndex: targetType.index,
      targetValue: targetValue,
      unitIndex: unit.index,
      activeDayIndexes: activeDays.map((Weekday day) => day.index).toList(),
      isActive: isActive,
    );
  }
}
