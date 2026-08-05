/// General emotional state recorded with a daily check-in.
enum Mood {
  /// Very low mood.
  veryLow,

  /// Low mood.
  low,

  /// Neutral mood.
  neutral,

  /// Good mood.
  good,

  /// Very good mood.
  veryGood,
}

/// A daily snapshot of health and nutrition inputs.
class DailyCheckIn {
  /// Creates an immutable daily check-in.
  DailyCheckIn({
    required this.id,
    required this.date,
    required this.bodyWeightKg,
    required this.proteinGrams,
    required this.waterMillilitres,
    this.steps = 0,
    List<String> completedHabitIds = const <String>[],
    this.heightCm,
    this.mood,
    this.energyLevel,
    this.notes,
  }) : _completedHabitIds = List<String>.unmodifiable(completedHabitIds);

  /// Stable, client-generated identifier for this check-in.
  final String id;

  /// Calendar date represented by the check-in.
  final DateTime date;

  /// Measured body weight in kilograms.
  final double bodyWeightKg;

  /// Optional measured height in centimetres; BMI remains a derived value.
  final double? heightCm;

  /// Total protein consumed during the calendar day, in grams.
  final double proteinGrams;

  /// Total water consumed during the calendar day, in millilitres.
  final double waterMillilitres;

  /// Manually entered step count until a health integration is available.
  final int steps;

  final List<String> _completedHabitIds;

  /// Identifiers of habits completed on this calendar day.
  List<String> get completedHabitIds => _completedHabitIds;

  /// Optional general emotional state.
  final Mood? mood;

  /// Optional self-rated energy level; a future use case can define valid bounds.
  final int? energyLevel;

  /// Optional free-form notes for the day.
  final String? notes;

  static const Object _unset = Object();

  /// Returns this check-in with selected values replaced.
  ///
  /// Pass `null` to [heightCm], [mood], [energyLevel], or [notes] to clear it.
  DailyCheckIn copyWith({
    String? id,
    DateTime? date,
    double? bodyWeightKg,
    Object? heightCm = _unset,
    double? proteinGrams,
    double? waterMillilitres,
    int? steps,
    List<String>? completedHabitIds,
    Object? mood = _unset,
    Object? energyLevel = _unset,
    Object? notes = _unset,
  }) {
    return DailyCheckIn(
      id: id ?? this.id,
      date: date ?? this.date,
      bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
      heightCm:
          identical(heightCm, _unset) ? this.heightCm : heightCm as double?,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      waterMillilitres: waterMillilitres ?? this.waterMillilitres,
      steps: steps ?? this.steps,
      completedHabitIds: completedHabitIds ?? _completedHabitIds,
      mood: identical(mood, _unset) ? this.mood : mood as Mood?,
      energyLevel: identical(energyLevel, _unset)
          ? this.energyLevel
          : energyLevel as int?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DailyCheckIn &&
        other.id == id &&
        other.date == date &&
        other.bodyWeightKg == bodyWeightKg &&
        other.heightCm == heightCm &&
        other.proteinGrams == proteinGrams &&
        other.waterMillilitres == waterMillilitres &&
        other.steps == steps &&
        _listEquals(other._completedHabitIds, _completedHabitIds) &&
        other.mood == mood &&
        other.energyLevel == energyLevel &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        id,
        date,
        bodyWeightKg,
        heightCm,
        proteinGrams,
        waterMillilitres,
        steps,
        Object.hashAll(_completedHabitIds),
        mood,
        energyLevel,
        notes,
      );
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (int index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
