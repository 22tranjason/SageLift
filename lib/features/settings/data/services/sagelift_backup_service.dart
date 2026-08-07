import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../check_ins/data/models/daily_check_in_hive_model.dart';
import '../../../habits/data/models/habit_hive_model.dart';
import '../../../workouts/data/models/exercise_hive_model.dart';
import '../../../workouts/data/models/workout_hive_model.dart';
import '../../../workouts/data/models/workout_set_hive_model.dart';

/// A validated SageLift backup ready to be downloaded as JSON.
class SageLiftBackup {
  /// Creates one backup file payload.
  const SageLiftBackup({required this.filename, required this.contents});

  /// Human-readable filename intended for a user's download folder.
  final String filename;

  /// UTF-8 JSON contents.
  final String contents;
}

/// Thrown when a selected file is not a compatible SageLift backup.
class BackupFormatException implements Exception {
  /// Creates an error that can be shown without exposing raw parser details.
  const BackupFormatException(this.message);

  /// Human-readable validation failure.
  final String message;

  @override
  String toString() => message;
}

/// Exports and restores all local SageLift records without a remote service.
class SageLiftBackupService {
  /// Creates a service over every currently persisted SageLift box.
  const SageLiftBackupService({
    required Box<ExerciseHiveModel> exerciseBox,
    required Box<WorkoutHiveModel> workoutBox,
    required Box<DailyCheckInHiveModel> dailyCheckInBox,
    required Box<HabitHiveModel> habitBox,
    required Box<dynamic> settingsBox,
    DateTime Function()? now,
  })  : _exerciseBox = exerciseBox,
        _workoutBox = workoutBox,
        _dailyCheckInBox = dailyCheckInBox,
        _habitBox = habitBox,
        _settingsBox = settingsBox,
        _now = now ?? DateTime.now;

  /// Current compatible file structure version.
  static const int schemaVersion = 1;

  final Box<ExerciseHiveModel> _exerciseBox;
  final Box<WorkoutHiveModel> _workoutBox;
  final Box<DailyCheckInHiveModel> _dailyCheckInBox;
  final Box<HabitHiveModel> _habitBox;
  final Box<dynamic> _settingsBox;
  final DateTime Function() _now;

  /// Produces one self-contained JSON export of all local SageLift data.
  SageLiftBackup createBackup() {
    final DateTime exportedAt = _now().toUtc();
    final Map<String, Object?> document = <String, Object?>{
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'workouts':
          _workoutBox.values.map(_workoutToJson).toList(growable: false),
      'exercises':
          _exerciseBox.values.map(_exerciseToJson).toList(growable: false),
      'dailyCheckIns': _dailyCheckInBox.values
          .map(_dailyCheckInToJson)
          .toList(growable: false),
      'habits': _habitBox.values.map(_habitToJson).toList(growable: false),
      'settings': <String, Object?>{
        for (final dynamic key in _settingsBox.keys)
          if (key is String) key: _settingsBox.get(key),
      },
    };
    final String day = '${exportedAt.year.toString().padLeft(4, '0')}-'
        '${exportedAt.month.toString().padLeft(2, '0')}-'
        '${exportedAt.day.toString().padLeft(2, '0')}';
    return SageLiftBackup(
      filename: 'sagelift-backup-$day.json',
      contents: const JsonEncoder.withIndent('  ').convert(document),
    );
  }

  /// Validates [contents] completely before replacing local records.
  ///
  /// If a write fails, the previous box contents are restored where possible.
  Future<void> restore(String contents) async {
    final _BackupRecords records = _parse(contents);
    final _BoxSnapshot snapshot = _BoxSnapshot(
      exercises: Map<dynamic, ExerciseHiveModel>.from(_exerciseBox.toMap()),
      workouts: Map<dynamic, WorkoutHiveModel>.from(_workoutBox.toMap()),
      dailyCheckIns:
          Map<dynamic, DailyCheckInHiveModel>.from(_dailyCheckInBox.toMap()),
      habits: Map<dynamic, HabitHiveModel>.from(_habitBox.toMap()),
      settings: Map<dynamic, dynamic>.from(_settingsBox.toMap()),
    );
    try {
      await _replaceAll(records);
    } catch (_) {
      await _restoreSnapshot(snapshot);
      rethrow;
    }
  }

