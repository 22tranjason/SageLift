import '../models/workout.dart';
import '../models/workout_set.dart';

/// Selects each independent repeating SageLift workout programme.
class WorkoutProgram {
  WorkoutProgram._();

  /// Fixed strength programme order, which repeats indefinitely after Legs B.
  static const List<String> workoutNames = <String>[
    'Push A',
    'Pull A',
    'Legs A',
    'Push B',
    'Pull B',
    'Legs B',
  ];

  /// Fixed CrossFit programme order, which repeats indefinitely after F.
  static const List<String> crossFitWorkoutNames = <String>[
    'CrossFit A',
    'CrossFit B',
    'CrossFit C',
    'CrossFit D',
    'CrossFit E',
    'CrossFit F',
  ];

  /// Names in programme order for [track].
  static List<String> workoutNamesFor(WorkoutTrack track) {
    return track == WorkoutTrack.crossFit ? crossFitWorkoutNames : workoutNames;
  }

  /// Whether [workoutName] is known to either built-in programme.
  static bool isProgramWorkoutName(String workoutName) {
    return workoutNames.contains(workoutName) ||
        crossFitWorkoutNames.contains(workoutName);
  }

  /// Whether [workoutName] belongs to [track].
  static bool isProgramWorkoutNameForTrack(
    String workoutName,
    WorkoutTrack track,
  ) {
    return workoutNamesFor(track).contains(workoutName);
  }

  /// Returns the programme track inferred from its known workout name.
  static WorkoutTrack? trackForWorkoutName(String workoutName) {
    if (workoutNames.contains(workoutName)) {
      return WorkoutTrack.strengthPpl;
    }
    if (crossFitWorkoutNames.contains(workoutName)) {
      return WorkoutTrack.crossFit;
    }
    return null;
  }

  /// Returns the following workout in [track], looping continuously.
  static String? nextWorkoutName(
    String workoutName, {
    WorkoutTrack? track,
  }) {
    final WorkoutTrack? resolvedTrack =
        track ?? trackForWorkoutName(workoutName);
    if (resolvedTrack == null) return null;
    final List<String> names = workoutNamesFor(resolvedTrack);
    final int currentIndex = names.indexOf(workoutName);
    if (currentIndex == -1) return null;
    return names[(currentIndex + 1) % names.length];
  }

  /// Returns the latest valid completed programme session for [track].
  static Workout? latestValidCompletion(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.strengthPpl,
  }) {
    final List<Workout> completions = workouts
        .where((Workout workout) =>
            isValidCompletedProgramWorkout(workout, track: track))
        .toList(growable: false)
      ..sort(_compareCompletionDescending);
    return completions.isEmpty ? null : completions.first;
  }

  /// Whether [workout] is a timestamped completion belonging to [track].
  static bool isValidCompletedProgramWorkout(
    Workout workout, {
    WorkoutTrack track = WorkoutTrack.strengthPpl,
  }) {
    return workout.status == WorkoutStatus.completed &&
        workout.completedAt != null &&
        workout.track == track &&
        isProgramWorkoutNameForTrack(workout.name, track);
  }

  /// Infers the next programme workout solely from [track]'s completed history.
  static String recommendedNextWorkoutName(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.strengthPpl,
  }) {
    final Workout? latestCompletion =
        latestValidCompletion(workouts, track: track);
    if (latestCompletion == null) return workoutNamesFor(track).first;
    return nextWorkoutName(latestCompletion.name, track: track) ??
        workoutNamesFor(track).first;
  }

  /// Selects the active session or planned recommended session for [track].
  static Workout? nextIncompleteWorkout(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.strengthPpl,
  }) {
    final List<Workout> inProgress = workouts
        .where(
          (Workout workout) =>
              workout.track == track &&
              workout.status == WorkoutStatus.inProgress,
        )
        .toList(growable: false)
      ..sort(_compareActiveDescending);
    if (inProgress.isNotEmpty) return inProgress.first;

    final String recommendedName =
        recommendedNextWorkoutName(workouts, track: track);
    final List<Workout> plannedRecommended = workouts
        .where(
          (Workout workout) =>
              workout.track == track &&
              workout.status == WorkoutStatus.planned &&
              workout.name == recommendedName,
        )
        .toList(growable: false)
      ..sort(_comparePlannedDeterministically);
    return plannedRecommended.isEmpty ? null : plannedRecommended.first;
  }

  /// Creates a planned session from a persisted programme [template].
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
      conditioningResult: null,
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
