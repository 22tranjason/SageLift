import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/check_ins/data/adapters/daily_check_in_hive_adapters.dart';
import 'package:sagelift/features/check_ins/data/models/daily_check_in_hive_model.dart';
import 'package:sagelift/features/habits/data/adapters/habit_hive_adapters.dart';
import 'package:sagelift/features/habits/data/models/habit_hive_model.dart';
import 'package:sagelift/features/settings/data/services/sagelift_backup_service.dart';
import 'package:sagelift/features/workouts/data/adapters/workout_hive_adapters.dart';
import 'package:sagelift/features/workouts/data/models/exercise_hive_model.dart';
import 'package:sagelift/features/workouts/data/models/workout_hive_model.dart';
import 'package:sagelift/features/workouts/data/models/workout_set_hive_model.dart';
import 'package:sagelift/features/workouts/data/repositories/local_workout_draft_repository.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/domain/services/for_time_timer.dart';

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

  test('older backups without movement-specific fields remain restorable',
      () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final SageLiftBackupService service = _service(
      exerciseBox,
      workoutBox,
      checkInBox,
      habitBox,
      settingsBox,
    );
    final Map<String, dynamic> document =
        jsonDecode(service.createBackup().contents) as Map<String, dynamic>;
    final Map<String, dynamic> workout =
        (document['workouts'] as List<dynamic>).single as Map<String, dynamic>;
    workout
      ..remove('sessionDurationTarget')
      ..remove('conditioningMovementsJson')
      ..remove('conditioningMovementResultsJson');

    await workoutBox.clear();
    await service.restore(jsonEncode(document));

    expect(workoutBox.get('workout-1')?.trackIndex, 0);
    expect(workoutBox.get('workout-1')?.conditioningMovementsJson, isNull);
  });

  test('draft survives Hive reopening and existing backup restore format',
      () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final DateTime startedAt = DateTime.utc(2026, 9, 21, 8);
    final LocalWorkoutDraftRepository drafts =
        LocalWorkoutDraftRepository(_BoxKeyValueStore(settingsBox));
    await drafts.save(WorkoutDraft(
      workoutId: 'active-session',
      sets: const <String, WorkoutSetProgress>{
        'set-1': WorkoutSetProgress(weight: '87.5', reps: '9'),
      },
      conditioning: WorkoutConditioningProgress(
        timer: ForTimeTimer(
            startedAt: startedAt, elapsed: const Duration(seconds: 15)),
        movements: const <String, ConditioningMovementProgress>{
          'snatch':
              ConditioningMovementProgress(load: '22.5', modification: 'Hang'),
        },
      ),
    ));
    await drafts.flush();
    await settingsBox.close();
    settingsBox = await Hive.openBox<dynamic>('backup_settings');
    final WorkoutDraft reopened =
        await LocalWorkoutDraftRepository(_BoxKeyValueStore(settingsBox))
            .load('active-session');
    expect(reopened.sets['set-1']!.weight, '87.5');
    expect(reopened.sets['set-1']!.reps, '9');
    expect(reopened.conditioning.movements['snatch']!.load, '22.5');
    expect(reopened.conditioning.movements['snatch']!.modification, 'Hang');
    expect(
        reopened.conditioning.timer
            .elapsedAt(startedAt.add(const Duration(minutes: 2))),
        const Duration(seconds: 135));

    final SageLiftBackupService service =
        _service(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final String backup = service.createBackup().contents;
    expect((jsonDecode(backup) as Map<String, dynamic>)['schemaVersion'], 1);
    await settingsBox.clear();
    await service.restore(backup);
    final WorkoutDraft restored =
        await LocalWorkoutDraftRepository(_BoxKeyValueStore(settingsBox))
            .load('active-session');
    expect(restored.sets['set-1']!.weight, '87.5');
    expect(restored.conditioning.timer.startedAt, startedAt);
    expect(workoutBox.get('workout-1')!.name, 'Completed workout');
    expect(workoutBox.length, 1);
  });

  test('backup without draft keys restores with no migration or history edits',
      () async {
    await _seed(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final SageLiftBackupService service =
        _service(exerciseBox, workoutBox, checkInBox, habitBox, settingsBox);
    final String oldBackup = service.createBackup().contents;
    await LocalWorkoutDraftRepository(_BoxKeyValueStore(settingsBox))
        .save(WorkoutDraft(workoutId: 'active-session'));
    await service.restore(oldBackup);
    final WorkoutDraft empty =
        await LocalWorkoutDraftRepository(_BoxKeyValueStore(settingsBox))
            .load('active-session');
    expect(empty.sets, isEmpty);
    expect(empty.conditioning.timer.isRunning, isFalse);
    expect(settingsBox.keys, <String>['app.theme_preference']);
    expect(workoutBox.get('workout-1')!.statusIndex, 2);
  });
}

class _BoxKeyValueStore implements KeyValueStore {
  _BoxKeyValueStore(this.box);

  final Box<dynamic> box;

  @override
  Future<void> initialize() async {}

  @override
  Future<T?> read<T>(String key) async => box.get(key) as T?;

  @override
  Future<void> write<T>(String key, T value) => box.put(key, value);

  @override
  Future<void> delete(String key) => box.delete(key);
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
