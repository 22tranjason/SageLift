import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';

void main() {
  test('no valid history recommends Push A', () {
    expect(
        WorkoutProgram.recommendedNextWorkoutName(const <Workout>[]), 'Push A');
  });

  test('Push A completion recommends Pull A', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        <Workout>[_completed('Push A', DateTime.utc(2026, 8, 1, 7))],
      ),
      'Pull A',
    );
  });

  test('Pull A completion recommends Legs A', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        <Workout>[_completed('Pull A', DateTime.utc(2026, 8, 1, 7))],
      ),
      'Legs A',
    );
  });

  test('loops through the complete A/B program', () {
    final List<String> expectedNextNames = <String>[
      'Pull A',
      'Legs A',
      'Push B',
      'Pull B',
      'Legs B',
      'Push A',
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

  test('uses the latest completion timestamp rather than list order', () {
    final List<Workout> workouts = <Workout>[
      _completed('Legs B', DateTime.utc(2026, 8, 1, 7)),
      _completed('Pull A', DateTime.utc(2026, 8, 3, 7)),
      _completed('Push A', DateTime.utc(2026, 8, 2, 7)),
    ];

    expect(WorkoutProgram.recommendedNextWorkoutName(workouts), 'Legs A');
  });

  test('planned seed records never determine the program position', () {
    final List<Workout> workouts = <Workout>[
      _completed('Pull A', DateTime.utc(2026, 8, 3, 7)),
      _planned('Push A'),
      _planned('Legs A'),
    ];

    expect(WorkoutProgram.nextIncompleteWorkout(workouts)?.name, 'Legs A');
  });

  test('prefers the active workout so manually selected work can be resumed',
      () {
    final List<Workout> workouts = <Workout>[
      _completed('Push A', DateTime.utc(2026, 8, 1, 7)),
      _planned('Pull A'),
      _inProgress('Pull B', DateTime.utc(2026, 8, 2, 6)),
    ];

    expect(WorkoutProgram.nextIncompleteWorkout(workouts)?.name, 'Pull B');
  });

  test('CrossFit starts at A without CrossFit history', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        const <Workout>[],
        track: WorkoutTrack.crossFit,
      ),
      'CrossFit A',
    );
  });

  test('CrossFit loops independently from A through F', () {
    final List<String> expected = <String>[
      'CrossFit B',
      'CrossFit C',
      'CrossFit D',
      'CrossFit E',
      'CrossFit F',
      'CrossFit A',
    ];
    for (int index = 0;
        index < WorkoutProgram.crossFitWorkoutNames.length;
        index++) {
      expect(
        WorkoutProgram.recommendedNextWorkoutName(
          <Workout>[
            _completed(
              WorkoutProgram.crossFitWorkoutNames[index],
              DateTime.utc(2026, 8, index + 1),
              track: WorkoutTrack.crossFit,
            ),
          ],
          track: WorkoutTrack.crossFit,
        ),
        expected[index],
      );
    }
  });

  test('CrossFit and PPL completions do not advance each other', () {
    final List<Workout> history = <Workout>[
      _completed('Pull A', DateTime.utc(2026, 8, 1),
          track: WorkoutTrack.strengthPpl),
      _completed('CrossFit C', DateTime.utc(2026, 8, 2),
          track: WorkoutTrack.crossFit),
    ];

    expect(WorkoutProgram.recommendedNextWorkoutName(history), 'Legs A');
    expect(
      WorkoutProgram.recommendedNextWorkoutName(
        history,
        track: WorkoutTrack.crossFit,
      ),
      'CrossFit D',
    );
  });
}

Workout _completed(
  String name,
  DateTime completedAt, {
  WorkoutTrack track = WorkoutTrack.strengthPpl,
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

Workout _planned(String name) {
  return Workout(
    id: 'planned-${name.toLowerCase().replaceAll(' ', '-')}',
    name: name,
    scheduledDate: DateTime.utc(2000),
    status: WorkoutStatus.planned,
  );
}

Workout _inProgress(String name, DateTime startedAt) {
  return Workout(
    id: 'active-${name.toLowerCase().replaceAll(' ', '-')}',
    name: name,
    scheduledDate: DateTime.utc(2026, 8, 2),
    status: WorkoutStatus.inProgress,
    startedAt: startedAt,
  );
}
