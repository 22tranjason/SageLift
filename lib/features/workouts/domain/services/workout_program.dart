import '../models/workout.dart';
import '../models/workout_set.dart';

/// Selects the repeating programme sequence for each SageLift workout track.
class WorkoutProgram {
  WorkoutProgram._();

  /// The sole sequence available for new and future SageLift sessions.
  static const List<String> workoutNames = <String>[
    'Push A Hybrid',
    'Pull A Hybrid',
    'Legs A Hybrid',
    'Push B Hybrid',
    'Pull B Hybrid',
    'Legs B Hybrid',
  ];

  /// Legacy PPL names retained only to identify historical records safely.
  static const List<String> legacyStrengthWorkoutNames = <String>[
    'Push A',
    'Pull A',
    'Legs A',
    'Push B',
    'Pull B',
    'Legs B',
  ];

  /// Legacy CrossFit names retained only to identify historical records safely.
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
    switch (track) {
      case WorkoutTrack.strengthPpl:
        return legacyStrengthWorkoutNames;
      case WorkoutTrack.crossFit:
        return crossFitWorkoutNames;
      case WorkoutTrack.hybrid:
        return workoutNames;
    }
  }

  /// Whether [workoutName] belongs to the future Hybrid programme.
  static bool isSelectableWorkoutName(String workoutName) =>
      workoutNames.contains(workoutName);

  /// Whether [workoutName] is known to any present or historical programme.
  static bool isProgramWorkoutName(String workoutName) =>
      workoutNames.contains(workoutName) ||
      legacyStrengthWorkoutNames.contains(workoutName) ||
      crossFitWorkoutNames.contains(workoutName);

  /// Whether [workoutName] belongs to [track].
  static bool isProgramWorkoutNameForTrack(
    String workoutName,
    WorkoutTrack track,
  ) =>
      workoutNamesFor(track).contains(workoutName);

  /// Returns the track inferred from a known workout name.
  static WorkoutTrack? trackForWorkoutName(String workoutName) {
    if (workoutNames.contains(workoutName)) {
      return WorkoutTrack.hybrid;
    }
    if (legacyStrengthWorkoutNames.contains(workoutName)) {
      return WorkoutTrack.strengthPpl;
    }
    if (crossFitWorkoutNames.contains(workoutName)) {
      return WorkoutTrack.crossFit;
    }
    return null;
  }

  /// Returns the following workout in [track], looping continuously.
  static String? nextWorkoutName(String workoutName, {WorkoutTrack? track}) {
    final WorkoutTrack? resolvedTrack =
        track ?? trackForWorkoutName(workoutName);
    if (resolvedTrack == null) {
      return null;
    }
    final List<String> names = workoutNamesFor(resolvedTrack);
    final int index = names.indexOf(workoutName);
    if (index == -1) {
      return null;
    }
    return names[(index + 1) % names.length];
  }

  /// Returns the latest timestamped completion for [track].
  static Workout? latestValidCompletion(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.hybrid,
  }) {
    final List<Workout> values = workouts
        .where((Workout workout) =>
            isValidCompletedProgramWorkout(workout, track: track))
        .toList(growable: false)
      ..sort(_compareCompletionDescending);
    return values.isEmpty ? null : values.first;
  }

  /// Whether [workout] is a timestamped completion belonging to [track].
  static bool isValidCompletedProgramWorkout(
    Workout workout, {
    WorkoutTrack track = WorkoutTrack.hybrid,
  }) =>
      workout.status == WorkoutStatus.completed &&
      workout.completedAt != null &&
      workout.track == track &&
      isProgramWorkoutNameForTrack(workout.name, track);

  /// Recommends the next [track] workout solely from that track's history.
  static String recommendedNextWorkoutName(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.hybrid,
  }) {
    final Workout? latest = latestValidCompletion(workouts, track: track);
    if (latest == null) {
      return workoutNamesFor(track).first;
    }
    return nextWorkoutName(latest.name, track: track) ??
        workoutNamesFor(track).first;
  }

  /// Selects an active session or planned recommendation for [track].
  static Workout? nextIncompleteWorkout(
    List<Workout> workouts, {
    WorkoutTrack track = WorkoutTrack.hybrid,
  }) {
    final List<Workout> active = workouts
        .where((Workout workout) =>
            workout.track == track &&
            workout.status == WorkoutStatus.inProgress)
        .toList(growable: false)
      ..sort(_compareActiveDescending);
    if (active.isNotEmpty) {
      return active.first;
    }
    final String recommended =
        recommendedNextWorkoutName(workouts, track: track);
    final List<Workout> planned = workouts
        .where((Workout workout) =>
            workout.track == track &&
            workout.status == WorkoutStatus.planned &&
            workout.name == recommended)
        .toList(growable: false)
      ..sort(_comparePlannedDeterministically);
    return planned.isEmpty ? null : planned.first;
  }

  /// Creates a clean planned session from a persisted programme [template].
  static Workout createPlannedSession({
    required Workout template,
    required String id,
    required DateTime scheduledDate,
  }) =>
      template.copyWith(
        id: id,
        scheduledDate: scheduledDate,
        sets: <WorkoutSet>[
          for (int index = 0; index < template.sets.length; index++)
            template.sets[index].copyWith(
              id: '$id-set-${index + 1}',
              weightKg: null,
              reps: null,
              rpe: null,
              status: WorkoutSetStatus.planned,
            ),
        ],
        status: WorkoutStatus.planned,
        startedAt: null,
        completedAt: null,
        conditioningResult: null,
      );

  static int _compareCompletionDescending(Workout first, Workout second) {
    final int result = second.completedAt!.compareTo(first.completedAt!);
    return result != 0 ? result : first.id.compareTo(second.id);
  }

  static int _compareActiveDescending(Workout first, Workout second) {
    final DateTime firstDate = first.startedAt ?? first.scheduledDate;
    final DateTime secondDate = second.startedAt ?? second.scheduledDate;
    final int result = secondDate.compareTo(firstDate);
    return result != 0 ? result : first.id.compareTo(second.id);
  }

  static int _comparePlannedDeterministically(Workout first, Workout second) {
    final int result = second.scheduledDate.compareTo(first.scheduledDate);
    return result != 0 ? result : first.id.compareTo(second.id);
  }
}
