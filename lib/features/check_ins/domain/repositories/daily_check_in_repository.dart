import '../models/daily_check_in.dart';

/// Contract for offline storage and retrieval of daily check-ins.
abstract interface class DailyCheckInRepository {
  /// Returns every stored daily check-in.
  Future<List<DailyCheckIn>> getAll();

  /// Returns the check-in for the calendar day represented by [date], or null.
  ///
  /// Implementations compare calendar days and ignore the time-of-day component.
  Future<DailyCheckIn?> getByDate(DateTime date);

  /// Inserts [checkIn] or replaces the existing record with the same stable ID.
  Future<void> save(DailyCheckIn checkIn);

  /// Deletes the check-in with [id].
  ///
  /// This operation is idempotent and succeeds when no matching record exists.
  Future<void> delete(String id);
}
