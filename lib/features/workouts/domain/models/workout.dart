import 'workout_set.dart';

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
        other.notes == notes;
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
