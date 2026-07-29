import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/habits/domain/models/habit.dart';

void main() {
  Habit createHabit({Set<Weekday>? activeDays}) {
    return Habit(
      id: 'habit-1',
      name: 'Drink water',
      targetType: HabitTargetType.quantity,
      targetValue: 2500,
      unit: HabitUnit.millilitres,
      activeDays: activeDays ?? <Weekday>{Weekday.monday, Weekday.wednesday},
    );
  }

  test('uses value equality for set contents regardless of insertion order',
      () {
    final Habit first = createHabit();
    final Habit equal = createHabit(
      activeDays: <Weekday>{Weekday.wednesday, Weekday.monday},
    );

    expect(first, equals(equal));
    expect(first.hashCode, equal.hashCode);
  });

  test('defensively copies and exposes an unmodifiable active-day set', () {
    final Set<Weekday> activeDays = <Weekday>{Weekday.monday};
    final Habit habit = createHabit(activeDays: activeDays);

    activeDays.add(Weekday.tuesday);

    expect(habit.activeDays, equals(<Weekday>{Weekday.monday}));
    expect(
      () => habit.activeDays.add(Weekday.tuesday),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('copyWith creates a new immutable active-day set', () {
    final Habit habit = createHabit();
    final Habit updated = habit.copyWith(
      activeDays: <Weekday>{Weekday.friday},
      isActive: false,
    );

    expect(updated.activeDays, equals(<Weekday>{Weekday.friday}));
    expect(updated.isActive, isFalse);
  });
}