  Future<void> _replaceAll(_BackupRecords records) async {
    await _exerciseBox.clear();
    await _workoutBox.clear();
    await _dailyCheckInBox.clear();
    await _habitBox.clear();
    await _settingsBox.clear();
    await _exerciseBox.putAll(<String, ExerciseHiveModel>{
      for (final ExerciseHiveModel exercise in records.exercises)
        exercise.id: exercise,
    });
    await _workoutBox.putAll(<String, WorkoutHiveModel>{
      for (final WorkoutHiveModel workout in records.workouts)
        workout.id: workout,
    });
    await _dailyCheckInBox.putAll(<String, DailyCheckInHiveModel>{
      for (final DailyCheckInHiveModel checkIn in records.dailyCheckIns)
        checkIn.id: checkIn,
    });
    await _habitBox.putAll(<String, HabitHiveModel>{
      for (final HabitHiveModel habit in records.habits) habit.id: habit,
    });
    await _settingsBox.putAll(records.settings);
  }

  Future<void> _restoreSnapshot(_BoxSnapshot snapshot) async {
    await _exerciseBox.clear();
    await _workoutBox.clear();
    await _dailyCheckInBox.clear();
    await _habitBox.clear();
    await _settingsBox.clear();
    await _exerciseBox.putAll(snapshot.exercises);
    await _workoutBox.putAll(snapshot.workouts);
    await _dailyCheckInBox.putAll(snapshot.dailyCheckIns);
    await _habitBox.putAll(snapshot.habits);
    await _settingsBox.putAll(snapshot.settings);
  }

  _BackupRecords _parse(String contents) {
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      throw const BackupFormatException('This is not valid SageLift JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException(
          'This backup has an invalid structure.');
    }
    if (decoded['schemaVersion'] != schemaVersion) {
      throw const BackupFormatException(
        'This backup uses an unsupported SageLift schema version.',
      );
    }
    try {
      return _BackupRecords(
        exercises:
            _jsonList(decoded, 'exercises').map(_exerciseFromJson).toList(),
        workouts: _jsonList(decoded, 'workouts').map(_workoutFromJson).toList(),
        dailyCheckIns: _jsonList(decoded, 'dailyCheckIns')
            .map(_dailyCheckInFromJson)
            .toList(),
        habits: _jsonList(decoded, 'habits').map(_habitFromJson).toList(),
        settings: _jsonMap(decoded['settings'] ?? const <String, dynamic>{}),
      );
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException('This backup contains invalid data.');
    }
  }

  List<Map<String, dynamic>> _jsonList(
      Map<String, dynamic> document, String key) {
    final Object? value = document[key];
    if (value is! List<dynamic>) {
      throw BackupFormatException('The backup is missing $key data.');
    }
    return value.map(_jsonMap).toList(growable: false);
  }

  Map<String, dynamic> _jsonMap(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const BackupFormatException(
          'The backup contains an invalid record.');
    }
    return value;
  }
}

class _BackupRecords {
  const _BackupRecords({
    required this.exercises,
    required this.workouts,
    required this.dailyCheckIns,
    required this.habits,
    required this.settings,
  });

  final List<ExerciseHiveModel> exercises;
  final List<WorkoutHiveModel> workouts;
  final List<DailyCheckInHiveModel> dailyCheckIns;
  final List<HabitHiveModel> habits;
  final Map<String, dynamic> settings;
}

class _BoxSnapshot {
  const _BoxSnapshot({
    required this.exercises,
    required this.workouts,
    required this.dailyCheckIns,
    required this.habits,
    required this.settings,
  });

  final Map<dynamic, ExerciseHiveModel> exercises;
  final Map<dynamic, WorkoutHiveModel> workouts;
  final Map<dynamic, DailyCheckInHiveModel> dailyCheckIns;
  final Map<dynamic, HabitHiveModel> habits;
  final Map<dynamic, dynamic> settings;
}

Map<String, Object?> _exerciseToJson(ExerciseHiveModel value) =>
    <String, Object?>{
      'id': value.id,
      'name': value.name,
      'categoryIndex': value.categoryIndex,
      'primaryMuscleGroupIndex': value.primaryMuscleGroupIndex,
      'equipmentIndex': value.equipmentIndex,
      'instructions': value.instructions,
      'notes': value.notes,
      'isArchived': value.isArchived,
    };

