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
import 'package:sagelift/features/workouts/domain/services/working_set_program.dart';
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

  test('all defaults have first four, others three minimum, calves four',
      () async {
    final _Repositories r = await _openRepositories();
    await WorkoutSeedService(
            exerciseRepository: r.exerciseRepository,
            workoutRepository: r.workoutRepository)
        .seedIfEmpty();
    for (final Workout w in await r.workoutRepository.getAll()) {
      _expectCounts(w);
      expect(WorkingSetProgram.migrateUnstarted(w), same(w));
    }
  });

  test(
      'legacy two-set variants, backups and clones upgrade without touching protected sessions',
      () async {
    final _Repositories r = await _openRepositories();
    final _BoxKeyValueStore settings =
        _BoxKeyValueStore(await Hive.openBox<dynamic>('working_sets_settings'));
    final WorkoutSeedService seed = WorkoutSeedService(
        exerciseRepository: r.exerciseRepository,
        workoutRepository: r.workoutRepository,
        settingsStore: settings);
    await seed.seedIfEmpty();
    final List<Workout> fresh = await r.workoutRepository.getAll();
    final List<Workout> old = <Workout>[];
    for (final Workout current in fresh) {
      old.add(_old(current));
    }
    final Workout back =
        fresh.singleWhere((Workout w) => w.name == 'Back + Biceps');
    for (final bool oldCurl in <bool>[false, true]) {
      for (final int row in <int>[2, 3]) {
        for (final int hammer in <int>[2, 3]) {
          final Workout v1 = _old(back, row: row, hammer: hammer);
          old.add(v1.copyWith(
              id: 'legacy-back-$oldCurl-$row-$hammer',
              exerciseIds: v1.exerciseIds
                  .map((String id) =>
                      oldCurl && id == 'seed-exercise-ez-bar-curl'
                          ? 'seed-exercise-alternating-dumbbell-curl'
                          : id)
                  .toList(),
              sets: v1.sets
                  .map((WorkoutSet s) => oldCurl &&
                          s.exerciseId == 'seed-exercise-ez-bar-curl'
                      ? s.copyWith(
                          exerciseId: 'seed-exercise-alternating-dumbbell-curl')
                      : s)
                  .toList()));
        }
      }
    }
    final Workout chest =
        _old(fresh.singleWhere((Workout w) => w.name == 'Chest + Triceps'));
    old.add(chest.copyWith(
        id: 'legacy-cable-fly',
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
                    ? s.copyWith(exerciseId: EquipmentProgramUpdate.cableFly)
                    : s)
            .toList()));
    final Workout legs =
        _old(fresh.singleWhere((Workout w) => w.name == 'Legs + Calves'));
    old.add(legs.copyWith(id: 'legacy-walkout', exerciseIds: <String>[
      ...legs.exerciseIds.take(3),
      EquipmentProgramUpdate.walkout,
      legs.exerciseIds.last
    ], sets: <WorkoutSet>[
      ...legs.sets,
      for (int n = 1; n <= 3; n++)
        WorkoutSet(
          id: 'walkout-$n',
          exerciseId: EquipmentProgramUpdate.walkout,
          setNumber: n,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
          notes:
              'Target 6–10 reps; each controlled heel walk out and back is one rep. Keep hips comfortably raised; use a short range initially. Rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
        )
    ]));
    final List<Workout> protected = <Workout>[];
    for (final Workout w in old.take(4)) {
      protected.addAll(<Workout>[
        w.copyWith(
            id: '${w.id}-completed',
            status: WorkoutStatus.completed,
            completedAt: DateTime.utc(2026, 10, 27),
            sets: w.sets
                .map((WorkoutSet s) => s.copyWith(
                    status: WorkoutSetStatus.completed,
                    weightKg: 22.5,
                    reps: 8))
                .toList()),
        w.copyWith(
            id: '${w.id}-active',
            status: WorkoutStatus.inProgress,
            startedAt: DateTime.utc(2026, 10, 27)),
        w.copyWith(
            id: '${w.id}-started', startedAt: DateTime.utc(2026, 10, 27)),
        w.copyWith(id: '${w.id}-skipped', status: WorkoutStatus.skipped),
        w.copyWith(id: '${w.id}-draft'),
        w.copyWith(id: '${w.id}-unknown-draft'),
        w.copyWith(id: '${w.id}-entered', sets: <WorkoutSet>[
          w.sets.first.copyWith(weightKg: 0.0),
          ...w.sets.skip(1)
        ]),
        w.copyWith(id: '${w.id}-custom', sets: <WorkoutSet>[
          w.sets.first.copyWith(notes: 'Custom prescription'),
          ...w.sets.skip(1)
        ]),
        w.copyWith(id: '${w.id}-custom-reps', sets: <WorkoutSet>[
          w.sets.first.copyWith(targetReps: 99),
          ...w.sets.skip(1)
        ]),
        w.copyWith(id: '${w.id}-custom-warmup', warmUp: 'Custom warmup'),
        w.copyWith(
            id: '${w.id}-custom-count',
            sets: w.sets
                .where((WorkoutSet s) =>
                    s.exerciseId != w.exerciseIds.first || s.setNumber < 3)
                .toList()),
      ]);
      await settings.write(
          'workouts.draft.v1.${w.id}-draft', '{"version":1,"entered":"22.5"}');
      await settings.write(
          'workouts.draft.v1.${w.id}-unknown-draft', '{"version":99}');
    }
    for (final Workout w in <Workout>[...old, ...protected]) {
      await r.workoutRepository.save(w);
    }
    await Hive.openBox<DailyCheckInHiveModel>('sets_check_ins');
    await Hive.openBox<HabitHiveModel>('sets_habits');
    SageLiftBackupService backup(_Repositories v) => SageLiftBackupService(
        exerciseBox: v.store.exerciseBox,
        workoutBox: v.store.workoutBox,
        dailyCheckInBox: Hive.box<DailyCheckInHiveModel>('sets_check_ins'),
        habitBox: Hive.box<HabitHiveModel>('sets_habits'),
        settingsBox: settings.box);
    final String beforeBackup = backup(r).createBackup().contents;
    final Map<dynamic, dynamic> beforeSettings = settings.box.toMap();
    final String beforeRecommendation =
        WorkoutProgram.recommendedNextWorkoutName(
            await r.workoutRepository.getAll());
    await seed.seedIfEmpty();
    final List<Workout> migrated = await r.workoutRepository.getAll();
    await seed.seedIfEmpty();
    expect(await r.workoutRepository.getAll(), migrated);
    await r.store.workoutBox.close();
    await r.store.exerciseBox.close();
    final _Repositories reopened = await _openRepositories();
    for (final Workout original in old) {
      final Workout actual =
          (await reopened.workoutRepository.getById(original.id))!;
      _expectCounts(actual);
      expect(actual.id, original.id);
      for (final WorkoutSet prior in original.sets) {
        if (prior.exerciseId == EquipmentProgramUpdate.walkout) continue;
        final WorkoutSet retained =
            actual.sets.singleWhere((WorkoutSet s) => s.id == prior.id);
        expect(retained.setNumber, prior.setNumber);
        expect(retained.targetReps, prior.targetReps);
        expect(retained.weightKg, prior.weightKg);
        expect(retained.reps, prior.reps);
      }
      final Workout factual = original.copyWith(
          status: WorkoutStatus.completed,
          completedAt: DateTime.utc(2026, 10, 27),
          sets: original.sets
              .map((WorkoutSet s) => s.copyWith(
                  status: WorkoutSetStatus.completed, weightKg: 12.5, reps: 8))
              .toList());
      final Workout clone = WorkoutProgram.createPlannedSession(
          template: factual,
          id: 'clone-${original.id}',
          scheduledDate: DateTime.utc(2026, 10, 28));
      _expectCounts(clone);
      expect(
          clone.sets
              .every((WorkoutSet s) => s.weightKg == null && s.reps == null),
          isTrue);
      expect(
          factual.sets
              .every((WorkoutSet s) => s.weightKg == 12.5 && s.reps == 8),
          isTrue);
    }
    for (final Workout w in protected) {
      expect(await reopened.workoutRepository.getById(w.id), w);
    }
    expect(settings.box.toMap(), beforeSettings);
    expect(
        WorkoutProgram.recommendedNextWorkoutName(
            await reopened.workoutRepository.getAll()),
        beforeRecommendation);
    final SageLiftBackupService restored = backup(reopened);
    await restored.restore(restored.createBackup().contents);
    expect(await reopened.workoutRepository.getAll(), migrated);
    await restored.restore(beforeBackup);
    await WorkoutSeedService(
            exerciseRepository: reopened.exerciseRepository,
            workoutRepository: reopened.workoutRepository,
            settingsStore: settings)
        .seedIfEmpty();
    expect(await reopened.workoutRepository.getAll(), migrated);
    expect(settings.box.toMap(), beforeSettings);
    await settings.box.close();
  });
}

