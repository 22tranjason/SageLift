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
import 'package:sagelift/features/workouts/data/repositories/local_workout_draft_repository.dart';
import 'package:sagelift/features/workouts/data/services/workout_seed_service.dart';
import 'package:sagelift/features/workouts/domain/models/exercise.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
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

  test(
    'Back + Biceps v2 migrates persisted plans and protects history and drafts',
    () async {
      final _Repositories repositories = await _openRepositories();
      final _BoxKeyValueStore settings = _BoxKeyValueStore(
        await Hive.openBox<dynamic>('back_biceps_migration_settings'),
      );
      final WorkoutSeedService seed = WorkoutSeedService(
        exerciseRepository: repositories.exerciseRepository,
        workoutRepository: repositories.workoutRepository,
        settingsStore: settings,
      );
      await seed.seedIfEmpty();
      final List<Workout> fresh = await repositories.workoutRepository.getAll();
      final Workout v2 = fresh.singleWhere(
        (Workout w) => w.name == 'Back + Biceps',
      );
      const String oldCurl = 'seed-exercise-alternating-dumbbell-curl';
      const String newCurl = 'seed-exercise-ez-bar-curl';
      const String row = 'seed-exercise-chest-supported-dumbbell-row';
      const String hammer = 'seed-exercise-dumbbell-hammer-curl';
      final Workout v1 = v2.copyWith(
        exerciseIds: v2.exerciseIds
            .map((String id) => id == newCurl ? oldCurl : id)
            .toList(),
        sets: v2.sets
            .where(
              (WorkoutSet set) =>
                  !((set.exerciseId == row || set.exerciseId == hammer) &&
                      set.setNumber == 3),
            )
            .map(
              (WorkoutSet set) => set.exerciseId == newCurl
                  ? set.copyWith(
                      exerciseId: oldCurl,
                      id: '${set.id}-old',
                      targetWeightKg: 10.0,
                    )
                  : set,
            )
            .toList(),
      );
      final List<Workout> protected = <Workout>[
        v1.copyWith(
          id: 'active-v1',
          status: WorkoutStatus.inProgress,
          startedAt: DateTime.utc(2026, 10, 21),
        ),
        v1.copyWith(
          id: 'completed-v1',
          status: WorkoutStatus.completed,
          completedAt: DateTime.utc(2026, 10, 20),
        ),
        v1.copyWith(id: 'skipped-v1', status: WorkoutStatus.skipped),
        v1.copyWith(id: 'draft-v1'),
        v1.copyWith(id: 'unknown-draft-v1'),
        v1.copyWith(
          id: 'logged-v1',
          sets: <WorkoutSet>[
            v1.sets.first.copyWith(weightKg: 20.0, reps: 8),
            ...v1.sets.skip(1),
          ],
        ),
        v1.copyWith(id: 'retired-v1', name: 'Pull B Hybrid'),
      ];
      final WorkoutDraft draft = WorkoutDraft(
        workoutId: 'draft-v1',
        sets: <String, WorkoutSetProgress>{
          v1.sets.first.id: const WorkoutSetProgress(weight: '12.5', reps: '8'),
        },
      );
      await LocalWorkoutDraftRepository(settings).save(draft);
      await settings.write(
        'workouts.draft.v1.unknown-draft-v1',
        '{"version":99}',
      );
      final Map<dynamic, dynamic> settingsBefore = settings.box.toMap();
      for (final Workout workout in <Workout>[v1, ...protected]) {
        await repositories.workoutRepository.save(workout);
      }
      // Simulate a release-15 backup with no EZ-bar catalogue entry.
      SageLiftBackupService backupService(_Repositories values) =>
          SageLiftBackupService(
            exerciseBox: values.store.exerciseBox,
            workoutBox: values.store.workoutBox,
            dailyCheckInBox:
                Hive.box<DailyCheckInHiveModel>('migration_check_ins'),
            habitBox: Hive.box<HabitHiveModel>('migration_habits'),
            settingsBox: settings.box,
          );
      await Hive.openBox<DailyCheckInHiveModel>('migration_check_ins');
      await Hive.openBox<HabitHiveModel>('migration_habits');
      final Map<String, dynamic> oldBackup =
          jsonDecode(backupService(repositories).createBackup().contents)
              as Map<String, dynamic>;
      (oldBackup['exercises'] as List<dynamic>).removeWhere(
          (dynamic value) => (value as Map<String, dynamic>)['id'] == newCurl);
      await seed.seedIfEmpty();
      final List<Workout> migrated =
          await repositories.workoutRepository.getAll();
      await seed.seedIfEmpty();
      expect(await repositories.workoutRepository.getAll(), migrated);
      expect(settings.box.toMap(), settingsBefore);
      await repositories.store.workoutBox.close();
      await repositories.store.exerciseBox.close();
      final _Repositories reopened = await _openRepositories();
      final Workout actual = (await reopened.workoutRepository.getById(v1.id))!;
      expect(actual.id, v1.id);
      expect(actual.exerciseIds, v2.exerciseIds);
      expect(actual.sets, hasLength(16));
      for (final String id in <String>[row, newCurl, hammer]) {
        final List<WorkoutSet> sets = actual.sets
            .where((WorkoutSet set) => set.exerciseId == id)
            .toList();
        expect(sets, hasLength(3));
        expect(sets.map((WorkoutSet set) => set.setNumber), <int>[1, 2, 3]);
        expect(
          sets.every(
            (WorkoutSet set) => set.targetReps == (id == hammer ? 15 : 12),
          ),
          isTrue,
        );
        expect(
          sets.every(
            (WorkoutSet set) =>
                set.notes!.contains(id == row ? 'rest 120 sec' : 'rest 75 sec'),
          ),
          isTrue,
        );
      }
      expect(
        actual.sets
            .where((WorkoutSet set) => set.exerciseId == newCurl)
            .every((WorkoutSet set) => set.targetWeightKg == null),
        isTrue,
      );
      for (final WorkoutSet set in v1.sets.where(
        (WorkoutSet set) => set.exerciseId != oldCurl,
      )) {
        expect(actual.sets, contains(set));
      }
      for (final Workout workout in <Workout>[
        ...protected,
        ...fresh.where((Workout w) => w.name != 'Back + Biceps'),
      ]) {
        expect(await reopened.workoutRepository.getById(workout.id), workout);
      }
      final List<Exercise> exercises =
          await reopened.exerciseRepository.getAll();
      expect(
        exercises.singleWhere((Exercise e) => e.id == oldCurl).name,
        'Alternating Dumbbell Curl',
      );
      expect(
        exercises.singleWhere((Exercise e) => e.id == newCurl).name,
        'EZ-Bar Curl',
      );
      final Workout future = WorkoutProgram.createPlannedSession(
        template: protected[1],
        id: 'next-back',
        scheduledDate: DateTime.utc(2026, 10, 22),
      );
      expect(future.exerciseIds, v2.exerciseIds);
      expect(future.sets, hasLength(16));
      expect(
        future.sets.map((WorkoutSet set) => set.id).toSet(),
        hasLength(16),
      );
      expect(
        future.sets.every(
          (WorkoutSet set) => set.weightKg == null && set.reps == null,
        ),
        isTrue,
      );
      expect(
        (await LocalWorkoutDraftRepository(
          settings,
        ).load('draft-v1'))
            .sets[v1.sets.first.id]
            ?.weight,
        '12.5',
      );
      final SageLiftBackupService reloadedBackup = backupService(reopened);
      final String migratedBackup = reloadedBackup.createBackup().contents;
      await reloadedBackup.restore(migratedBackup);
      expect(await reopened.workoutRepository.getAll(), migrated);
      expect(settings.box.toMap(), settingsBefore);
      await reloadedBackup.restore(jsonEncode(oldBackup));
      expect(
          (await reopened.exerciseRepository.getAll())
              .any((Exercise e) => e.id == newCurl),
          isFalse);
      final WorkoutSeedService restoredSeed = WorkoutSeedService(
        exerciseRepository: reopened.exerciseRepository,
        workoutRepository: reopened.workoutRepository,
        settingsStore: settings,
      );
      await restoredSeed.seedIfEmpty();
      expect(await reopened.workoutRepository.getAll(), migrated);
      expect(settings.box.toMap(), settingsBefore);
      expect(
          (await reopened.exerciseRepository.getAll())
              .singleWhere((Exercise e) => e.id == oldCurl)
              .name,
          'Alternating Dumbbell Curl');
      expect(
          (await reopened.exerciseRepository.getAll())
              .singleWhere((Exercise e) => e.id == newCurl)
              .name,
          'EZ-Bar Curl');
      await settings.box.close();
    },
  );
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
