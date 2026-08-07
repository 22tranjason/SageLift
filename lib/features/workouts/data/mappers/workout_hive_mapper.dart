import 'dart:convert';

import '../../domain/models/conditioning.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../models/workout_hive_model.dart';
import '../models/workout_set_hive_model.dart';

/// Converts workout persistence models into domain models.
extension WorkoutHiveMapper on WorkoutHiveModel {
  /// Creates the equivalent framework-independent [Workout].
  Workout toDomain() {
    return Workout(
      id: id,
      name: name,
      scheduledDate: DateTime.fromMillisecondsSinceEpoch(
        scheduledDateMilliseconds,
        isUtc: true,
      ),
      exerciseIds: exerciseIds,
      sets: sets.map((WorkoutSetHiveModel set) => set.toDomain()).toList(),
      status: WorkoutStatus.values[statusIndex],
      startedAt: startedAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              startedAtMilliseconds!,
              isUtc: true,
            ),
      completedAt: completedAtMilliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              completedAtMilliseconds!,
              isUtc: true,
            ),
      notes: notes,
      track: _trackFromIndex(trackIndex),
      warmUp: warmUp,
      conditioningPlan: conditioningFormatIndex == null
          ? null
          : ConditioningPlan(
              format: _conditioningFormatFromIndex(conditioningFormatIndex!),
              title: conditioningTitle ?? '',
              instructions: conditioningInstructions ?? '',
              prescribedRounds: prescribedRounds,
              durationMinutes: conditioningDurationMinutes,
              movements: _movementsFromJson(conditioningMovementsJson),
            ),
      conditioningResult: roundsCompleted == null ||
              additionalReps == null ||
              conditioningCompleted == null
          ? null
          : ConditioningResult(
              roundsCompleted: roundsCompleted!,
              additionalReps: additionalReps!,
              completionTime: completionTimeMilliseconds == null
                  ? null
                  : Duration(milliseconds: completionTimeMilliseconds!),
              weightKg: conditioningWeightKg,
              scaling: conditioningScaling,
              isCompleted: conditioningCompleted!,
              movementResults: _movementResultsFromJson(
                conditioningMovementResultsJson,
              ),
            ),
      sessionDurationTarget: sessionDurationTarget,
    );
  }
}

/// Converts workout domain models into persistence models.
extension WorkoutDomainMapper on Workout {
  /// Creates the Hive-specific representation of this workout.
  WorkoutHiveModel toHiveModel() {
    return WorkoutHiveModel(
      id: id,
      name: name,
      scheduledDateMilliseconds: DateTime.utc(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
      ).millisecondsSinceEpoch,
      exerciseIds: exerciseIds,
      sets: sets.map((WorkoutSet set) => set.toHiveModel()).toList(),
      statusIndex: status.index,
      startedAtMilliseconds: startedAt?.toUtc().millisecondsSinceEpoch,
      completedAtMilliseconds: completedAt?.toUtc().millisecondsSinceEpoch,
      notes: notes,
      trackIndex: track.index,
      warmUp: warmUp,
      conditioningFormatIndex: conditioningPlan?.format.index,
      conditioningTitle: conditioningPlan?.title,
      conditioningInstructions: conditioningPlan?.instructions,
      prescribedRounds: conditioningPlan?.prescribedRounds,
      conditioningDurationMinutes: conditioningPlan?.durationMinutes,
      roundsCompleted: conditioningResult?.roundsCompleted,
      additionalReps: conditioningResult?.additionalReps,
      completionTimeMilliseconds:
          conditioningResult?.completionTime?.inMilliseconds,
      conditioningWeightKg: conditioningResult?.weightKg,
      conditioningScaling: conditioningResult?.scaling,
      conditioningCompleted: conditioningResult?.isCompleted,
      sessionDurationTarget: sessionDurationTarget,
      conditioningMovementsJson: _movementsToJson(conditioningPlan?.movements),
      conditioningMovementResultsJson:
          _movementResultsToJson(conditioningResult?.movementResults),
    );
  }
}

