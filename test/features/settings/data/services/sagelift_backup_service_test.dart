import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/features/check_ins/data/adapters/daily_check_in_hive_adapters.dart';
import 'package:sagelift/features/check_ins/data/models/daily_check_in_hive_model.dart';
import 'package:sagelift/features/habits/data/adapters/habit_hive_adapters.dart';
import 'package:sagelift/features/habits/data/models/habit_hive_model.dart';
import 'package:sagelift/features/settings/data/services/sagelift_backup_service.dart';
import 'package:sagelift/features/workouts/data/adapters/workout_hive_adapters.dart';
import 'package:sagelift/features/workouts/data/models/exercise_hive_model.dart';
import 'package:sagelift/features/workouts/data/models/workout_hive_model.dart';
import 'package:sagelift/features/workouts/data/models/workout_set_hive_model.dart';

void main() {
  late Directory temporaryDirectory;
  late Box<ExerciseHiveModel> exerciseBox;
  late Box<WorkoutHiveModel> workoutBox;
  late Box<DailyCheckInHiveModel> checkInBox;
  late Box<HabitHiveModel> habitBox;
  late Box<dynamic> settingsBox;

  setUpAll(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('sagelift_backup_');
    Hive.init(temporaryDirectory.path);
    WorkoutHiveAdapters.registerAll();
    DailyCheckInHiveAdapters.registerAll();
    HabitHiveAdapters.registerAll();
    exerciseBox = await Hive.openBox<ExerciseHiveModel>('backup_exercises');
    workoutBox = await Hive.openBox<WorkoutHiveModel>('backup_workouts');
    checkInBox = await Hive.openBox<DailyCheckInHiveModel>('backup_check_ins');
    habitBox = await Hive.openBox<HabitHiveModel>('backup_habits');
    settingsBox = await Hive.openBox<dynamic>('backup_settings');
  });

  setUp(() async {
    await exerciseBox.clear();
    await workoutBox.clear();
    await checkInBox.clear();
    await habitBox.clear();
    await settingsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('backup includes workout records and daily target data', () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final SageLiftBackup backup = _service(
      exerciseBox,
      workoutBox,
      checkInBox,
      habitBox,
      settingsBox,
    ).createBackup();

    expect(backup.filename, 'sagelift-backup-2026-08-05.json');
    expect(backup.contents, contains('Completed workout'));
    expect(backup.contents, contains('proteinGrams'));
    expect(backup.contents, contains('completedHabitIds'));
  });

  test('invalid restore is rejected without replacing local data', () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final SageLiftBackupService service = _service(
      exerciseBox,
      workoutBox,
      checkInBox,
      habitBox,
      settingsBox,
    );

    await expectLater(
      service.restore('{"schemaVersion":99}'),
      throwsA(isA<BackupFormatException>()),
    );
    expect(workoutBox.get('workout-1')?.name, 'Completed workout');
    expect(checkInBox.get('check-in-1')?.proteinGrams, 160);
  });

  test('valid restore recovers replaced workouts and daily targets', () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final SageLiftBackupService service = _service(
      exerciseBox,
      workoutBox,
      checkInBox,
      habitBox,
      settingsBox,
    );
    final String contents = service.createBackup().contents;
    await workoutBox.clear();
    await checkInBox.clear();

    await service.restore(contents);

    expect(workoutBox.get('workout-1')?.name, 'Completed workout');
    expect(checkInBox.get('check-in-1')?.waterMillilitres, 2500);
    expect(checkInBox.get('check-in-1')?.completedHabitIds, <String>['walk']);
    expect(habitBox.get('habit-1')?.name, 'Walk');
  });
}

SageLiftBackupService _service(
  Box<ExerciseHiveModel> exerciseBox,
  Box<WorkoutHiveModel> workoutBox,
  Box<DailyCheckInHiveModel> checkInBox,
  Box<HabitHiveModel> habitBox,
  Box<dynamic> settingsBox,
) {
  return SageLiftBackupService(
    exerciseBox: exerciseBox,
    workoutBox: workoutBox,
    dailyCheckInBox: checkInBox,
    habitBox: habitBox,
    settingsBox: settingsBox,
    now: () => DateTime.utc(2026, 8, 5),
  );
}

Future<void> _seed(
  Box<ExerciseHiveModel> exerciseBox,
  Box<WorkoutHiveModel> workoutBox,
  Box<DailyCheckInHiveModel> checkInBox,
  Box<HabitHiveModel> habitBox,
  Box<dynamic> settingsBox,
) async {
  await exerciseBox.put(
    'exercise-1',
    ExerciseHiveModel(
      id: 'exercise-1',
      name: 'Bench Press',
      categoryIndex: 0,
      equipmentIndex: 0,
      isArchived: false,
    ),
  );
  await workoutBox.put(
    'workout-1',
    WorkoutHiveModel(
      id: 'workout-1',
      name: 'Completed workout',
      scheduledDateMilliseconds:
          DateTime.utc(2026, 8, 5).millisecondsSinceEpoch,
      exerciseIds: const <String>['exercise-1'],
      sets: const <WorkoutSetHiveModel>[],
      statusIndex: 2,
    ),
  );
  await checkInBox.put(
    'check-in-1',
    DailyCheckInHiveModel(
      id: 'check-in-1',
      dateMilliseconds: DateTime.utc(2026, 8, 5).millisecondsSinceEpoch,
      bodyWeightKg: 0,
      proteinGrams: 160,
      waterMillilitres: 2500,
      steps: 8000,
      completedHabitIds: const <String>['walk'],
    ),
  );
  await habitBox.put(
    'habit-1',
    HabitHiveModel(
      id: 'habit-1',
      name: 'Walk',
      targetTypeIndex: 0,
      targetValue: 1,
      unitIndex: 0,
      activeDayIndexes: const <int>[],
      isActive: true,
    ),
  );
  await settingsBox.put('app.theme_preference', 'dark');
}
