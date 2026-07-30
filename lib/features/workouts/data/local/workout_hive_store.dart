import 'package:hive_flutter/hive_flutter.dart';

import '../adapters/workout_hive_adapters.dart';
import '../models/exercise_hive_model.dart';
import '../models/workout_hive_model.dart';

/// Opens and exposes the typed Hive boxes used by workout persistence.
class WorkoutHiveStore {
  /// Creates a store from already-open typed Hive boxes.
  const WorkoutHiveStore({
    required this.exerciseBox,
    required this.workoutBox,
  });

  static const String _exerciseBoxName = 'sagelift_exercises';
  static const String _workoutBoxName = 'sagelift_workouts';

  /// Typed storage for exercise catalogue entries.
  final Box<ExerciseHiveModel> exerciseBox;

  /// Typed storage for workout aggregates.
  final Box<WorkoutHiveModel> workoutBox;

  /// Opens the workout boxes after registering their persistence adapters.
  static Future<WorkoutHiveStore> open() async {
    WorkoutHiveAdapters.registerAll();
    return WorkoutHiveStore(
      exerciseBox: await Hive.openBox<ExerciseHiveModel>(_exerciseBoxName),
      workoutBox: await Hive.openBox<WorkoutHiveModel>(_workoutBoxName),
    );
  }

  /// Whether no workout or exercise records have been stored yet.
  bool get isEmpty => exerciseBox.isEmpty && workoutBox.isEmpty;
}
