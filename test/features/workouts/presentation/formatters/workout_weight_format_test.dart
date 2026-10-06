import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/presentation/formatters/workout_weight_format.dart';

void main() {
  test('recorded fractional loads remain exact and whole loads stay tidy', () {
    expect(formatWorkoutWeight(82.5), '82.5');
    expect(formatWorkoutWeight(1.25), '1.25');
    expect(formatWorkoutWeight(82.75), '82.75');
    expect(formatWorkoutWeight(80), '80');
    expect(formatWorkoutWeight(0), '0');
    expect(formatWorkoutWeight(null), '—');
  });
}
