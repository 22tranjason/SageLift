import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_check_in_hive_model.dart';

/// Registers Hive types owned by the daily check-in data layer.
abstract final class DailyCheckInHiveAdapters {
  static const int _dailyCheckInTypeId = 210;

  /// Registers the adapter once before the check-in box opens.
  static void registerAll() {
    if (!Hive.isAdapterRegistered(_dailyCheckInTypeId)) {
      Hive.registerAdapter<DailyCheckInHiveModel>(
          DailyCheckInHiveModelAdapter());
    }
  }
}

/// Binary adapter for [DailyCheckInHiveModel].
class DailyCheckInHiveModelAdapter extends TypeAdapter<DailyCheckInHiveModel> {
  /// Creates the daily check-in persistence adapter.
  DailyCheckInHiveModelAdapter();

  @override
  int get typeId => 210;

  @override
  DailyCheckInHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, Object?> fields = <int, Object?>{
      for (int index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return DailyCheckInHiveModel(
      id: fields[0]! as String,
      dateMilliseconds: fields[1]! as int,
      bodyWeightKg: fields[2]! as double,
      proteinGrams: fields[3]! as double,
      waterMillilitres: fields[4]! as double,
      steps: fields[5] as int? ?? 0,
      completedHabitIds:
          List<String>.from(fields[6] as List<Object?>? ?? const <Object?>[]),
      heightCm: fields[7] as double?,
      moodIndex: fields[8] as int?,
      energyLevel: fields[9] as int?,
      notes: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyCheckInHiveModel object) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.dateMilliseconds)
      ..writeByte(2)
      ..write(object.bodyWeightKg)
      ..writeByte(3)
      ..write(object.proteinGrams)
      ..writeByte(4)
      ..write(object.waterMillilitres)
      ..writeByte(5)
      ..write(object.steps)
      ..writeByte(6)
      ..write(object.completedHabitIds)
      ..writeByte(7)
      ..write(object.heightCm)
      ..writeByte(8)
      ..write(object.moodIndex)
      ..writeByte(9)
      ..write(object.energyLevel)
      ..writeByte(10)
      ..write(object.notes);
  }
}
