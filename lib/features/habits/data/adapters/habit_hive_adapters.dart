import 'package:hive_flutter/hive_flutter.dart';

import '../models/habit_hive_model.dart';

/// Registers Hive types owned by the habit data layer.
abstract final class HabitHiveAdapters {
  static const int _habitTypeId = 211;

  /// Registers the habit adapter once before its box opens.
  static void registerAll() {
    if (!Hive.isAdapterRegistered(_habitTypeId)) {
      Hive.registerAdapter<HabitHiveModel>(HabitHiveModelAdapter());
    }
  }
}

/// Binary adapter for [HabitHiveModel].
class HabitHiveModelAdapter extends TypeAdapter<HabitHiveModel> {
  /// Creates the habit persistence adapter.
  HabitHiveModelAdapter();

  @override
  int get typeId => 211;

  @override
  HabitHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, Object?> fields = <int, Object?>{
      for (int index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return HabitHiveModel(
      id: fields[0]! as String,
      name: fields[1]! as String,
      targetTypeIndex: fields[2]! as int,
      targetValue: fields[3]! as double,
      unitIndex: fields[4]! as int,
      activeDayIndexes: List<int>.from(fields[5]! as List<Object?>),
      isActive: fields[6]! as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HabitHiveModel object) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.name)
      ..writeByte(2)
      ..write(object.targetTypeIndex)
      ..writeByte(3)
      ..write(object.targetValue)
      ..writeByte(4)
      ..write(object.unitIndex)
      ..writeByte(5)
      ..write(object.activeDayIndexes)
      ..writeByte(6)
      ..write(object.isActive);
  }
}
