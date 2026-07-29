/// The recording state of one planned or performed set.
enum WorkoutSetStatus {
  /// The set has not yet been performed.
  planned,

  /// The set was completed and its result may be recorded.
  completed,

  /// The set was deliberately skipped.
  skipped,
}

/// One planned or performed set within a workout.
class WorkoutSet {
  /// Creates an immutable workout set.
  const WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    required this.status,
    this.weightKg,
    this.reps,
    this.targetWeightKg,
    this.targetReps,
    this.rpe,
    this.notes,
  });

  /// Stable, client-generated identifier for this set.
  final String id;

  /// Identifier of the catalogue [Exercise] performed for this set.
  final String exerciseId;

  /// One-based position of this set among the exercise's sets in a workout.
  final int setNumber;

  /// Actual external load in kilograms; null supports bodyweight or unperformed sets.
  final double? weightKg;

  /// Actual completed repetitions; null when not yet recorded or not applicable.
  final int? reps;

  /// Optional planned external load in kilograms.
  final double? targetWeightKg;

  /// Optional planned repetition count.
  final int? targetReps;

  /// Completion state for the individual set.
  final WorkoutSetStatus status;

  /// Optional rate of perceived exertion, commonly on a 1–10 scale.
  final double? rpe;

  /// Optional notes specific to this set.
  final String? notes;

  static const Object _unset = Object();

  /// Returns this set with selected values replaced.
  ///
  /// Pass `null` to any nullable argument to intentionally clear that field.
  WorkoutSet copyWith({
    String? id,
    String? exerciseId,
    int? setNumber,
    Object? weightKg = _unset,
    Object? reps = _unset,
    Object? targetWeightKg = _unset,
    Object? targetReps = _unset,
    WorkoutSetStatus? status,
    Object? rpe = _unset,
    Object? notes = _unset,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      weightKg:
          identical(weightKg, _unset) ? this.weightKg : weightKg as double?,
      reps: identical(reps, _unset) ? this.reps : reps as int?,
      targetWeightKg: identical(targetWeightKg, _unset)
          ? this.targetWeightKg
          : targetWeightKg as double?,
      targetReps:
          identical(targetReps, _unset) ? this.targetReps : targetReps as int?,
      status: status ?? this.status,
      rpe: identical(rpe, _unset) ? this.rpe : rpe as double?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkoutSet &&
        other.id == id &&
        other.exerciseId == exerciseId &&
        other.setNumber == setNumber &&
        other.weightKg == weightKg &&
        other.reps == reps &&
        other.targetWeightKg == targetWeightKg &&
        other.targetReps == targetReps &&
        other.status == status &&
        other.rpe == rpe &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        id,
        exerciseId,
        setNumber,
        weightKg,
        reps,
        targetWeightKg,
        targetReps,
        status,
        rpe,
        notes,
      );
}
