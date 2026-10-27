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
import 'package:sagelift/features/workouts/data/local/workout_hive_store.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_exercise_repository.dart';
import 'package:sagelift/features/workouts/data/repositories/hive_workout_repository.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/equipment_program_update.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sagelift_hive_',
    );
    Hive.init(temporaryDirectory.path);
    WorkoutHiveAdapters.registerAll();
    DailyCheckInHiveAdapters.registerAll();
    HabitHiveAdapters.registerAll();
  });

  setUp(() async {
    final WorkoutHiveStore store = await WorkoutHiveStore.open();
    await store.workoutBox.clear();
    await store.exerciseBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('equipment update preserves persisted history, drafts and backups',
      () async {
    final _Repositories repositories = await _openRepositories();
    final _BoxKeyValueStore settings = _BoxKeyValueStore(
      await Hive.openBox<dynamic>('equipment_settings'),
    );
    final WorkoutSeedService seed = WorkoutSeedService(
      exerciseRepository: repositories.exerciseRepository,
      workoutRepository: repositories.workoutRepository,
      settingsStore: settings,
    );
    await seed.seedIfEmpty();
    final List<Workout> fresh = await repositories.workoutRepository.getAll();
    final Workout chest =
        fresh.singleWhere((Workout w) => w.name == 'Chest + Triceps');
    final Workout legs =
        fresh.singleWhere((Workout w) => w.name == 'Legs + Calves');
    expect(chest.exerciseIds, hasLength(5));
    expect(chest.sets, hasLength(15));
    for (final String id in <String>[
      EquipmentProgramUpdate.dumbbellFly,
      EquipmentProgramUpdate.pushdown
    ]) {
      final List<WorkoutSet> sets =
          chest.sets.where((WorkoutSet s) => s.exerciseId == id).toList();
      expect(sets, hasLength(3));
      expect(sets.map((WorkoutSet s) => s.setNumber), <int>[1, 2, 3]);
      expect(
          sets.every((WorkoutSet s) =>
              s.targetReps == 15 &&
              s.notes!.contains('Target 10–15 reps; rest 75 sec')),
          isTrue);
    }
    expect(
        fresh.singleWhere((Workout w) => w.name == 'Back + Biceps').exerciseIds,
        hasLength(5));
    expect(
        fresh
            .singleWhere((Workout w) => w.name == 'Shoulders + Traps')
            .exerciseIds,
        hasLength(4));

    expect(legs.exerciseIds, hasLength(4));
    expect(legs.sets, hasLength(12));
    final List<Workout> originals = <Workout>[
      chest.copyWith(
        exerciseIds: chest.exerciseIds
            .where((String id) => id != EquipmentProgramUpdate.pushdown)
            .map((String id) => id == EquipmentProgramUpdate.dumbbellFly
                ? EquipmentProgramUpdate.cableFly
                : id)
            .toList(),
        sets: chest.sets
            .where((WorkoutSet s) =>
                s.exerciseId != EquipmentProgramUpdate.pushdown)
            .map((WorkoutSet s) =>
                s.exerciseId == EquipmentProgramUpdate.dumbbellFly
                    ? s.copyWith(
                        exerciseId: EquipmentProgramUpdate.cableFly,
                        targetWeightKg: 20.0)
                    : s)
            .toList(),
      ),
      legs.copyWith(
        exerciseIds: <String>[
          ...legs.exerciseIds.take(3),
          EquipmentProgramUpdate.walkout,
          legs.exerciseIds.last
        ],
        sets: <WorkoutSet>[
          ...legs.sets,
          for (int n = 1; n <= 3; n++)
            WorkoutSet(
              id: 'old-walkout-$n',
              exerciseId: EquipmentProgramUpdate.walkout,
              setNumber: n,
              targetReps: 10,
              status: WorkoutSetStatus.planned,
              notes:
                  'Target 6–10 reps; each controlled heel walk out and back is one rep. Keep hips comfortably raised; use a short range initially. Rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
            ),
        ],
      ),
    ];
    final List<Workout> protected = <Workout>[];
    for (final Workout original in originals) {
      final List<Workout> values = <Workout>[
        original.copyWith(
            id: '${original.id}-active',
            status: WorkoutStatus.inProgress,
            startedAt: DateTime.utc(2026, 10, 27)),
        original.copyWith(
            id: '${original.id}-started',
            startedAt: DateTime.utc(2026, 10, 27)),
        original.copyWith(
            id: '${original.id}-completed',
            status: WorkoutStatus.completed,
            completedAt: DateTime.utc(2026, 10, 26)),
        original.copyWith(
            id: '${original.id}-skipped', status: WorkoutStatus.skipped),
        original.copyWith(id: '${original.id}-draft'),
        original.copyWith(id: '${original.id}-unknown-draft'),
        original.copyWith(id: '${original.id}-logged', sets: <WorkoutSet>[
          original.sets.first.copyWith(weightKg: 30.0, reps: 5),
          ...original.sets.skip(1)
        ]),
        original.copyWith(id: '${original.id}-rpe', sets: <WorkoutSet>[
          original.sets.first.copyWith(rpe: 7.0),
          ...original.sets.skip(1)
        ]),
        original.copyWith(id: '${original.id}-set-skipped', sets: <WorkoutSet>[
          original.sets.first.copyWith(status: WorkoutSetStatus.skipped),
          ...original.sets.skip(1)
        ]),
        original.copyWith(id: '${original.id}-custom-notes', sets: <WorkoutSet>[
          original.sets.first.copyWith(notes: 'My custom prescription'),
          ...original.sets.skip(1)
        ]),
        original.copyWith(
            id: '${original.id}-custom',
            exerciseIds: original.exerciseIds.reversed.toList()),
        original.copyWith(id: '${original.id}-custom-reps', sets: <WorkoutSet>[
          original.sets.first.copyWith(targetReps: 99),
          ...original.sets.skip(1)
        ]),
      ];
      protected.addAll(values);
      await settings.write(
          'workouts.draft.v1.${original.id}-draft', '{"version":1,"sets":{}}');
      await settings.write(
          'workouts.draft.v1.${original.id}-unknown-draft', '{"version":99}');
      for (final Workout value in <Workout>[original, ...values]) {
        await repositories.workoutRepository.save(value);
      }
    }
    await Hive.openBox<DailyCheckInHiveModel>('equipment_check_ins');
    await Hive.openBox<HabitHiveModel>('equipment_habits');
    SageLiftBackupService backupService(_Repositories values) =>
        SageLiftBackupService(
          exerciseBox: values.store.exerciseBox,
          workoutBox: values.store.workoutBox,
          dailyCheckInBox:
              Hive.box<DailyCheckInHiveModel>('equipment_check_ins'),
          habitBox: Hive.box<HabitHiveModel>('equipment_habits'),
          settingsBox: settings.box,
        );
    final Map<String, dynamic> oldBackup =
        jsonDecode(backupService(repositories).createBackup().contents)
            as Map<String, dynamic>;
    (oldBackup['exercises'] as List<dynamic>).removeWhere((dynamic e) =>
        <String>[
          EquipmentProgramUpdate.dumbbellFly,
          EquipmentProgramUpdate.pushdown
        ].contains((e as Map<String, dynamic>)['id']));
    final Map<dynamic, dynamic> settingsBefore = settings.box.toMap();
    await seed.seedIfEmpty();
    final List<Workout> migrated =
        await repositories.workoutRepository.getAll();
    await seed.seedIfEmpty();
    expect(await repositories.workoutRepository.getAll(), migrated);
    await repositories.store.workoutBox.close();
    await repositories.store.exerciseBox.close();
    final _Repositories reopened = await _openRepositories();
    for (final Workout original in originals) {
      final Workout actual =
          (await reopened.workoutRepository.getById(original.id))!;
      final bool isChest = original.name == 'Chest + Triceps';
      expect(actual.id, original.id);
      expect(
          actual.exerciseIds, isChest ? chest.exerciseIds : legs.exerciseIds);
      expect(actual.sets, hasLength(isChest ? 15 : 12));
      for (final WorkoutSet set in original.sets) {
        if (set.exerciseId == EquipmentProgramUpdate.walkout) continue;
        final WorkoutSet migratedSet =
            actual.sets.singleWhere((WorkoutSet s) => s.id == set.id);
        expect(
            migratedSet,
            set.exerciseId == EquipmentProgramUpdate.cableFly
                ? set.copyWith(
                    exerciseId: EquipmentProgramUpdate.dumbbellFly,
                    targetWeightKg: null)
                : set);
      }
      final Workout history = original.copyWith(
          status: WorkoutStatus.completed,
          completedAt: DateTime.utc(2026, 10, 26),
          sets: original.sets
              .map((WorkoutSet s) => s.copyWith(
                  weightKg: 15.0, reps: 10, status: WorkoutSetStatus.completed))
              .toList());
      final Workout clone = WorkoutProgram.createPlannedSession(
          template: history,
          id: 'future-${original.id}',
          scheduledDate: DateTime.utc(2026, 10, 28));
      expect(clone.exerciseIds, actual.exerciseIds);
      expect(clone.sets, hasLength(actual.sets.length));
      expect(clone.sets.map((WorkoutSet s) => s.id).toSet(),
          hasLength(clone.sets.length));
      expect(
          clone.sets
              .every((WorkoutSet s) => s.weightKg == null && s.reps == null),
          isTrue);
      expect(EquipmentProgramUpdate.migrateUnstarted(clone), same(clone));
    }
    for (final Workout value in <Workout>[
      ...protected,
      ...fresh.where((Workout w) =>
          w.name == 'Back + Biceps' || w.name == 'Shoulders + Traps')
    ]) {
      expect(await reopened.workoutRepository.getById(value.id), value);
    }
    expect(settings.box.toMap(), settingsBefore);
    final SageLiftBackupService backup = backupService(reopened);
    await backup.restore(backup.createBackup().contents);
    expect(await reopened.workoutRepository.getAll(), migrated);
    await backup.restore(jsonEncode(oldBackup));
    await WorkoutSeedService(
            exerciseRepository: reopened.exerciseRepository,
            workoutRepository: reopened.workoutRepository,
            settingsStore: settings)
        .seedIfEmpty();
    expect(await reopened.workoutRepository.getAll(), migrated);
    expect(settings.box.toMap(), settingsBefore);
    for (final String id in <String>[
      EquipmentProgramUpdate.dumbbellFly,
      EquipmentProgramUpdate.pushdown,
      EquipmentProgramUpdate.cableFly,
      EquipmentProgramUpdate.walkout
    ]) {
      expect(await reopened.exerciseRepository.getById(id), isNotNull);
    }
    await settings.box.close();
  });
}

Future<_Repositories> _openRepositories() async {
  final WorkoutHiveStore store = await WorkoutHiveStore.open();
  return _Repositories(
    store: store,
    exerciseRepository: HiveExerciseRepository(store.exerciseBox),
    workoutRepository: HiveWorkoutRepository(store.workoutBox),
  );
}

class _Repositories {
  const _Repositories({
    required this.store,
    required this.exerciseRepository,
    required this.workoutRepository,
  });

  final WorkoutHiveStore store;
  final HiveExerciseRepository exerciseRepository;
  final HiveWorkoutRepository workoutRepository;
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