ExerciseHiveModel _exerciseFromJson(Map<String, dynamic> value) =>
    ExerciseHiveModel(
      id: _string(value, 'id'),
      name: _string(value, 'name'),
      categoryIndex: _int(value, 'categoryIndex'),
      primaryMuscleGroupIndex: _nullableInt(value, 'primaryMuscleGroupIndex'),
      equipmentIndex: _int(value, 'equipmentIndex'),
      instructions: value['instructions'] as String?,
      notes: value['notes'] as String?,
      isArchived: _bool(value, 'isArchived'),
    );

Map<String, Object?> _workoutToJson(WorkoutHiveModel value) =>
    <String, Object?>{
      'id': value.id,
      'name': value.name,
      'scheduledDateMilliseconds': value.scheduledDateMilliseconds,
      'exerciseIds': value.exerciseIds,
      'sets': value.sets.map(_setToJson).toList(growable: false),
      'statusIndex': value.statusIndex,
      'startedAtMilliseconds': value.startedAtMilliseconds,
      'completedAtMilliseconds': value.completedAtMilliseconds,
      'notes': value.notes,
      'trackIndex': value.trackIndex,
      'warmUp': value.warmUp,
      'conditioningFormatIndex': value.conditioningFormatIndex,
      'conditioningTitle': value.conditioningTitle,
      'conditioningInstructions': value.conditioningInstructions,
      'prescribedRounds': value.prescribedRounds,
      'conditioningDurationMinutes': value.conditioningDurationMinutes,
      'roundsCompleted': value.roundsCompleted,
      'additionalReps': value.additionalReps,
      'completionTimeMilliseconds': value.completionTimeMilliseconds,
      'conditioningWeightKg': value.conditioningWeightKg,
      'conditioningScaling': value.conditioningScaling,
      'conditioningCompleted': value.conditioningCompleted,
    };

WorkoutHiveModel _workoutFromJson(Map<String, dynamic> value) =>
    WorkoutHiveModel(
      id: _string(value, 'id'),
      name: _string(value, 'name'),
      scheduledDateMilliseconds: _int(value, 'scheduledDateMilliseconds'),
      exerciseIds: _stringList(value, 'exerciseIds'),
      sets: _jsonValueList(value, 'sets').map(_setFromJson).toList(),
      statusIndex: _int(value, 'statusIndex'),
      startedAtMilliseconds: _nullableInt(value, 'startedAtMilliseconds'),
      completedAtMilliseconds: _nullableInt(value, 'completedAtMilliseconds'),
      notes: value['notes'] as String?,
      trackIndex: _nullableInt(value, 'trackIndex') ?? 0,
      warmUp: value['warmUp'] as String?,
      conditioningFormatIndex: _nullableInt(value, 'conditioningFormatIndex'),
      conditioningTitle: value['conditioningTitle'] as String?,
      conditioningInstructions: value['conditioningInstructions'] as String?,
      prescribedRounds: _nullableInt(value, 'prescribedRounds'),
      conditioningDurationMinutes:
          _nullableInt(value, 'conditioningDurationMinutes'),
      roundsCompleted: _nullableInt(value, 'roundsCompleted'),
      additionalReps: _nullableInt(value, 'additionalReps'),
      completionTimeMilliseconds:
          _nullableInt(value, 'completionTimeMilliseconds'),
      conditioningWeightKg: _nullableDouble(value, 'conditioningWeightKg'),
      conditioningScaling: value['conditioningScaling'] as String?,
      conditioningCompleted: _nullableBool(value, 'conditioningCompleted'),
    );

Map<String, Object?> _setToJson(WorkoutSetHiveModel value) => <String, Object?>{
      'id': value.id,
      'exerciseId': value.exerciseId,
      'setNumber': value.setNumber,
      'weightKg': value.weightKg,
      'reps': value.reps,
      'targetWeightKg': value.targetWeightKg,
      'targetReps': value.targetReps,
      'statusIndex': value.statusIndex,
      'rpe': value.rpe,
      'notes': value.notes,
    };

