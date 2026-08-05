import 'package:hive_flutter/hive_flutter.dart';

import '../adapters/daily_check_in_hive_adapters.dart';
import '../models/daily_check_in_hive_model.dart';

/// Opens the typed Hive box used by local daily check-ins.
class DailyCheckInHiveStore {
  /// Creates a store from an already-open check-in box.
  const DailyCheckInHiveStore(this.checkInBox);

  /// Public name used by backup and restore operations.
  static const String boxName = 'sagelift_daily_check_ins';

  /// Typed storage for one check-in per local calendar day.
  final Box<DailyCheckInHiveModel> checkInBox;

  /// Registers adapters and opens local check-in storage.
  static Future<DailyCheckInHiveStore> open() async {
    DailyCheckInHiveAdapters.registerAll();
    return DailyCheckInHiveStore(
      await Hive.openBox<DailyCheckInHiveModel>(boxName),
    );
  }
}
