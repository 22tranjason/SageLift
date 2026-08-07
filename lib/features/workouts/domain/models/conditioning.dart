/// The conditioning format prescribed for a CrossFit workout.
enum ConditioningFormat {
  /// A fixed number of rounds completed as quickly as practical.
  roundsForTime,

  /// As many complete rounds and additional repetitions as possible.
  amrap,

  /// Work repeated at the start of each minute.
  emom,
}

/// The programmed conditioning section of a workout.
class ConditioningPlan {
  /// Creates an immutable conditioning prescription.
  const ConditioningPlan({
    required this.format,
    required this.title,
    required this.instructions,
    this.prescribedRounds,
    this.durationMinutes,
  });

  /// How the conditioning work is structured.
  final ConditioningFormat format;

  /// Short display label, such as `4 rounds for time`.
  final String title;

  /// Ordered movements and quantities for the conditioning work.
  final String instructions;

  /// Number of prescribed rounds when the format specifies one.
  final int? prescribedRounds;

  /// Time cap or prescribed duration for AMRAP and EMOM work.
  final int? durationMinutes;

  @override
  bool operator ==(Object other) {
    return other is ConditioningPlan &&
        other.format == format &&
        other.title == title &&
        other.instructions == instructions &&
        other.prescribedRounds == prescribedRounds &&
        other.durationMinutes == durationMinutes;
  }

  @override
  int get hashCode => Object.hash(
        format,
        title,
        instructions,
        prescribedRounds,
        durationMinutes,
      );
}

/// The factual result recorded for a conditioning section.
class ConditioningResult {
  /// Creates an immutable conditioning result.
  const ConditioningResult({
    required this.roundsCompleted,
    required this.additionalReps,
    required this.isCompleted,
    this.completionTime,
    this.weightKg,
    this.scaling,
  });

  /// Complete rounds performed, including zero for an honest unfinished result.
  final int roundsCompleted;

  /// Repetitions performed after the final complete round.
  final int additionalReps;

  /// Elapsed time when the user records a timed result.
  final Duration? completionTime;

  /// Optional load used during the conditioning section.
  final double? weightKg;

  /// Optional movement modification, such as band-assisted pull-ups.
  final String? scaling;

  /// Whether the prescribed conditioning work was fully completed.
  final bool isCompleted;

  static const Object _unset = Object();

  /// Returns this result with selected values replaced or nullable values cleared.
  ConditioningResult copyWith({
    int? roundsCompleted,
    int? additionalReps,
    bool? isCompleted,
    Object? completionTime = _unset,
    Object? weightKg = _unset,
    Object? scaling = _unset,
  }) {
    return ConditioningResult(
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      additionalReps: additionalReps ?? this.additionalReps,
      isCompleted: isCompleted ?? this.isCompleted,
      completionTime: identical(completionTime, _unset)
          ? this.completionTime
          : completionTime as Duration?,
      weightKg:
          identical(weightKg, _unset) ? this.weightKg : weightKg as double?,
      scaling: identical(scaling, _unset) ? this.scaling : scaling as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConditioningResult &&
        other.roundsCompleted == roundsCompleted &&
        other.additionalReps == additionalReps &&
        other.completionTime == completionTime &&
        other.weightKg == weightKg &&
        other.scaling == scaling &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode => Object.hash(
        roundsCompleted,
        additionalReps,
        completionTime,
        weightKg,
        scaling,
        isCompleted,
      );
}
