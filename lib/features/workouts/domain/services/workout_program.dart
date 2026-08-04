import '../models/workout.dart';

/// Defines SageLift's repeating Push/Pull/Legs workout sequence.
class WorkoutProgram {
  WorkoutProgram._();

  /// The fixed programme order, which repeats indefinitely after Legs B.
  static const List<String> workoutNames = <String>[
    'Push A',
    'Pull A',
    'Legs A',
    'Push B',
    'Pull B',
    'Legs B',
  ];

  /// Returns the programme workout that follows [workoutName], looping forever.
  ///
  /// Returns null when [workoutName] is not part of this programme.
  static String? nextWorkoutName(String workoutName) {
    final int currentIndex = workoutNames.indexOf(workoutName);
    if (currentIndex == -1) return null;
    return workoutNames[(currentIndex + 1) % workoutNames.length];
  }

  /// Selects an in-progress workout, or the first planned workout in programme
  /// order. Completed workouts are deliberately never returned.
  static Workout? nextIncompleteWorkout(List<Workout> workouts) {
    for (final Workout workout in workouts) {
      if (workout.status == WorkoutStatus.inProgress) return workout;
    }

    for (final String workoutName in workoutNames) {
      for (final Workout workout in workouts) {
        if (workout.name == workoutName &&
            workout.status == WorkoutStatus.planned) {
          return workout;
        }
      }
    }
    return null;
  }
}
