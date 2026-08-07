/// The conditioning format prescribed for a CrossFit workout.
enum ConditioningFormat {
  /// A fixed number of rounds completed as quickly as practical.
  roundsForTime,

  /// As many rounds and extra repetitions as possible in a duration.
  amrap,

  /// Work repeated at the start of each minute.
  emom,
}

/// Unit used for a prescribed or recorded conditioning distance.
enum DistanceUnit {
  /// Metres, suitable for a short run or shuttle.
  metres,

  /// Kilometres, suitable for a longer running distance.
  kilometres,
}

/// Unit used for a prescribed or recorded conditioning load.
enum LoadUnit {
  /// Kilograms are SageLift's current standard unit for external load.
  kilograms,
}

/// One prescribed movement in an ordered conditioning circuit.
class ConditioningMovement {
  /// Creates an immutable conditioning movement prescription.
  const ConditioningMovement({
    required this.id,
    required this.name,
    this.prescribedReps,
    this.prescribedDistance,
    this.distanceUnit,
    this.prescribedLoad,
    this.loadUnit = LoadUnit.kilograms,
    this.implementCount = 1,
    this.isBodyweight = false,
    this.notes,
  });

  /// Stable movement identifier within the workout's conditioning plan.
  final String id;

  /// Display name for the movement.
  final String name;

  /// Repetitions prescribed for this movement, where applicable.
  final int? prescribedReps;

  /// Distance prescribed for this movement, where applicable.
  final double? prescribedDistance;

  /// Unit for [prescribedDistance].
  final DistanceUnit? distanceUnit;

  /// Suggested external load, when the movement has one.
  final double? prescribedLoad;

  /// Unit for prescribed and actual loads.
  final LoadUnit loadUnit;

  /// Number of implements, such as two dumbbells.
  final int implementCount;

  /// Whether the movement intentionally has no external load.
  final bool isBodyweight;

  /// Optional movement-specific scaling or safety guidance.
  final String? notes;

  @override
  bool operator ==(Object other) =>
      other is ConditioningMovement &&
      other.id == id &&
      other.name == name &&
      other.prescribedReps == prescribedReps &&
      other.prescribedDistance == prescribedDistance &&
      other.distanceUnit == distanceUnit &&
      other.prescribedLoad == prescribedLoad &&
      other.loadUnit == loadUnit &&
      other.implementCount == implementCount &&
      other.isBodyweight == isBodyweight &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        prescribedReps,
        prescribedDistance,
        distanceUnit,
        prescribedLoad,
        loadUnit,
        implementCount,
        isBodyweight,
        notes,
      );
}

/// The recorded load and modification for one conditioning movement.
class ConditioningMovementResult {
  /// Creates an immutable result for one conditioning movement.
  const ConditioningMovementResult({
    required this.movementId,
    this.actualLoad,
    this.implementCount,
    this.modification,
  });

  /// Identifier of the prescribed [ConditioningMovement].
  final String movementId;

  /// Actual per-implement load used, when applicable.
  final double? actualLoad;

  /// Actual number of implements used, when different from the prescription.
  final int? implementCount;

  /// Optional user-recorded scaling or modification.
  final String? modification;

  @override
  bool operator ==(Object other) =>
      other is ConditioningMovementResult &&
      other.movementId == movementId &&
      other.actualLoad == actualLoad &&
      other.implementCount == implementCount &&
      other.modification == modification;

  @override
  int get hashCode =>
      Object.hash(movementId, actualLoad, implementCount, modification);
}

/// The programmed conditioning section of a workout.
class ConditioningPlan {
  /// Creates an immutable conditioning prescription.
  ConditioningPlan({
    required this.format,
    required this.title,
    required this.instructions,
    List<ConditioningMovement> movements = const <ConditioningMovement>[],
    this.prescribedRounds,
    this.durationMinutes,
  }) : _movements = List<ConditioningMovement>.unmodifiable(movements);

  /// How the conditioning work is structured.
  final ConditioningFormat format;

  /// Short display title, such as `4 rounds for time`.
  final String title;

  /// Human-readable ordered movement instructions.
  final String instructions;

  /// Prescribed full rounds for round-based conditioning.
  final int? prescribedRounds;

  /// Prescribed duration for AMRAP and EMOM conditioning.
  final int? durationMinutes;
  final List<ConditioningMovement> _movements;

  /// Ordered movements shown while logging this conditioning circuit.
  List<ConditioningMovement> get movements => _movements;

  @override
  bool operator ==(Object other) =>
      other is ConditioningPlan &&
      other.format == format &&
      other.title == title &&
      other.instructions == instructions &&
      other.prescribedRounds == prescribedRounds &&
      other.durationMinutes == durationMinutes &&
      _listEquals(other._movements, _movements);

  @override
  int get hashCode => Object.hash(
        format,
        title,
        instructions,
        prescribedRounds,
        durationMinutes,
        Object.hashAll(_movements),
      );
}

/// The factual result recorded for a conditioning section.
class ConditioningResult {
  /// Creates an immutable conditioning result.
  ConditioningResult({
    required this.roundsCompleted,
    required this.additionalReps,
    required this.isCompleted,
    List<ConditioningMovementResult> movementResults =
        const <ConditioningMovementResult>[],
    this.completionTime,
    this.weightKg,
    this.scaling,
  }) : _movementResults =
            List<ConditioningMovementResult>.unmodifiable(movementResults);

  /// Complete conditioning rounds actually performed.
  final int roundsCompleted;

  /// Repetitions completed after the final full round.
  final int additionalReps;

  /// Recorded elapsed time, when applicable.
  final Duration? completionTime;

  /// Legacy generic load retained for conditioning results recorded before
  /// movement-specific logging was introduced.
  final double? weightKg;

  /// Legacy free-form scaling retained without attempting fragile parsing.
  /// Legacy free-form scaling retained without attempting fragile parsing.
  final String? scaling;

  /// Whether the prescribed conditioning work was fully completed.
  final bool isCompleted;
  final List<ConditioningMovementResult> _movementResults;

  /// Structured, movement-specific data recorded in newer sessions.
  List<ConditioningMovementResult> get movementResults => _movementResults;

  static const Object _unset = Object();

  /// Returns this result with selected values replaced or nullable values cleared.
  ConditioningResult copyWith({
    int? roundsCompleted,
    int? additionalReps,
    bool? isCompleted,
    List<ConditioningMovementResult>? movementResults,
    Object? completionTime = _unset,
    Object? weightKg = _unset,
    Object? scaling = _unset,
  }) {
    return ConditioningResult(
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      additionalReps: additionalReps ?? this.additionalReps,
      isCompleted: isCompleted ?? this.isCompleted,
      movementResults: movementResults ?? _movementResults,
      completionTime: identical(completionTime, _unset)
          ? this.completionTime
          : completionTime as Duration?,
      weightKg:
          identical(weightKg, _unset) ? this.weightKg : weightKg as double?,
      scaling: identical(scaling, _unset) ? this.scaling : scaling as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConditioningResult &&
      other.roundsCompleted == roundsCompleted &&
      other.additionalReps == additionalReps &&
      other.completionTime == completionTime &&
      other.weightKg == weightKg &&
      other.scaling == scaling &&
      other.isCompleted == isCompleted &&
      _listEquals(other._movementResults, _movementResults);

  @override
  int get hashCode => Object.hash(
        roundsCompleted,
        additionalReps,
        completionTime,
        weightKg,
        scaling,
        isCompleted,
        Object.hashAll(_movementResults),
      );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