WorkoutSetHiveModel _setFromJson(Map<String, dynamic> value) =>
    WorkoutSetHiveModel(
      id: _string(value, 'id'),
      exerciseId: _string(value, 'exerciseId'),
      setNumber: _int(value, 'setNumber'),
      weightKg: _nullableDouble(value, 'weightKg'),
      reps: _nullableInt(value, 'reps'),
      targetWeightKg: _nullableDouble(value, 'targetWeightKg'),
      targetReps: _nullableInt(value, 'targetReps'),
      statusIndex: _int(value, 'statusIndex'),
      rpe: _nullableDouble(value, 'rpe'),
      notes: value['notes'] as String?,
    );

Map<String, Object?> _dailyCheckInToJson(DailyCheckInHiveModel value) =>
    <String, Object?>{
      'id': value.id,
      'dateMilliseconds': value.dateMilliseconds,
      'bodyWeightKg': value.bodyWeightKg,
      'proteinGrams': value.proteinGrams,
      'waterMillilitres': value.waterMillilitres,
      'steps': value.steps,
      'completedHabitIds': value.completedHabitIds,
      'heightCm': value.heightCm,
      'moodIndex': value.moodIndex,
      'energyLevel': value.energyLevel,
      'notes': value.notes,
    };

DailyCheckInHiveModel _dailyCheckInFromJson(Map<String, dynamic> value) =>
    DailyCheckInHiveModel(
      id: _string(value, 'id'),
      dateMilliseconds: _int(value, 'dateMilliseconds'),
      bodyWeightKg: _double(value, 'bodyWeightKg'),
      proteinGrams: _double(value, 'proteinGrams'),
      waterMillilitres: _double(value, 'waterMillilitres'),
      steps: _int(value, 'steps'),
      completedHabitIds: _stringList(value, 'completedHabitIds'),
      heightCm: _nullableDouble(value, 'heightCm'),
      moodIndex: _nullableInt(value, 'moodIndex'),
      energyLevel: _nullableInt(value, 'energyLevel'),
      notes: value['notes'] as String?,
    );

Map<String, Object?> _habitToJson(HabitHiveModel value) => <String, Object?>{
      'id': value.id,
      'name': value.name,
      'targetTypeIndex': value.targetTypeIndex,
      'targetValue': value.targetValue,
      'unitIndex': value.unitIndex,
      'activeDayIndexes': value.activeDayIndexes,
      'isActive': value.isActive,
    };

HabitHiveModel _habitFromJson(Map<String, dynamic> value) => HabitHiveModel(
      id: _string(value, 'id'),
      name: _string(value, 'name'),
      targetTypeIndex: _int(value, 'targetTypeIndex'),
      targetValue: _double(value, 'targetValue'),
      unitIndex: _int(value, 'unitIndex'),
      activeDayIndexes: _intList(value, 'activeDayIndexes'),
      isActive: _bool(value, 'isActive'),
    );

List<Map<String, dynamic>> _jsonValueList(
    Map<String, dynamic> value, String key) {
  final Object? values = value[key];
  if (values is! List<dynamic>) {
    throw BackupFormatException('The backup contains an invalid $key list.');
  }
  return values.map((Object? item) {
    if (item is! Map<String, dynamic>) {
      throw BackupFormatException(
          'The backup contains an invalid $key record.');
    }
    return item;
  }).toList(growable: false);
}

List<String> _stringList(Map<String, dynamic> value, String key) {
  final Object? values = value[key];
  if (values is! List<dynamic> ||
      values.any((Object? item) => item is! String)) {
    throw BackupFormatException('The backup contains an invalid $key list.');
  }
  return values.cast<String>();
}

List<int> _intList(Map<String, dynamic> value, String key) {
  final Object? values = value[key];
  if (values is! List<dynamic> || values.any((Object? item) => item is! num)) {
    throw BackupFormatException('The backup contains an invalid $key list.');
  }
  return values.cast<num>().map((num item) => item.toInt()).toList();
}

String _string(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result is! String) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result;
}

int _int(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result is! num) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result.toInt();
}

int? _nullableInt(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result == null) {
    return null;
  }
  if (result is! num) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result.toInt();
}

double _double(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result is! num) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result.toDouble();
}

double? _nullableDouble(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result == null) {
    return null;
  }
  if (result is! num) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result.toDouble();
}

bool _bool(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result is! bool) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result;
}

bool? _nullableBool(Map<String, dynamic> value, String key) {
  final Object? result = value[key];
  if (result == null) return null;
  if (result is! bool) {
    throw BackupFormatException('The backup has invalid $key.');
  }
  return result;
}
