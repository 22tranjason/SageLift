/// The completion state of one challenge day.
enum ChallengeDayStatus {
  /// The day's target has not yet been met.
  pending,

  /// The day's target has been met.
  completed,

  /// The day was deliberately skipped.
  skipped,
}

/// Unit for a challenge day's target and progress values.
enum ChallengeProgressUnit {
  /// A binary completion target.
  completion,

  /// A count of repeated actions.
  count,

  /// Minutes of activity or focus.
  minutes,

  /// Grams of a nutrient or substance.
  grams,

  /// Millilitres of fluid.
  millilitres,
}

/// One dated target within a challenge.
class ChallengeDay {
  /// Creates an immutable challenge day.
  const ChallengeDay({
    required this.id,
    required this.challengeId,
    required this.date,
    required this.targetDescription,
    required this.targetValue,
    required this.progressValue,
    required this.unit,
    required this.status,
  });

  /// Stable, client-generated identifier for this challenge day.
  final String id;

  /// Identifier of the containing [Challenge].
  final String challengeId;

  /// Calendar date to which this target applies.
  final DateTime date;

  /// Human-readable explanation of the target.
  final String targetDescription;

  /// Numeric value required to complete the target.
  final double targetValue;

  /// Numeric progress recorded toward [targetValue].
  final double progressValue;

  /// Unit shared by [targetValue] and [progressValue].
  final ChallengeProgressUnit unit;

  /// Completion state for this day.
  final ChallengeDayStatus status;

  /// Returns this challenge day with selected values replaced.
  ChallengeDay copyWith({
    String? id,
    String? challengeId,
    DateTime? date,
    String? targetDescription,
    double? targetValue,
    double? progressValue,
    ChallengeProgressUnit? unit,
    ChallengeDayStatus? status,
  }) {
    return ChallengeDay(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      date: date ?? this.date,
      targetDescription: targetDescription ?? this.targetDescription,
      targetValue: targetValue ?? this.targetValue,
      progressValue: progressValue ?? this.progressValue,
      unit: unit ?? this.unit,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChallengeDay &&
        other.id == id &&
        other.challengeId == challengeId &&
        other.date == date &&
        other.targetDescription == targetDescription &&
        other.targetValue == targetValue &&
        other.progressValue == progressValue &&
        other.unit == unit &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        challengeId,
        date,
        targetDescription,
        targetValue,
        progressValue,
        unit,
        status,
      );
}
