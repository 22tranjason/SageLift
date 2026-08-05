import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sagelift/features/check_ins/data/adapters/daily_check_in_hive_adapters.dart';
import 'package:sagelift/features/check_ins/data/local/daily_check_in_hive_store.dart';
import 'package:sagelift/features/check_ins/data/repositories/hive_daily_check_in_repository.dart';
import 'package:sagelift/features/check_ins/domain/models/daily_check_in.dart';

void main() {
  late Directory temporaryDirectory;

  setUpAll(() async {
    temporaryDirectory =
        await Directory.systemTemp.createTemp('sagelift_check_ins_');
    Hive.init(temporaryDirectory.path);
    DailyCheckInHiveAdapters.registerAll();
  });

  tearDownAll(() async {
    await Hive.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('persists one local-day daily target record including habit completion',
      () async {
    final DailyCheckInHiveStore store = await DailyCheckInHiveStore.open();
    final HiveDailyCheckInRepository repository =
        HiveDailyCheckInRepository(store.checkInBox);
    final DailyCheckIn checkIn = DailyCheckIn(
      id: 'daily-check-in-2026-08-05',
      date: DateTime(2026, 8, 5),
      bodyWeightKg: 0,
      proteinGrams: 160,
      waterMillilitres: 2500,
      steps: 8000,
      completedHabitIds: const <String>['walk'],
    );

    await repository.save(checkIn);

    expect(
      await repository.getByDate(DateTime(2026, 8, 5, 22, 30)),
      checkIn,
    );
    expect(await repository.getByDate(DateTime(2026, 8, 6)), isNull);
  });
}
