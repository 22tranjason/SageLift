import '../models/workout.dart';
import '../models/workout_set.dart';

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

  /// Whether [workoutName] identifies one of SageLift's program workouts.
  static bool isProgramWorkoutName(String workoutName) {
    return workoutNames.contains(workoutName);
  }

  /// Returns the programme workout that follows [workoutName], looping forever.
  ///
  /// Returns null when [workoutName] is not part of this programme.
  static String? nextWorkoutName(String workoutName) {
    final int currentIndex = workoutNames.indexOf(workoutName);
    if (currentIndex == -1) return null;
    return workoutNames[(currentIndex + 1) % workoutNames.length];
  }

  /// Returns the last valid program completion, using its completion timestamp.
  ///
  /// Planned records, non-program workouts, and legacy completed records without
  /// a completion timestamp deliberately do not influence the program position.
  static Workout? latestValidCompletion(List<Workout> workouts) {
    final List<Workout> completions = workouts
        .where(isValidCompletedProgramWorkout)
        .toList(growable: false)
      ..sort(_compareCompletionDescending);
    return completions.isEmpty ? null : completions.first;
  }

  /// Whether [workout] is a timestamped completion from this program.
  static bool isValidCompletedProgramWorkout(Workout workout) {
    return workout.status == WorkoutStatus.completed &&
        workout.completedAt != null &&
        isProgramWorkoutName(workout.name);
  }

  /// Selects the next recommended program name from persisted completion history.
  ///
  /// A new program begins at Push A. Only the latest valid completion matters.
  static String recommendedNextWorkoutName(List<Workout> workouts) {
    final Workout? latestCompletion = latestValidCompletion(workouts);
    if (latestCompletion == null) return workoutNames.first;
    return nextWorkoutName(latestCompletion.name) ?? workoutNames.first;
  }

  /// Selects the active workout, or the planned session matching the recommendation.
  ///
  /// This intentionally ignores stale planned sessions for other program names.
  static Workout? nextIncompleteWorkout(List<Workout> workouts) {
    final List<Workout> inProgress = workouts
        .where((Workout workout) => workout.status == WorkoutStatus.inProgress)
        .toList(growable: false)
      ..sort(_compareActiveDescending);
    if (inProgress.isNotEmpty) return inProgress.first;

    final String recommendedName = recommendedNextWorkoutName(workouts);
    final List<Workout> plannedRecommended = workouts
        .where(
          (Workout workout) =>
              workout.status == WorkoutStatus.planned &&
              workout.name == recommendedName,
        )
        .toList(growable: false)
      ..sort(_comparePlannedDeterministically);
    return plannedRecommended.isEmpty ? null : plannedRecommended.first;
  }

  /// Creates a new planned session from a persisted program workout [template].
  ///
  /// Recorded set values are cleared, while programmed set targets and notes remain.
  static Workout createPlannedSession({
    required Workout template,
    required String id,
    required DateTime scheduledDate,
  }) {
    final List<WorkoutSet> plannedSets = <WorkoutSet>[
      for (int index = 0; index < template.sets.length; index++)
        template.sets[index].copyWith(
          id: '$id-set-${index + 1}',
          weightKg: null,
          reps: null,
          rpe: null,
          status: WorkoutSetStatus.planned,
        ),
    ];
    return template.copyWith(
      id: id,
      scheduledDate: scheduledDate,
      sets: plannedSets,
      status: WorkoutStatus.planned,
      startedAt: null,
      completedAt: null,
    );
  }

  static int _compareCompletionDescending(Workout first, Workout second) {
    final int comparison = second.completedAt!.compareTo(first.completedAt!);
    return comparison != 0 ? comparison : first.id.compareTo(second.id);
  }

  static int _compareActiveDescending(Workout first, Workout second) {
    final DateTime firstDate = first.startedAt ?? first.scheduledDate;
    final DateTime secondDate = second.startedAt ?? second.scheduledDate;
    final int comparison = secondDate.compareTo(firstDate);
    return comparison != 0 ? comparison : first.id.compareTo(second.id);
  }

  static int _comparePlannedDeterministically(Workout first, Workout second) {
    final int comparison = second.scheduledDate.compareTo(first.scheduledDate);
    return comparison != 0 ? comparison : first.id.compareTo(second.id);
  }
}
