/// Hive-specific representation of an exercise catalogue entry.
class ExerciseHiveModel {
  /// Creates a persistence representation of an exercise.
  const ExerciseHiveModel({
    required this.id,
    required this.name,
    required this.categoryIndex,
    required this.equipmentIndex,
    required this.isArchived,
    this.primaryMuscleGroupIndex,
    this.instructions,
    this.notes,
  });

  /// Stable identifier used as the Hive box key.
  final String id;

  /// Stored exercise name.
  final String name;

  /// Persisted index of the domain exercise category enum.
  final int categoryIndex;

  /// Persisted index of the optional primary muscle group enum.
  final int? primaryMuscleGroupIndex;

  /// Persisted index of the domain equipment enum.
  final int equipmentIndex;

  /// Optional stored exercise instructions.
  final String? instructions;

  /// Optional stored personal notes.
  final String? notes;

  /// Whether the exercise is archived.
  final bool isArchived;
}
