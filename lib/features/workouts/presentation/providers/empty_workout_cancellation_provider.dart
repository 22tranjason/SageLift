import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/local_workout_draft_repository.dart';
import '../../data/services/workout_seed_service.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_draft.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/working_set_program.dart';
import '../../domain/services/workout_program.dart';
import 'today_workout_provider.dart';
import 'workout_draft_controller.dart';

/// Cancels only the explicitly selected, verified-empty active default session.
final Provider<EmptyWorkoutCancellation> emptyWorkoutCancellationProvider =
    Provider<EmptyWorkoutCancellation>(
        (Ref ref) => EmptyWorkoutCancellation(ref));

/// Coordinates validation, draft cleanup and one session's lifecycle reset.
class EmptyWorkoutCancellation {
  /// Creates the session-scoped operation using the existing provider stores.
  EmptyWorkoutCancellation(this._ref);
  final Ref _ref;

  /// Returns the updated planned session; refuses unsafe or concurrent resets.
  Future<Workout> cancel(String id) async {
    if (_ref.read(workoutDraftFinishingProvider(id))) {
      throw StateError('This workout is busy. Try again after saving.');
    }
    _ref.read(workoutDraftFinishingProvider(id).notifier).state = true;
    try {
      // Wait for any loaded in-memory edits and queued writes before reading raw
      // storage. The presentation draft deliberately sanitizes conditioning.
      await _ref.read(workoutDraftControllerProvider(id).future);
      final LocalWorkoutDraftRepository drafts =
          _ref.read(workoutDraftRepositoryProvider);
      await drafts.flush();
      final WorkoutDraft raw = await drafts.loadForEmptyCancellation(id);
      final WorkoutConditioningProgress c = raw.conditioning;
      if (raw.sets.values.any((WorkoutSetProgress s) =>
              s.weight.trim().isNotEmpty || s.reps.trim().isNotEmpty) ||
          c.rounds.trim().isNotEmpty ||
          c.additionalReps.trim().isNotEmpty ||
          c.minutes.trim().isNotEmpty ||
          c.seconds.trim().isNotEmpty ||
          c.scaling.trim().isNotEmpty ||
          c.hasManualTime ||
          c.isCompleted ||
          c.timer.elapsed != Duration.zero ||
          c.timer.isRunning ||
          c.movements.values.any((ConditioningMovementProgress m) =>
              m.load.trim().isNotEmpty ||
              m.implementCount.trim().isNotEmpty ||
              m.modification.trim().isNotEmpty)) {
        throw StateError(
            'This workout has entries. Resume it to keep your data.');
      }
      final WorkoutRepository repository = _ref.read(workoutRepositoryProvider);
      final List<Workout> all = await repository.getAll();
      final Workout? original = await repository.getById(id);
      if (original == null ||
          original.status != WorkoutStatus.inProgress ||
          original.track != WorkoutTrack.hybrid ||
          original.completedAt != null ||
          WorkoutProgram.nextIncompleteWorkout(all)?.id != id ||
          original.sets.any((WorkoutSet s) =>
              s.status != WorkoutSetStatus.planned ||
              s.weightKg != null ||
              s.targetWeightKg != null ||
              s.reps != null ||
              s.rpe != null) ||
          original.notes != null ||
          original.conditioningPlan != null ||
          original.conditioningResult != null ||
          original.sets.map((WorkoutSet s) => s.id).toSet().length !=
              original.sets.length) {
        throw StateError(
            'Only the current empty default workout can be cancelled.');
      }
      final Workout planned = WorkingSetProgram.migrateUnstarted(
        original.copyWith(status: WorkoutStatus.planned, startedAt: null),
      );
      final Workout? template =
          WorkoutSeedService.defaultTemplateFor(original.name);
      bool matches = template != null &&
          planned.exerciseIds.join('|') == template.exerciseIds.join('|') &&
          planned.warmUp == template.warmUp &&
          planned.sessionDurationTarget == template.sessionDurationTarget &&
          planned.sets.length == template.sets.length;
      if (matches) {
        for (int i = 0; i < planned.sets.length; i++) {
          final WorkoutSet actual = planned.sets[i];
          final WorkoutSet expected = template.sets[i];
          if (actual.exerciseId != expected.exerciseId ||
              actual.setNumber != expected.setNumber ||
              actual.targetReps != expected.targetReps ||
              actual.notes != expected.notes) {
            matches = false;
          }
        }
      }
      if (!matches) {
        throw StateError('Custom workout plans cannot be cancelled here.');
      }
      if (await repository.getById(id) != original) {
        throw StateError('Workout changed. Resume it and try again.');
      }
      // Only a proven-empty draft is removed. If saving fails, the original
      // active record remains, and cancellation can safely be retried.
      await _ref.read(workoutDraftControllerProvider(id).notifier).remove();
      await repository.save(planned);
      if (await repository.getById(id) != planned) {
        throw StateError('Unable to save the cancelled workout.');
      }
      return planned;
    } finally {
      _ref.read(workoutDraftFinishingProvider(id).notifier).state = false;
      // A storage write can succeed before reporting an error. Always reload
      // persisted lifecycle state rather than leave a stale Resume action.
      _ref.read(workoutDataRevisionProvider.notifier).state++;
    }
  }
}
