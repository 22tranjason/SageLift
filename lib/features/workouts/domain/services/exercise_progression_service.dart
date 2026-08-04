import '../models/workout_set.dart';

/// Factual comparison outcomes for one exercise across consecutive sessions.
enum ExerciseProgressionStatus {
  /// No prior completed sets exist for the exercise.
  firstSession,

  /// A higher recorded weight was used while repetitions stayed in range.
  improvedByWeight,

  /// The same recorded weight was used for more repetitions.
  improvedByReps,

  /// Weight and repetitions matched the prior completed session.
  matched,

  /// The current recorded result was below the prior completed session.
  belowPrevious,
}

/// Inclusive programmed repetition range parsed from an exercise set note.
class RepRange {
  /// Creates a repetition range from [minimum] through [maximum].
  const RepRange({required this.minimum, required this.maximum});

  /// Lowest programmed repetition count.
  final int minimum;

  /// Highest programmed repetition count.
  final int maximum;

  /// Human-readable range suitable for concise UI hints.
  String get display => '$minimum–$maximum';

  /// Whether [reps] is within the inclusive programmed range.
  bool includes(int reps) => reps >= minimum && reps <= maximum;
}

/// One editable repetition target for a planned set.
class SetProgressionSuggestion {
  /// Creates guidance for a set identified by [setNumber].
  const SetProgressionSuggestion({
    required this.setNumber,
    required this.targetReps,
    this.suggestedWeightKg,
  });

  /// One-based position of the set within its exercise.
  final int setNumber;

  /// Suggested editable repetition target.
  final int? targetReps;

  /// Suggested weight when the prior weight should be repeated.
  final double? suggestedWeightKg;
}

/// Non-persistent next-session guidance for one exercise.
class ExerciseProgressionGuidance {
  /// Creates a factual guidance message and optional set-level targets.
  ExerciseProgressionGuidance({
    required this.status,
    required this.message,
    required List<SetProgressionSuggestion> setSuggestions,
    this.repRange,
  }) : _setSuggestions = List<SetProgressionSuggestion>.unmodifiable(
          setSuggestions,
        );

  /// Classification based on the available completed history.
  final ExerciseProgressionStatus status;

  /// Plain-language next-session guidance.
  final String message;

  /// Parsed programmed range, when a set note provides one.
  final RepRange? repRange;

  final List<SetProgressionSuggestion> _setSuggestions;

  /// Suggested targets in the planned set order.
  List<SetProgressionSuggestion> get setSuggestions => _setSuggestions;
}

/// Compares completed exercise sets and produces conservative next-session guidance.
class ExerciseProgressionService {
  /// Creates a progression service with no infrastructure dependencies.
  const ExerciseProgressionService();

  /// Parses a programmed repetition range from [set]'s exercise note.
  RepRange? repRangeFor(WorkoutSet set) {
    final RegExpMatch? match = RegExp(
      r'(\d+)\s*[–-]\s*(\d+)\s*reps',
      caseSensitive: false,
    ).firstMatch(set.notes ?? '');
    if (match == null) return null;
    final int? minimum = int.tryParse(match.group(1) ?? '');
    final int? maximum = int.tryParse(match.group(2) ?? '');
    if (minimum == null || maximum == null || minimum > maximum) return null;
    return RepRange(minimum: minimum, maximum: maximum);
  }

  /// Parses the rest instruction from [set]'s note, when it is present.
  String? restGuidanceFor(WorkoutSet set) {
    return RegExp(
      r'rest\s+[^;]+',
      caseSensitive: false,
    ).firstMatch(set.notes ?? '')?.group(0);
  }

  /// Produces next-session suggestions without modifying any recorded set values.
  ExerciseProgressionGuidance suggest({
    required List<WorkoutSet> programmedSets,
    required List<WorkoutSet> previousCompletedSets,
  }) {
    final RepRange? range = _rangeFor(programmedSets);
    if (previousCompletedSets.isEmpty) {
      return ExerciseProgressionGuidance(
        status: ExerciseProgressionStatus.firstSession,
        message: 'First session — choose a comfortable starting weight.',
        repRange: range,
        setSuggestions: _plannedSuggestions(programmedSets),
      );
    }

    if (range != null && _allSetsReachedTop(previousCompletedSets, range)) {
      final int upperAim =
          range.minimum + 2 > range.maximum ? range.maximum : range.minimum + 2;
      return ExerciseProgressionGuidance(
        status: ExerciseProgressionStatus.improvedByReps,
        message: 'Increase the weight by the smallest available amount and '
            'aim for ${range.minimum}–$upperAim reps.',
        repRange: range,
        setSuggestions: programmedSets
            .map(
              (WorkoutSet set) => SetProgressionSuggestion(
                setNumber: set.setNumber,
                targetReps: range.minimum,
              ),
            )
            .toList(growable: false),
      );
    }

    final List<SetProgressionSuggestion> suggestions = _sameWeightSuggestions(
      programmedSets: programmedSets,
      previousCompletedSets: previousCompletedSets,
      range: range,
    );
    return ExerciseProgressionGuidance(
      status: ExerciseProgressionStatus.matched,
      message: 'Keep the same weight and add one rep where practical.',
      repRange: range,
      setSuggestions: suggestions,
    );
  }

