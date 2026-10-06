import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/key_value_store.dart';
import '../../data/repositories/local_workout_draft_repository.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_draft.dart';
import 'today_workout_provider.dart';

/// Shares one serialized write queue across all workout sessions.
final Provider<LocalWorkoutDraftRepository> workoutDraftRepositoryProvider =
    Provider<LocalWorkoutDraftRepository>((Ref ref) =>
        LocalWorkoutDraftRepository(ref.watch(keyValueStoreProvider)));

/// Clock shared by timer display, actions, and workout finalization.
final Provider<DateTime Function()> workoutClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Reports write failures while keeping editable in-memory entries available.
final StateProviderFamily<AsyncValue<void>, String> workoutDraftSaveProvider =
    StateProvider.family<AsyncValue<void>, String>(
        (Ref ref, String id) => const AsyncData<void>(null));

/// Locks session edits while its completion snapshot is being saved.
final StateProviderFamily<bool, String> workoutDraftFinishingProvider =
    StateProvider.family<bool, String>((Ref ref, String id) => false);

/// Loads a session before allowing edits, then persists every changed snapshot.
final AsyncNotifierProviderFamily<WorkoutDraftController, WorkoutDraft, String>
    workoutDraftControllerProvider =
    AsyncNotifierProvider.family<WorkoutDraftController, WorkoutDraft, String>(
        WorkoutDraftController.new);

/// Owns the complete strength/conditioning draft for one workout ID.
class WorkoutDraftController extends FamilyAsyncNotifier<WorkoutDraft, String> {
  bool _disposed = false;
  int _revision = 0;

  @override
  Future<WorkoutDraft> build(String arg) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final LocalWorkoutDraftRepository repository =
        ref.watch(workoutDraftRepositoryProvider);
    final Workout? workout =
        await ref.read(workoutRepositoryProvider).getById(arg);
    final WorkoutDraft draft = await repository.load(arg);
    if (workout?.track == WorkoutTrack.hybrid &&
        (workout?.status == WorkoutStatus.planned ||
            workout?.status == WorkoutStatus.inProgress)) {
      // Retire only the removed section; keep every raw strength entry.
      return draft.copyWith(conditioning: WorkoutConditioningProgress());
    }
    return draft;
  }

  /// Records raw entered weight.
  void updateWeight(String setId, String weight) {
    final WorkoutDraft current = state.requireValue;
    _update(current.copyWith(sets: <String, WorkoutSetProgress>{
      ...current.sets,
      setId: (current.sets[setId] ?? const WorkoutSetProgress())
          .copyWith(weight: weight),
    }));
  }

  /// Records raw entered repetitions.
  void updateReps(String setId, String reps) {
    final WorkoutDraft current = state.requireValue;
    _update(current.copyWith(sets: <String, WorkoutSetProgress>{
      ...current.sets,
      setId: (current.sets[setId] ?? const WorkoutSetProgress())
          .copyWith(reps: reps),
    }));
  }

  /// Replaces conditioning entries within this session.
  void updateConditioning(WorkoutConditioningProgress progress) =>
      _update(state.requireValue.copyWith(conditioning: progress));

  /// Records movement-specific loads and modifications.
  void updateMovement(
      String movementId, ConditioningMovementProgress progress) {
    final WorkoutConditioningProgress current = state.requireValue.conditioning;
    updateConditioning(current.copyWith(
      movements: <String, ConditioningMovementProgress>{
        ...current.movements,
        movementId: progress,
      },
    ));
  }

  /// Starts or resumes the timer without discarding manual time corrections.
  void startTimer(DateTime now) {
    final WorkoutConditioningProgress current = state.requireValue.conditioning;
    updateConditioning(current.copyWith(timer: current.timer.start(now)));
  }

  /// Pauses the timer and updates automatic editable time.
  void pauseTimer(DateTime now) {
    final WorkoutConditioningProgress current = state.requireValue.conditioning;
    updateConditioning(
        current.copyWith(timer: current.timer.pause(now)).withTimerTime());
  }

  /// Finalizes elapsed time, preserving any explicit manual correction.
  void finishTimer(DateTime now) =>
      updateConditioning(state.requireValue.conditioning.finishTimer(now));

  /// Explicitly replaces manual time with the current stopwatch duration.
  void useTimerTime(DateTime now) {
    final WorkoutConditioningProgress current = state.requireValue.conditioning;
    updateConditioning(current
        .copyWith(timer: current.timer.finish(now))
        .withTimerTime(replaceManual: true));
  }

  /// Persists the final timer snapshot before writing completed history.
  Future<WorkoutDraft> finalize(DateTime now) async {
    await future;
    final WorkoutDraft draft = state.requireValue.copyWith(
      conditioning: state.requireValue.conditioning.finishTimer(now),
    );
    state = AsyncData<WorkoutDraft>(draft);
    await _save(draft);
    return draft;
  }

  /// Removes this session only after completed history has been saved.
  Future<void> remove() async {
    await ref.read(workoutDraftRepositoryProvider).remove(arg);
    if (!_disposed) {
      state = AsyncData<WorkoutDraft>(WorkoutDraft(workoutId: arg));
    }
  }

  /// Retries the latest entries after a local storage error.
  Future<void> retrySave() => _save(state.requireValue);

  void _update(WorkoutDraft draft) {
    if (ref.read(workoutDraftFinishingProvider(arg))) return;
    state = AsyncData<WorkoutDraft>(draft);
    // Errors are displayed separately; they must not erase the editable draft.
    unawaited(_save(draft).catchError((Object _, StackTrace __) {}));
  }

  Future<void> _save(WorkoutDraft draft) async {
    final int revision = ++_revision;
    ref.read(workoutDraftSaveProvider(arg).notifier).state =
        const AsyncLoading<void>();
    try {
      await ref.read(workoutDraftRepositoryProvider).save(draft);
      if (!_disposed && revision == _revision) {
        ref.read(workoutDraftSaveProvider(arg).notifier).state =
            const AsyncData<void>(null);
      }
    } catch (error, stackTrace) {
      if (!_disposed && revision == _revision) {
        ref.read(workoutDraftSaveProvider(arg).notifier).state =
            AsyncError<void>(error, stackTrace);
      }
      rethrow;
    }
  }
}
