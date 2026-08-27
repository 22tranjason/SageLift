import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';

void main() {
  test('no Hybrid history recommends Push A Hybrid', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(const <Workout>[]),
      'Push A Hybrid',
    );
  });

  test('legacy PPL and CrossFit completions do not set the Hybrid position',
      () {
    final List<Workout> history = <Workout>[
      _completed(
        'Legs B',
        DateTime.utc(2026, 8, 1),
        track: WorkoutTrack.strengthPpl,
      ),
      _completed(
        'CrossFit F',
        DateTime.utc(2026, 8, 2),
        track: WorkoutTrack.crossFit,
      ),
    ];

    expect(
      WorkoutProgram.recommendedNextWorkoutName(history),
      'Push A Hybrid',
    );
  });

  test('Push A Hybrid completion recommends Pull A Hybrid', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        <Workout>[_completed('Push A Hybrid', DateTime.utc(2026, 8, 1, 7))],
      ),
      'Pull A Hybrid',
    );
  });

  test('Pull A Hybrid completion recommends Legs A Hybrid', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        <Workout>[_completed('Pull A Hybrid', DateTime.utc(2026, 8, 1, 7))],
      ),
      'Legs A Hybrid',
    );
  });

  test('loops through the complete Hybrid A/B programme', () {
    const List<String> expectedNextNames = <String>[
      'Pull A Hybrid',
      'Legs A Hybrid',
      'Push B Hybrid',
      'Pull B Hybrid',
      'Legs B Hybrid',
      'Push A Hybrid',
    ];

    for (int index = 0; index < WorkoutProgram.workoutNames.length; index++) {
      expect(
        WorkoutProgram.recommendedNextWorkoutName(
          <Workout>[
            _completed(
              WorkoutProgram.workoutNames[index],
              DateTime.utc(2026, 8, index + 1),
            ),
          ],
        ),
        expectedNextNames[index],
      );
    }
  });

  test('uses the latest Hybrid completion timestamp rather than list order',
      () {
    final List<Workout> workouts = <Workout>[
      _completed('Legs B Hybrid', DateTime.utc(2026, 8, 1, 7)),
      _completed('Pull A Hybrid', DateTime.utc(2026, 8, 3, 7)),
      _completed('Push A Hybrid', DateTime.utc(2026, 8, 2, 7)),
    ];

    expect(
      WorkoutProgram.recommendedNextWorkoutName(workouts),
      'Legs A Hybrid',
    );
  });

  test('planned legacy records never determine the Hybrid position', () {
    final List<Workout> workouts = <Workout>[
      _completed('Pull A Hybrid', DateTime.utc(2026, 8, 3, 7)),
      _planned('Push A', track: WorkoutTrack.strengthPpl),
      _planned('Legs A', track: WorkoutTrack.strengthPpl),
      _planned('Legs A Hybrid'),
    ];

    expect(
      WorkoutProgram.nextIncompleteWorkout(workouts)?.name,
      'Legs A Hybrid',
    );
  });

  test('prefers the active Hybrid workout so a manual choice can resume', () {
    final List<Workout> workouts = <Workout>[
      _completed('Push A Hybrid', DateTime.utc(2026, 8, 1, 7)),
      _planned('Pull A Hybrid'),
      _inProgress('Pull B Hybrid', DateTime.utc(2026, 8, 2, 6)),
    ];

    expect(
      WorkoutProgram.nextIncompleteWorkout(workouts)?.name,
      'Pull B Hybrid',
    );
  });

  test('only Hybrid workout names are selectable for future sessions', () {
    for (final String name in WorkoutProgram.workoutNames) {
      expect(WorkoutProgram.isSelectableWorkoutName(name), isTrue);
    }
    expect(WorkoutProgram.isSelectableWorkoutName('Push A'), isFalse);
    expect(WorkoutProgram.isSelectableWorkoutName('CrossFit A'), isFalse);
  });
}

Workout _completed(
  String name,
  DateTime completedAt, {
  WorkoutTrack track = WorkoutTrack.hybrid,
}) {
  return Workout(
    id: '${name.toLowerCase().replaceAll(' ', '-')}-${completedAt.microsecondsSinceEpoch}',
    name: name,
    scheduledDate: DateTime.utc(2026, 8, 1),
    status: WorkoutStatus.completed,
    completedAt: completedAt,
    track: track,
  );
}

Workout _planned(String name, {WorkoutTrack track = WorkoutTrack.hybrid}) {
  return Workout(
    id: 'planned-${name.toLowerCase().replaceAll(' ', '-')}',
    name: name,
    scheduledDate: DateTime.utc(2000),
    status: WorkoutStatus.planned,
    track: track,
  );
}

Workout _inProgress(String name, DateTime startedAt) {
  return Workout(
    id: 'active-${name.toLowerCase().replaceAll(' ', '-')}',
    name: name,
    scheduledDate: DateTime.utc(2026, 8, 2),
    status: WorkoutStatus.inProgress,
    startedAt: startedAt,
    track: WorkoutTrack.hybrid,
  );
}
