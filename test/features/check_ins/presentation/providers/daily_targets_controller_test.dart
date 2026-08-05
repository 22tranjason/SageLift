import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/check_ins/presentation/providers/daily_targets_controller.dart';

void main() {
  test('updates nutrition, water, steps, and habit completion in memory', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final DailyTargetsController controller =
        container.read(dailyTargetsControllerProvider.notifier);

    controller.addProtein(35);
    controller.addWater(250);
    controller.setSteps(4200);
    controller.setHabits(
      const <DailyHabitProgress>[
        DailyHabitProgress(id: 'mobility', name: 'Mobility'),
      ],
    );
    controller.toggleHabit('mobility');

    final DailyTargets targets = container.read(dailyTargetsControllerProvider);
    expect(targets.proteinGrams, 35);
    expect(targets.waterMillilitres, 250);
    expect(targets.steps, 4200);
    expect(targets.habits.single.isCompleted, isTrue);
  });
}
