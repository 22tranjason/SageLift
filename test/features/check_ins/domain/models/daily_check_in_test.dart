import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/check_ins/domain/models/daily_check_in.dart';

void main() {
  final DailyCheckIn checkIn = DailyCheckIn(
    id: 'check-in-1',
    date: DateTime.utc(2026, 7, 29),
    bodyWeightKg: 80.2,
    heightCm: 180,
    proteinGrams: 160,
    waterMillilitres: 2800,
    mood: Mood.good,
    energyLevel: 4,
    notes: 'Slept well.',
  );

  test('uses value equality', () {
    expect(checkIn, equals(checkIn.copyWith()));
    expect(checkIn.hashCode, checkIn.copyWith().hashCode);
  });

  test('copyWith can intentionally clear nullable values', () {
    final DailyCheckIn cleared = checkIn.copyWith(
      heightCm: null,
      mood: null,
      energyLevel: null,
      notes: null,
    );

    expect(cleared.heightCm, isNull);
    expect(cleared.mood, isNull);
    expect(cleared.energyLevel, isNull);
    expect(cleared.notes, isNull);
  });
}
