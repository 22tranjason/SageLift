import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/sagelift_app.dart';
import 'core/storage/hive_local_key_value_store.dart';
import 'core/storage/key_value_store.dart';
import 'features/check_ins/data/local/daily_check_in_hive_store.dart';
import 'features/check_ins/data/repositories/hive_daily_check_in_repository.dart';
import 'features/check_ins/presentation/providers/daily_targets_controller.dart';
import 'features/habits/data/local/habit_hive_store.dart';
import 'features/habits/data/repositories/hive_habit_repository.dart';
import 'features/settings/data/services/sagelift_backup_service.dart';
import 'features/settings/presentation/providers/backup_restore_controller.dart';
import 'features/workouts/data/local/workout_hive_store.dart';
import 'features/workouts/data/repositories/hive_exercise_repository.dart';
import 'features/workouts/data/repositories/hive_workout_repository.dart';
import 'features/workouts/data/services/workout_seed_service.dart';
import 'features/workouts/presentation/providers/today_workout_provider.dart';

/// Starts the app after its offline storage dependency is ready.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final HiveLocalKeyValueStore localStore = HiveLocalKeyValueStore();
  await localStore.initialize();
  final WorkoutHiveStore workoutStore = await WorkoutHiveStore.open();
  final DailyCheckInHiveStore checkInStore = await DailyCheckInHiveStore.open();
  final HabitHiveStore habitStore = await HabitHiveStore.open();
  final HiveExerciseRepository exerciseRepository = HiveExerciseRepository(
    workoutStore.exerciseBox,
  );
  final HiveWorkoutRepository workoutRepository = HiveWorkoutRepository(
    workoutStore.workoutBox,
  );
  final HiveDailyCheckInRepository dailyCheckInRepository =
      HiveDailyCheckInRepository(checkInStore.checkInBox);
  final HiveHabitRepository habitRepository = HiveHabitRepository(
    habitStore.habitBox,
  );
  await WorkoutSeedService(
    exerciseRepository: exerciseRepository,
    workoutRepository: workoutRepository,
  ).seedIfEmpty();
  runApp(
    ProviderScope(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(localStore),
        exerciseRepositoryProvider.overrideWithValue(exerciseRepository),
        workoutRepositoryProvider.overrideWithValue(workoutRepository),
        dailyCheckInRepositoryProvider
            .overrideWithValue(dailyCheckInRepository),
        habitRepositoryProvider.overrideWithValue(habitRepository),
        sageLiftBackupServiceProvider.overrideWithValue(
          SageLiftBackupService(
            exerciseBox: workoutStore.exerciseBox,
            workoutBox: workoutStore.workoutBox,
            dailyCheckInBox: checkInStore.checkInBox,
            habitBox: habitStore.habitBox,
            settingsBox: localStore.box,
          ),
        ),
      ],
      child: const SageLiftApp(),
    ),
  );
}
