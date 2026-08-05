/// Hive-specific representation of one persisted daily check-in.
class DailyCheckInHiveModel {
  /// Creates a persistence representation of a daily check-in.
  DailyCheckInHiveModel({
    required this.id,
    required this.dateMilliseconds,
    required this.bodyWeightKg,
    required this.proteinGrams,
    required this.waterMillilitres,
    required this.steps,
    required List<String> completedHabitIds,
    this.heightCm,
    this.moodIndex,
    this.energyLevel,
    this.notes,
  }) : completedHabitIds = List<String>.unmodifiable(completedHabitIds);

  /// Stable key for the check-in record.
  final String id;

  /// Local calendar date encoded as a UTC date-only timestamp.
  final int dateMilliseconds;

  /// Body weight stored with this check-in, or zero until weight tracking is used.
  final double bodyWeightKg;

  /// Protein total recorded for the date, in grams.
  final double proteinGrams;

  /// Water total recorded for the date, in millilitres.
  final double waterMillilitres;

  /// Manually entered step count.
  final int steps;

  /// IDs of habits marked complete for this date.
  final List<String> completedHabitIds;

  /// Optional height measurement in centimetres.
  final double? heightCm;

  /// Optional persisted index of the mood enum.
  final int? moodIndex;

  /// Optional self-reported energy level.
  final int? energyLevel;

  /// Optional check-in notes.
  final String? notes;
}
