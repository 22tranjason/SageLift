import 'conditioning.dart';
import 'workout_set.dart';

/// The independent training programme to which a workout belongs.
enum WorkoutTrack {
  /// Jason's repeating Push/Pull/Legs strength programme.
  strengthPpl,

  /// Jason's repeating CrossFit programme.
  crossFit,
}

/// The lifecycle state of a scheduled workout.
enum WorkoutStatus {
  /// The workout is planned but not started.
  planned,

  /// The workout is currently underway.
  inProgress,

  /// The workout was completed.
  completed,

  /// The workout was deliberately skipped.
  skipped,
}

/// A scheduled training session and its ordered exercise plan and set records.
class Workout {
  /// Creates an immutable workout aggregate.
  Workout({
    required this.id,
    required this.name,
    required this.scheduledDate,
    required this.status,
    List<String> exerciseIds = const <String>[],
    List<WorkoutSet> sets = const <WorkoutSet>[],
    this.startedAt,
    this.completedAt,
    this.notes,
    this.track = WorkoutTrack.strengthPpl,
    this.warmUp,
    this.conditioningPlan,
    this.conditioningResult,
    this.sessionDurationTarget,
  })  : _exerciseIds = List<String>.unmodifiable(exerciseIds),
        _sets = List<WorkoutSet>.unmodifiable(sets);

  /// Stable, client-generated identifier for this workout.
  final String id;

  /// Human-readable workout name.
  final String name;

  /// Calendar date on which the workout is intended to occur.
  final DateTime scheduledDate;

  /// Ordered catalogue exercise identifiers in the workout plan.
  List<String> get exerciseIds => _exerciseIds;
  final List<String> _exerciseIds;

  /// Planned or performed set records belonging to this workout.
  List<WorkoutSet> get sets => _sets;
  final List<WorkoutSet> _sets;

  /// Current lifecycle state of the workout.
  final WorkoutStatus status;

  /// Timestamp at which the workout was started, if it has begun.
  final DateTime? startedAt;

  /// Timestamp at which the workout was completed, if it has finished.
  final DateTime? completedAt;

  /// Optional free-form notes for the workout.
  final String? notes;

  /// Independent programme sequence that owns this workout.
  final WorkoutTrack track;

  /// Optional warm-up guidance, used by workouts that do not log warm-up sets.
  final String? warmUp;

  /// Optional conditioning prescription, used by CrossFit workouts.
  final ConditioningPlan? conditioningPlan;

  /// Optional factual conditioning result recorded when the workout finishes.
  final ConditioningResult? conditioningResult;

  /// Informational session-duration target, used by CrossFit seed workouts.
  final String? sessionDurationTarget;

  static const Object _unset = Object();

  /// Returns this workout with selected values replaced.
  ///
  /// Pass `null` to [startedAt], [completedAt], or [notes] to clear it. Lists
  /// are copied into unmodifiable collections before being exposed.
  Workout copyWith({
    String? id,
    String? name,
    DateTime? scheduledDate,
    List<String>? exerciseIds,
    List<WorkoutSet>? sets,
    WorkoutStatus? status,
    Object? startedAt = _unset,
    Object? completedAt = _unset,
    Object? notes = _unset,
    WorkoutTrack? track,
    Object? warmUp = _unset,
    Object? conditioningPlan = _unset,
    Object? conditioningResult = _unset,
    Object? sessionDurationTarget = _unset,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      exerciseIds: exerciseIds ?? _exerciseIds,
      sets: sets ?? _sets,
      status: status ?? this.status,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      track: track ?? this.track,
      warmUp: identical(warmUp, _unset) ? this.warmUp : warmUp as String?,
      conditioningPlan: identical(conditioningPlan, _unset)
          ? this.conditioningPlan
          : conditioningPlan as ConditioningPlan?,
      conditioningResult: identical(conditioningResult, _unset)
          ? this.conditioningResult
          : conditioningResult as ConditioningResult?,
      sessionDurationTarget: identical(sessionDurationTarget, _unset)
          ? this.sessionDurationTarget
          : sessionDurationTarget as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Workout &&
        other.id == id &&
        other.name == name &&
        other.scheduledDate == scheduledDate &&
        _listEquals(other._exerciseIds, _exerciseIds) &&
        _listEquals(other._sets, _sets) &&
        other.status == status &&
        other.startedAt == startedAt &&
        other.completedAt == completedAt &&
        other.notes == notes &&
        other.track == track &&
        other.warmUp == warmUp &&
        other.conditioningPlan == conditioningPlan &&
        other.conditioningResult == conditioningResult &&
        other.sessionDurationTarget == sessionDurationTarget;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        scheduledDate,
        Object.hashAll(_exerciseIds),
        Object.hashAll(_sets),
        status,
        startedAt,
        completedAt,
        notes,
        track,
        warmUp,
        conditioningPlan,
        conditioningResult,
        sessionDurationTarget,
      );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
