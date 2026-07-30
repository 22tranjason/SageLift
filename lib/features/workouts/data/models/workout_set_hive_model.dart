/// Hive-specific representation of one set within a workout.
class WorkoutSetHiveModel {
  /// Creates a persistence representation of a workout set.
  const WorkoutSetHiveModel({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.statusIndex,
    this.weightKg,
    this.reps,
    this.targetWeightKg,
    this.targetReps,
    this.rpe,
    this.notes,
  });

  /// Stable identifier for the set.
  final String id;

  /// Identifier of the referenced exercise.
  final String exerciseId;

  /// One-based position for this set within its exercise.
  final int setNumber;

  /// Actual external load in kilograms, when recorded.
  final double? weightKg;

  /// Actual repetitions, when recorded.
  final int? reps;

  /// Planned external load in kilograms, when recorded.
  final double? targetWeightKg;

  /// Planned repetitions, when recorded.
  final int? targetReps;

  /// Persisted index of the workout-set status enum.
  final int statusIndex;

  /// Rate of perceived exertion, when recorded.
  final double? rpe;

  /// Optional notes for the set.
  final String? notes;
}
