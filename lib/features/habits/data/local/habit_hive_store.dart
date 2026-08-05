import 'package:hive_flutter/hive_flutter.dart';

import '../adapters/habit_hive_adapters.dart';
import '../models/habit_hive_model.dart';

/// Opens the typed Hive box used by recurring habit definitions.
class HabitHiveStore {
  /// Creates a store from an already-open habit box.
  const HabitHiveStore(this.habitBox);

  /// Public name used by backup and restore operations.
  static const String boxName = 'sagelift_habits';

  /// Typed storage for habit definitions.
  final Box<HabitHiveModel> habitBox;

  /// Registers adapters and opens local habit storage.
  static Future<HabitHiveStore> open() async {
    HabitHiveAdapters.registerAll();
    return HabitHiveStore(await Hive.openBox<HabitHiveModel>(boxName));
  }
}