String? _movementsToJson(List<ConditioningMovement>? movements) {
  if (movements == null || movements.isEmpty) return null;
  return jsonEncode(<Map<String, Object?>>[
    for (final ConditioningMovement movement in movements)
      <String, Object?>{
        'id': movement.id,
        'name': movement.name,
        'prescribedReps': movement.prescribedReps,
        'prescribedDistance': movement.prescribedDistance,
        'distanceUnit': movement.distanceUnit?.index,
        'prescribedLoad': movement.prescribedLoad,
        'loadUnit': movement.loadUnit.index,
        'implementCount': movement.implementCount,
        'isBodyweight': movement.isBodyweight,
        'notes': movement.notes,
      },
  ]);
}

List<ConditioningMovement> _movementsFromJson(String? encoded) {
  if (encoded == null) return const <ConditioningMovement>[];
  try {
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! List<dynamic>) return const <ConditioningMovement>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> value) {
          return ConditioningMovement(
            id: value['id'] as String? ?? '',
            name: value['name'] as String? ?? '',
            prescribedReps: (value['prescribedReps'] as num?)?.toInt(),
            prescribedDistance:
                (value['prescribedDistance'] as num?)?.toDouble(),
            distanceUnit: _distanceUnit(value['distanceUnit'] as int?),
            prescribedLoad: (value['prescribedLoad'] as num?)?.toDouble(),
            loadUnit: _loadUnit(value['loadUnit'] as int?),
            implementCount: (value['implementCount'] as num?)?.toInt() ?? 1,
            isBodyweight: value['isBodyweight'] as bool? ?? false,
            notes: value['notes'] as String?,
          );
        })
        .where((ConditioningMovement movement) => movement.id.isNotEmpty)
        .toList(growable: false);
  } on FormatException {
    return const <ConditioningMovement>[];
  }
}

String? _movementResultsToJson(List<ConditioningMovementResult>? results) {
  if (results == null || results.isEmpty) return null;
  return jsonEncode(<Map<String, Object?>>[
    for (final ConditioningMovementResult result in results)
      <String, Object?>{
        'movementId': result.movementId,
        'actualLoad': result.actualLoad,
        'implementCount': result.implementCount,
        'modification': result.modification,
      },
  ]);
}

List<ConditioningMovementResult> _movementResultsFromJson(String? encoded) {
  if (encoded == null) return const <ConditioningMovementResult>[];
  try {
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! List<dynamic>) return const <ConditioningMovementResult>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> value) {
          return ConditioningMovementResult(
            movementId: value['movementId'] as String? ?? '',
            actualLoad: (value['actualLoad'] as num?)?.toDouble(),
            implementCount: (value['implementCount'] as num?)?.toInt(),
            modification: value['modification'] as String?,
          );
        })
        .where(
            (ConditioningMovementResult result) => result.movementId.isNotEmpty)
        .toList(growable: false);
  } on FormatException {
    return const <ConditioningMovementResult>[];
  }
}

DistanceUnit? _distanceUnit(int? index) =>
    index == null || index < 0 || index >= DistanceUnit.values.length
        ? null
        : DistanceUnit.values[index];

LoadUnit _loadUnit(int? index) =>
    index == null || index < 0 || index >= LoadUnit.values.length
        ? LoadUnit.kilograms
        : LoadUnit.values[index];

WorkoutTrack _trackFromIndex(int index) {
  return index >= 0 && index < WorkoutTrack.values.length
      ? WorkoutTrack.values[index]
      : WorkoutTrack.strengthPpl;
}

ConditioningFormat _conditioningFormatFromIndex(int index) {
  return index >= 0 && index < ConditioningFormat.values.length
      ? ConditioningFormat.values[index]
      : ConditioningFormat.roundsForTime;
}

/// Converts workout-set persistence models into domain models.
extension WorkoutSetHiveMapper on WorkoutSetHiveModel {
  /// Creates the equivalent framework-independent [WorkoutSet].
  WorkoutSet toDomain() {
    return WorkoutSet(
      id: id,
      exerciseId: exerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      targetWeightKg: targetWeightKg,
      targetReps: targetReps,
      status: WorkoutSetStatus.values[statusIndex],
      rpe: rpe,
      notes: notes,
    );
  }
}

/// Converts workout-set domain models into persistence models.
extension WorkoutSetDomainMapper on WorkoutSet {
  /// Creates the Hive-specific representation of this workout set.
  WorkoutSetHiveModel toHiveModel() {
    return WorkoutSetHiveModel(
      id: id,
      exerciseId: exerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      targetWeightKg: targetWeightKg,
      targetReps: targetReps,
      statusIndex: status.index,
      rpe: rpe,
      notes: notes,
    );
  }
}
