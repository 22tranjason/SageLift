/// Hive-specific representation of a recurring habit definition.
class HabitHiveModel {
  /// Creates a persistence representation of a habit.
  HabitHiveModel({
    required this.id,
    required this.name,
    required this.targetTypeIndex,
    required this.targetValue,
    required this.unitIndex,
    required List<int> activeDayIndexes,
    required this.isActive,
  }) : activeDayIndexes = List<int>.unmodifiable(activeDayIndexes);

  /// Stable key for the habit record.
  final String id;

  /// Habit name shown to the user.
  final String name;

  /// Persisted index of the target-type enum.
  final int targetTypeIndex;

  /// Numeric target for an active day.
  final double targetValue;

  /// Persisted index of the unit enum.
  final int unitIndex;

  /// Persisted indexes of applicable weekdays.
  final List<int> activeDayIndexes;

  /// Whether the habit remains available for completion.
  final bool isActive;
}