  /// Classifies [currentCompletedSets] against [previousCompletedSets].
  ExerciseProgressionStatus classify({
    required List<WorkoutSet> currentCompletedSets,
    required List<WorkoutSet> previousCompletedSets,
    RepRange? repRange,
  }) {
    if (previousCompletedSets.isEmpty) {
      return ExerciseProgressionStatus.firstSession;
    }
    if (currentCompletedSets.isEmpty) {
      return ExerciseProgressionStatus.belowPrevious;
    }

    final bool repsAreInRange = repRange == null ||
        currentCompletedSets.every(
          (WorkoutSet set) => set.reps != null && repRange.includes(set.reps!),
        );
    if (_hasIncreasedWeight(currentCompletedSets, previousCompletedSets) &&
        repsAreInRange) {
      return ExerciseProgressionStatus.improvedByWeight;
    }
    if (_weightsMatch(currentCompletedSets, previousCompletedSets)) {
      final int currentReps = _totalReps(currentCompletedSets);
      final int previousReps = _totalReps(previousCompletedSets);
      if (currentReps > previousReps) {
        return ExerciseProgressionStatus.improvedByReps;
      }
      if (currentReps == previousReps) {
        return ExerciseProgressionStatus.matched;
      }
    }
    return ExerciseProgressionStatus.belowPrevious;
  }

  /// Returns a factual next-session note for a completed comparison [status].
  String nextStepFor(ExerciseProgressionStatus status) {
    switch (status) {
      case ExerciseProgressionStatus.firstSession:
        return 'First session — choose a comfortable starting weight.';
      case ExerciseProgressionStatus.improvedByWeight:
        return 'Higher weight was completed inside the programmed range.';
      case ExerciseProgressionStatus.improvedByReps:
        return 'More reps were completed at the same weight.';
      case ExerciseProgressionStatus.matched:
        return 'Attempt one additional rep next time.';
      case ExerciseProgressionStatus.belowPrevious:
        return 'Repeat the same weight and try to restore the previous reps.';
    }
  }

  RepRange? _rangeFor(List<WorkoutSet> sets) {
    for (final WorkoutSet set in sets) {
      final RepRange? range = repRangeFor(set);
      if (range != null) return range;
    }
    return null;
  }

  bool _allSetsReachedTop(List<WorkoutSet> sets, RepRange range) {
    return sets.isNotEmpty &&
        sets.every(
          (WorkoutSet set) => set.reps != null && set.reps! >= range.maximum,
        );
  }

  List<SetProgressionSuggestion> _plannedSuggestions(
    List<WorkoutSet> programmedSets,
  ) {
    return programmedSets
        .map(
          (WorkoutSet set) => SetProgressionSuggestion(
            setNumber: set.setNumber,
            targetReps: set.targetReps,
          ),
        )
        .toList(growable: false);
  }

  List<SetProgressionSuggestion> _sameWeightSuggestions({
    required List<WorkoutSet> programmedSets,
    required List<WorkoutSet> previousCompletedSets,
    required RepRange? range,
  }) {
    final List<SetProgressionSuggestion> suggestions =
        <SetProgressionSuggestion>[
      for (int index = 0; index < programmedSets.length; index++)
        SetProgressionSuggestion(
          setNumber: programmedSets[index].setNumber,
          targetReps: index < previousCompletedSets.length
              ? previousCompletedSets[index].reps ??
                  programmedSets[index].targetReps
              : programmedSets[index].targetReps,
          suggestedWeightKg: index < previousCompletedSets.length
              ? previousCompletedSets[index].weightKg
              : null,
        ),
    ];
    if (range == null) return suggestions;

    for (int index = suggestions.length - 1; index >= 0; index--) {
      final int? previousReps = suggestions[index].targetReps;
      if (previousReps != null && previousReps < range.maximum) {
        suggestions[index] = SetProgressionSuggestion(
          setNumber: suggestions[index].setNumber,
          targetReps: previousReps + 1,
          suggestedWeightKg: suggestions[index].suggestedWeightKg,
        );
        break;
      }
    }
    return suggestions;
  }

  bool _hasIncreasedWeight(
    List<WorkoutSet> currentSets,
    List<WorkoutSet> previousSets,
  ) {
    final double? currentHighestWeight = _highestWeight(currentSets);
    final double? previousHighestWeight = _highestWeight(previousSets);
    return currentHighestWeight != null &&
        previousHighestWeight != null &&
        currentHighestWeight > previousHighestWeight;
  }

  bool _weightsMatch(List<WorkoutSet> first, List<WorkoutSet> second) {
    if (first.length != second.length) return false;
    for (int index = 0; index < first.length; index++) {
      if (first[index].weightKg != second[index].weightKg) return false;
    }
    return true;
  }

  double? _highestWeight(List<WorkoutSet> sets) {
    final List<double> weights = sets
        .map((WorkoutSet set) => set.weightKg)
        .whereType<double>()
        .toList(growable: false);
    if (weights.isEmpty) return null;
    return weights.reduce((double first, double second) {
      return first > second ? first : second;
    });
  }

  int _totalReps(List<WorkoutSet> sets) {
    return sets.fold<int>(
      0,
      (int total, WorkoutSet set) => total + (set.reps ?? 0),
    );
  }
}
