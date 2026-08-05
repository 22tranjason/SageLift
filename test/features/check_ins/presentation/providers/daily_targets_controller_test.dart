import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/check_ins/domain/models/daily_check_in.dart';
import 'package:sagelift/features/check_ins/domain/repositories/daily_check_in_repository.dart';
import 'package:sagelift/features/check_ins/presentation/providers/daily_targets_controller.dart';
import 'package:sagelift/features/habits/domain/models/habit.dart';
import 'package:sagelift/features/habits/domain/repositories/habit_repository.dart';

void main() {
  test('persists targets and resets values for a new local day', () async {
    final _FakeDailyCheckInRepository repository =
        _FakeDailyCheckInRepository();
    DateTime now = DateTime(2026, 8, 5, 7);
    final ProviderContainer firstContainer = _container(repository, () => now);
    addTearDown(firstContainer.dispose);
    final DailyTargetsController controller =
        firstContainer.read(dailyTargetsControllerProvider.notifier);

    await controller.refreshForCurrentDay();
    await controller.addProtein(35);
    await controller.addWater(250);
    await controller.setSteps(4200);
    await controller.setHabits(
      const <DailyHabitProgress>[
        DailyHabitProgress(id: 'mobility', name: 'Mobility'),
      ],
    );
    await controller.toggleHabit('mobility');

    final ProviderContainer reopenedContainer =
        _container(repository, () => now);
    addTearDown(reopenedContainer.dispose);
    await reopenedContainer
        .read(dailyTargetsControllerProvider.notifier)
        .refreshForCurrentDay();
    final DailyTargets restored =
        reopenedContainer.read(dailyTargetsControllerProvider);
    expect(restored.proteinGrams, 35);
    expect(restored.waterMillilitres, 250);
    expect(restored.steps, 4200);
    expect(restored.habits.single.isCompleted, isTrue);

    now = DateTime(2026, 8, 6, 7);
    await reopenedContainer
        .read(dailyTargetsControllerProvider.notifier)
        .refreshForCurrentDay();
    final DailyTargets nextDay =
        reopenedContainer.read(dailyTargetsControllerProvider);
    expect(nextDay.proteinGrams, 0);
    expect(nextDay.waterMillilitres, 0);
    expect(nextDay.steps, 0);
  });
}

ProviderContainer _container(
  DailyCheckInRepository repository,
  DateTime Function() now,
) {
  return ProviderContainer(
    overrides: <Override>[
      dailyCheckInRepositoryProvider.overrideWithValue(repository),
      habitRepositoryProvider.overrideWithValue(_FakeHabitRepository()),
      dailyTargetsNowProvider.overrideWithValue(now),
    ],
  );
}

class _FakeDailyCheckInRepository implements DailyCheckInRepository {
  final Map<String, DailyCheckIn> _records = <String, DailyCheckIn>{};

  @override
  Future<void> delete(String id) async {
    _records.remove(id);
  }

  @override
  Future<List<DailyCheckIn>> getAll() async => _records.values.toList();

  @override
  Future<DailyCheckIn?> getByDate(DateTime date) async {
    for (final DailyCheckIn checkIn in _records.values) {
      if (checkIn.date.year == date.year &&
          checkIn.date.month == date.month &&
          checkIn.date.day == date.day) {
        return checkIn;
      }
    }
    return null;
  }

  @override
  Future<void> save(DailyCheckIn checkIn) async {
    _records[checkIn.id] = checkIn;
  }
}

class _FakeHabitRepository implements HabitRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Habit>> getActive() async => <Habit>[
        Habit(
          id: 'mobility',
          name: 'Mobility',
          targetType: HabitTargetType.completion,
          targetValue: 1,
          unit: HabitUnit.none,
        ),
      ];

  @override
  Future<List<Habit>> getAll() async => const <Habit>[];

  @override
  Future<Habit?> getById(String id) async => null;

  @override
  Future<void> save(Habit habit) async {}
}
