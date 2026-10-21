import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';

void main() {
  test('retired six-day history cannot advance the new rotation', () {
    for (final String name in WorkoutProgram.retiredHybridWorkoutNames) {
      expect(WorkoutProgram.isProgramWorkoutName(name), isTrue);
      expect(WorkoutProgram.isSelectableWorkoutName(name), isFalse);
      expect(
        WorkoutProgram.recommendedNextWorkoutName(<Workout>[
          _completed(name, DateTime.utc(2026, 10, 21)),
        ]),
        'Chest + Triceps',
      );
      final Workout active = _inProgress(name, DateTime.utc(2026, 10, 21));
      expect(WorkoutProgram.nextIncompleteWorkout(<Workout>[active]), active);
    }
  });

  test(
    'suggested rest days do not prevent manual selection or move rotation',
    () {
      expect(WorkoutProgram.weeklySchedule, contains('Thu: Rest'));
      expect(WorkoutProgram.weeklySchedule, contains('Sun + Mon: Rest'));
      expect(WorkoutProgram.workoutNames, hasLength(4));
      expect(
        WorkoutProgram.nextWorkoutName('Legs + Calves'),
        'Chest + Triceps',
      );
    },
  );

  test('no Hybrid history recommends Chest + Triceps', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(const <Workout>[]),
      'Chest + Triceps',
    );
  });

  test(
    'legacy PPL and CrossFit completions do not set the Hybrid position',
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
        'Chest + Triceps',
      );
    },
  );

  test('Chest + Triceps completion recommends Back + Biceps', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(<Workout>[
        _completed('Chest + Triceps', DateTime.utc(2026, 8, 1, 7)),
      ]),
      'Back + Biceps',
    );
  });

  test('Back + Biceps completion recommends Shoulders + Traps', () {
    expect(
      WorkoutProgram.recommendedNextWorkoutName(<Workout>[
        _completed('Back + Biceps', DateTime.utc(2026, 8, 1, 7)),
      ]),
      'Shoulders + Traps',
    );
  });

  test('loops through the complete four-day programme', () {
    const List<String> expectedNextNames = <String>[
      'Back + Biceps',
      'Shoulders + Traps',
      'Legs + Calves',
      'Chest + Triceps',
    ];

    for (int index = 0; index < WorkoutProgram.workoutNames.length; index++) {
      expect(
        WorkoutProgram.recommendedNextWorkoutName(<Workout>[
          _completed(
            WorkoutProgram.workoutNames[index],
            DateTime.utc(2026, 8, index + 1),
          ),
        ]),
        expectedNextNames[index],
      );
    }
  });

  test(
    'uses the latest Hybrid completion timestamp rather than list order',
    () {
      final List<Workout> workouts = <Workout>[
        _completed('Legs + Calves', DateTime.utc(2026, 8, 1, 7)),
        _completed('Back + Biceps', DateTime.utc(2026, 8, 3, 7)),
        _completed('Chest + Triceps', DateTime.utc(2026, 8, 2, 7)),
      ];

      expect(
        WorkoutProgram.recommendedNextWorkoutName(workouts),
        'Shoulders + Traps',
      );
    },
  );

  test('planned legacy records never determine the Hybrid position', () {
    final List<Workout> workouts = <Workout>[
      _completed('Back + Biceps', DateTime.utc(2026, 8, 3, 7)),
      _planned('Push A', track: WorkoutTrack.strengthPpl),
      _planned('Legs A', track: WorkoutTrack.strengthPpl),
      _planned('Shoulders + Traps'),
    ];

    expect(
      WorkoutProgram.nextIncompleteWorkout(workouts)?.name,
      'Shoulders + Traps',
    );
  });

  test('prefers the active Hybrid workout so a manual choice can resume', () {
    final List<Workout> workouts = <Workout>[
      _completed('Chest + Triceps', DateTime.utc(2026, 8, 1, 7)),
      _planned('Back + Biceps'),
      _inProgress('Shoulders + Traps', DateTime.utc(2026, 8, 2, 6)),
    ];

    expect(
      WorkoutProgram.nextIncompleteWorkout(workouts)?.name,
      'Shoulders + Traps',
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
