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
    this.trackIndex = 0,
    this.warmUp,
    this.conditioningFormatIndex,
    this.conditioningTitle,
    this.conditioningInstructions,
    this.prescribedRounds,
    this.conditioningDurationMinutes,
    this.roundsCompleted,
    this.additionalReps,
    this.completionTimeMilliseconds,
    this.conditioningWeightKg,
    this.conditioningScaling,
    this.conditioningCompleted,
    this.sessionDurationTarget,
    this.conditioningMovementsJson,
    this.conditioningMovementResultsJson,
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

  /// Stored index of the independent workout track; omitted legacy data is PPL.
  final int trackIndex;

  /// Optional non-logged warm-up instructions.
  final String? warmUp;

  /// Stored conditioning-format enum index, when this workout has conditioning.
  final int? conditioningFormatIndex;

  /// Optional conditioning display title.
  final String? conditioningTitle;

  /// Optional conditioning movement instructions.
  final String? conditioningInstructions;

  /// Optional prescribed conditioning-round count.
  final int? prescribedRounds;

  /// Optional AMRAP or EMOM duration in minutes.
  final int? conditioningDurationMinutes;

  /// Recorded number of completed conditioning rounds.
  final int? roundsCompleted;

  /// Recorded repetitions completed after the last full conditioning round.
  final int? additionalReps;

  /// Recorded conditioning duration in milliseconds.
  final int? completionTimeMilliseconds;

  /// Optional load used in the conditioning section.
  final double? conditioningWeightKg;

  /// Optional scaling or modification used in conditioning.
  final String? conditioningScaling;

  /// Whether the prescribed conditioning work was completed.
  final bool? conditioningCompleted;

  /// Optional informational duration target for a CrossFit session.
  final String? sessionDurationTarget;

  /// JSON-encoded ordered conditioning-movement prescriptions.
  final String? conditioningMovementsJson;

  /// JSON-encoded movement-specific conditioning results.
  final String? conditioningMovementResultsJson;
}
