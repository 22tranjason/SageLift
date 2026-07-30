import 'workout_set_hive_model.dart';

/// Hive-specific representation of a workout aggregate.
class WorkoutHiveModel {
  /// Creates a persistence representation of a workout.
  WorkoutHiveModel({
    required this.id,
    required this.name,
    required this.scheduledDateMilliseconds,
    required List<String> exerciseIds,
    required List<WorkoutSetHiveModel> sets,
    required this.statusIndex,
    this.startedAtMilliseconds,
    this.completedAtMilliseconds,
    this.notes,
  })  : exerciseIds = List<String>.unmodifiable(exerciseIds),
        sets = List<WorkoutSetHiveModel>.unmodifiable(sets);

  /// Stable identifier used as the Hive box key.
  final String id;

  /// Stored workout name.
  final String name;

  /// Scheduled date encoded as milliseconds since the Unix epoch.
  final int scheduledDateMilliseconds;

  /// Ordered exercise identifiers for the workout.
  final List<String> exerciseIds;

  /// Persisted set records belonging to the workout.
  final List<WorkoutSetHiveModel> sets;

  /// Persisted index of the workout status enum.
  final int statusIndex;

  /// Start timestamp encoded as milliseconds since the Unix epoch, when present.
  final int? startedAtMilliseconds;

  /// Completion timestamp encoded as milliseconds since the Unix epoch, when present.
  final int? completedAtMilliseconds;

  /// Optional stored workout notes.
  final String? notes;
}