Workout _old(Workout current, {int row = 3, int hammer = 2}) =>
    current.copyWith(
        sets: current.sets.where((WorkoutSet s) {
      final int count = s.exerciseId == current.exerciseIds.first
          ? 3
          : s.exerciseId == 'seed-exercise-dumbbell-reverse-lunge'
              ? 2
              : s.exerciseId == 'seed-exercise-chest-supported-dumbbell-row'
                  ? row
                  : s.exerciseId == 'seed-exercise-dumbbell-hammer-curl'
                      ? hammer
                      : 99;
      return s.setNumber <= count;
    }).toList());

void _expectCounts(Workout w) {
  final List<String> expected =
      WorkoutSeedService.defaultTemplateFor(w.name)!.exerciseIds;
  expect(w.exerciseIds, expected);
  for (int i = 0; i < w.exerciseIds.length; i++) {
    final String id = w.exerciseIds[i];
    final List<WorkoutSet> sets =
        w.sets.where((WorkoutSet s) => s.exerciseId == id).toList();
    final int count =
        i == 0 || id == 'seed-exercise-standing-dumbbell-calf-raise' ? 4 : 3;
    expect(sets, hasLength(count), reason: '${w.name}: $id');
    expect(sets.map((WorkoutSet s) => s.setNumber).toSet(),
        <int>{for (int n = 1; n <= count; n++) n});
  }
  expect(w.sets.map((WorkoutSet s) => s.id).toSet(), hasLength(w.sets.length));
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
