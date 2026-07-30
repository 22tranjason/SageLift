import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/sagelift_app.dart';
import 'core/storage/hive_local_key_value_store.dart';
import 'core/storage/key_value_store.dart';
import 'features/workouts/data/local/workout_hive_store.dart';
import 'features/workouts/data/repositories/hive_exercise_repository.dart';
import 'features/workouts/data/repositories/hive_workout_repository.dart';
import 'features/workouts/data/services/workout_seed_service.dart';

/// Starts the app after its offline storage dependency is ready.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final HiveLocalKeyValueStore localStore = HiveLocalKeyValueStore();
  await localStore.initialize();
  final WorkoutHiveStore workoutStore = await WorkoutHiveStore.open();
  await WorkoutSeedService(
    exerciseRepository: HiveExerciseRepository(workoutStore.exerciseBox),
    workoutRepository: HiveWorkoutRepository(workoutStore.workoutBox),
  ).seedIfEmpty();
  runApp(
    ProviderScope(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(localStore)
      ],
      child: const SageLiftApp(),
    ),
  );
}
