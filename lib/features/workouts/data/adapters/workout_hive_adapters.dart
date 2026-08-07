import 'package:hive_flutter/hive_flutter.dart';

import '../models/exercise_hive_model.dart';
import '../models/workout_hive_model.dart';
import '../models/workout_set_hive_model.dart';

/// Registers the manual Hive adapters used by the workouts data layer.
abstract final class WorkoutHiveAdapters {
  static const int _exerciseTypeId = 200;
  static const int _workoutTypeId = 201;
  static const int _workoutSetTypeId = 202;

  /// Registers every adapter once before opening workout-related Hive boxes.
  static void registerAll() {
    if (!Hive.isAdapterRegistered(_exerciseTypeId)) {
      Hive.registerAdapter<ExerciseHiveModel>(ExerciseHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(_workoutTypeId)) {
      Hive.registerAdapter<WorkoutHiveModel>(WorkoutHiveModelAdapter());
    }
    if (!Hive.isAdapterRegistered(_workoutSetTypeId)) {
      Hive.registerAdapter<WorkoutSetHiveModel>(WorkoutSetHiveModelAdapter());
    }
  }
}

/// Binary adapter for [ExerciseHiveModel].
class ExerciseHiveModelAdapter extends TypeAdapter<ExerciseHiveModel> {
  /// Creates the exercise persistence adapter.
  ExerciseHiveModelAdapter();

  @override
  int get typeId => 200;

  @override
  ExerciseHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, Object?> fields = <int, Object?>{
      for (int index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return ExerciseHiveModel(
      id: fields[0]! as String,
      name: fields[1]! as String,
      categoryIndex: fields[2]! as int,
      primaryMuscleGroupIndex: fields[3] as int?,
      equipmentIndex: fields[4]! as int,
      instructions: fields[5] as String?,
      notes: fields[6] as String?,
      isArchived: fields[7]! as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExerciseHiveModel object) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.name)
      ..writeByte(2)
      ..write(object.categoryIndex)
      ..writeByte(3)
      ..write(object.primaryMuscleGroupIndex)
      ..writeByte(4)
      ..write(object.equipmentIndex)
      ..writeByte(5)
      ..write(object.instructions)
      ..writeByte(6)
      ..write(object.notes)
      ..writeByte(7)
      ..write(object.isArchived);
  }
}

/// Binary adapter for [WorkoutHiveModel].
class WorkoutHiveModelAdapter extends TypeAdapter<WorkoutHiveModel> {
  /// Creates the workout persistence adapter.
  WorkoutHiveModelAdapter();

  @override
  int get typeId => 201;

  @override
  WorkoutHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, Object?> fields = <int, Object?>{
      for (int index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return WorkoutHiveModel(
      id: fields[0]! as String,
      name: fields[1]! as String,
      scheduledDateMilliseconds: fields[2]! as int,
      exerciseIds: List<String>.from(fields[3]! as List<Object?>),
      sets: List<WorkoutSetHiveModel>.from(fields[4]! as List<Object?>),
      statusIndex: fields[5]! as int,
      startedAtMilliseconds: fields[6] as int?,
      completedAtMilliseconds: fields[7] as int?,
      notes: fields[8] as String?,
      trackIndex: fields[9] as int? ?? 0,
      warmUp: fields[10] as String?,
      conditioningFormatIndex: fields[11] as int?,
      conditioningTitle: fields[12] as String?,
      conditioningInstructions: fields[13] as String?,
      prescribedRounds: fields[14] as int?,
      conditioningDurationMinutes: fields[15] as int?,
      roundsCompleted: fields[16] as int?,
      additionalReps: fields[17] as int?,
      completionTimeMilliseconds: fields[18] as int?,
      conditioningWeightKg: fields[19] as double?,
      conditioningScaling: fields[20] as String?,
      conditioningCompleted: fields[21] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutHiveModel object) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.name)
      ..writeByte(2)
      ..write(object.scheduledDateMilliseconds)
      ..writeByte(3)
      ..write(object.exerciseIds)
      ..writeByte(4)
      ..write(object.sets)
      ..writeByte(5)
      ..write(object.statusIndex)
      ..writeByte(6)
      ..write(object.startedAtMilliseconds)
      ..writeByte(7)
      ..write(object.completedAtMilliseconds)
      ..writeByte(8)
      ..write(object.notes)
      ..writeByte(9)
      ..write(object.trackIndex)
      ..writeByte(10)
      ..write(object.warmUp)
      ..writeByte(11)
      ..write(object.conditioningFormatIndex)
      ..writeByte(12)
      ..write(object.conditioningTitle)
      ..writeByte(13)
      ..write(object.conditioningInstructions)
      ..writeByte(14)
      ..write(object.prescribedRounds)
      ..writeByte(15)
      ..write(object.conditioningDurationMinutes)
      ..writeByte(16)
      ..write(object.roundsCompleted)
      ..writeByte(17)
      ..write(object.additionalReps)
      ..writeByte(18)
      ..write(object.completionTimeMilliseconds)
      ..writeByte(19)
      ..write(object.conditioningWeightKg)
      ..writeByte(20)
      ..write(object.conditioningScaling)
      ..writeByte(21)
      ..write(object.conditioningCompleted);
  }
}

/// Binary adapter for [WorkoutSetHiveModel].
class WorkoutSetHiveModelAdapter extends TypeAdapter<WorkoutSetHiveModel> {
  /// Creates the workout-set persistence adapter.
  WorkoutSetHiveModelAdapter();

  @override
  int get typeId => 202;

  @override
  WorkoutSetHiveModel read(BinaryReader reader) {
    final int fieldCount = reader.readByte();
    final Map<int, Object?> fields = <int, Object?>{
      for (int index = 0; index < fieldCount; index++)
        reader.readByte(): reader.read(),
    };
    return WorkoutSetHiveModel(
      id: fields[0]! as String,
      exerciseId: fields[1]! as String,
      setNumber: fields[2]! as int,
      weightKg: fields[3] as double?,
      reps: fields[4] as int?,
      targetWeightKg: fields[5] as double?,
      targetReps: fields[6] as int?,
      statusIndex: fields[7]! as int,
      rpe: fields[8] as double?,
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkoutSetHiveModel object) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(object.id)
      ..writeByte(1)
      ..write(object.exerciseId)
      ..writeByte(2)
      ..write(object.setNumber)
      ..writeByte(3)
      ..write(object.weightKg)
      ..writeByte(4)
      ..write(object.reps)
      ..writeByte(5)
      ..write(object.targetWeightKg)
      ..writeByte(6)
      ..write(object.targetReps)
      ..writeByte(7)
      ..write(object.statusIndex)
      ..writeByte(8)
      ..write(object.rpe)
      ..writeByte(9)
      ..write(object.notes);
  }
}
