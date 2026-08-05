import '../../domain/models/daily_check_in.dart';
import '../models/daily_check_in_hive_model.dart';

/// Converts check-in persistence records into framework-independent models.
extension DailyCheckInHiveMapper on DailyCheckInHiveModel {
  /// Creates the equivalent [DailyCheckIn].
  DailyCheckIn toDomain() {
    final DateTime storedDate = DateTime.fromMillisecondsSinceEpoch(
      dateMilliseconds,
      isUtc: true,
    );
    return DailyCheckIn(
      id: id,
      date: DateTime(storedDate.year, storedDate.month, storedDate.day),
      bodyWeightKg: bodyWeightKg,
      proteinGrams: proteinGrams,
      waterMillilitres: waterMillilitres,
      steps: steps,
      completedHabitIds: completedHabitIds,
      heightCm: heightCm,
      mood: moodIndex == null ? null : Mood.values[moodIndex!],
      energyLevel: energyLevel,
      notes: notes,
    );
  }
}

/// Converts daily check-in domain models into persistence records.
extension DailyCheckInDomainMapper on DailyCheckIn {
  /// Creates the Hive-specific representation of this check-in.
  DailyCheckInHiveModel toHiveModel() {
    return DailyCheckInHiveModel(
      id: id,
      dateMilliseconds:
          DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch,
      bodyWeightKg: bodyWeightKg,
      proteinGrams: proteinGrams,
      waterMillilitres: waterMillilitres,
      steps: steps,
      completedHabitIds: completedHabitIds,
      heightCm: heightCm,
      moodIndex: mood?.index,
      energyLevel: energyLevel,
      notes: notes,
    );
  }
}
