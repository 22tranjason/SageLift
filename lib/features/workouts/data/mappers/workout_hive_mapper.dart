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
            ),
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
    );
  }
}

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
