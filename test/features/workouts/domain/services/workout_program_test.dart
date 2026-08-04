import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';

void main() {
  test('loops from Legs B back to Push A', () {
    expect(WorkoutProgram.nextWorkoutName('Push A'), 'Pull A');
    expect(WorkoutProgram.nextWorkoutName('Legs B'), 'Push A');
  });

  test('never selects a completed workout as the next workout', () {
    final List<Workout> workouts = <Workout>[
      _workout('Push A', WorkoutStatus.completed),
      _workout('Pull A', WorkoutStatus.planned),
      _workout('Legs A', WorkoutStatus.planned),
    ];

    expect(WorkoutProgram.nextIncompleteWorkout(workouts)?.name, 'Pull A');
  });

  test('prefers an in-progress workout so it can be resumed', () {
    final List<Workout> workouts = <Workout>[
      _workout('Push A', WorkoutStatus.planned),
      _workout('Pull A', WorkoutStatus.inProgress),
    ];

    expect(WorkoutProgram.nextIncompleteWorkout(workouts)?.name, 'Pull A');
  });
}

Workout _workout(String name, WorkoutStatus status) {
  return Workout(
    id: name.toLowerCase().replaceAll(' ', '-'),
    name: name,
    scheduledDate: DateTime.utc(2026, 8, 5),
    status: status,
  );
}
