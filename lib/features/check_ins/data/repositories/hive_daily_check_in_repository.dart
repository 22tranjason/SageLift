import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/daily_check_in.dart';
import '../../domain/repositories/daily_check_in_repository.dart';
import '../mappers/daily_check_in_hive_mapper.dart';
import '../models/daily_check_in_hive_model.dart';

/// Hive-backed implementation of [DailyCheckInRepository].
class HiveDailyCheckInRepository implements DailyCheckInRepository {
  /// Creates a repository over the supplied typed check-in box.
  const HiveDailyCheckInRepository(this._box);

  final Box<DailyCheckInHiveModel> _box;

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<List<DailyCheckIn>> getAll() async {
    return _box.values
        .map((DailyCheckInHiveModel value) => value.toDomain())
        .toList(growable: false);
  }

  @override
  Future<DailyCheckIn?> getByDate(DateTime date) async {
    for (final DailyCheckInHiveModel value in _box.values) {
      final DailyCheckIn checkIn = value.toDomain();
      if (_sameLocalDay(checkIn.date, date)) return checkIn;
    }
    return null;
  }

  @override
  Future<void> save(DailyCheckIn checkIn) =>
      _box.put(checkIn.id, checkIn.toHiveModel());

  bool _sameLocalDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
