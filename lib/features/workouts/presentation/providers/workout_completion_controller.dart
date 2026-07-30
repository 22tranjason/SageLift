import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import 'today_workout_provider.dart';
import 'workout_set_progress_controller.dart';

/// Coordinates the persisted start and completion state of the active workout.
final Provider<WorkoutCompletionController>
    workoutCompletionControllerProvider =
    Provider<WorkoutCompletionController>((Ref ref) {
  return WorkoutCompletionController(
    workoutRepository: ref.watch(workoutRepositoryProvider),
    onWorkoutChanged: () => ref.invalidate(todayWorkoutProvider),
    clearSetProgress:
        ref.read(workoutSetProgressControllerProvider.notifier).clear,
    readSetProgress: () => ref.read(workoutSetProgressControllerProvider),
  );
});

/// Builds summary data for a completed workout and its resolved exercises.
final FutureProviderFamily<WorkoutSummary?, String> workoutSummaryProvider =
    FutureProvider.family<WorkoutSummary?, String>(
        (Ref ref, String workoutId) async {
  final WorkoutRepository workoutRepository = ref.watch(
    workoutRepositoryProvider,
  );
  final ExerciseRepository exerciseRepository = ref.watch(
    exerciseRepositoryProvider,
  );
  final Workout? workout = await workoutRepository.getById(workoutId);
  if (workout == null || workout.status != WorkoutStatus.completed) {
    return null;
  }

  final List<Exercise> exercises = <Exercise>[];
  for (final String exerciseId in workout.exerciseIds) {
    final Exercise? exercise = await exerciseRepository.getById(exerciseId);
    if (exercise != null) exercises.add(exercise);
  }
  return WorkoutSummary.fromWorkout(workout: workout, exercises: exercises);
});

/// Writes workout lifecycle changes through the existing offline repository.
class WorkoutCompletionController {
  /// Creates a controller using the workout repository and local set-entry state.
  const WorkoutCompletionController({
    required WorkoutRepository workoutRepository,
    required void Function() onWorkoutChanged,
    required void Function() clearSetProgress,
    required Map<String, WorkoutSetProgress> Function() readSetProgress,
  })  : _workoutRepository = workoutRepository,
        _onWorkoutChanged = onWorkoutChanged,
        _clearSetProgress = clearSetProgress,
        _readSetProgress = readSetProgress;

  final WorkoutRepository _workoutRepository;
  final void Function() _onWorkoutChanged;
  final void Function() _clearSetProgress;
  final Map<String, WorkoutSetProgress> Function() _readSetProgress;

  /// Starts [workout] once and persists its start time.
  ///
  /// A completed workout is returned as null so it cannot be completed again.
  Future<Workout?> startWorkout(Workout workout) async {
    final Workout? storedWorkout = await _workoutRepository.getById(workout.id);
    final Workout currentWorkout = storedWorkout ?? workout;
    if (currentWorkout.status == WorkoutStatus.completed) return null;
    if (currentWorkout.status == WorkoutStatus.inProgress) {
      return currentWorkout;
    }

    _clearSetProgress();
    final Workout startedWorkout = currentWorkout.copyWith(
      status: WorkoutStatus.inProgress,
      startedAt: DateTime.now(),
      completedAt: null,
    );
    await _workoutRepository.save(startedWorkout);
    _onWorkoutChanged();
    return startedWorkout;
  }

  /// Records entered sets, marks the workout complete, and persists it.
  ///
  /// Returns null when the workout is missing or was already completed.
  Future<Workout?> finishWorkout(String workoutId) async {
    final Workout? workout = await _workoutRepository.getById(workoutId);
    if (workout == null || workout.status == WorkoutStatus.completed) {
      return null;
    }

    final Map<String, WorkoutSetProgress> progressBySetId = _readSetProgress();
    final List<WorkoutSet> completedSets = workout.sets
        .map(
          (WorkoutSet set) => _completedSet(
            set,
            progressBySetId[set.id] ?? const WorkoutSetProgress(),
          ),
        )
        .toList(growable: false);
    final DateTime finishedAt = DateTime.now();
    final Workout completedWorkout = workout.copyWith(
      status: WorkoutStatus.completed,
      startedAt: workout.startedAt ?? finishedAt,
      completedAt: finishedAt,
      sets: completedSets,
    );
    await _workoutRepository.save(completedWorkout);
    _onWorkoutChanged();
    return completedWorkout;
  }

  WorkoutSet _completedSet(WorkoutSet set, WorkoutSetProgress progress) {
    if (!progress.isCompleted) return set;
    return set.copyWith(
      weightKg: double.tryParse(progress.weight),
      reps: int.tryParse(progress.completedReps),
      status: WorkoutSetStatus.completed,
    );
  }
}

/// Display-ready facts calculated from a completed workout's recorded sets.
class WorkoutSummary {
  /// Creates summary values calculated from completed workout data.
  const WorkoutSummary({
    required this.workout,
    required this.duration,
    required this.exercisesCompleted,
    required this.setsCompleted,
    required this.totalReps,
    required this.totalVolumeKg,
    required List<String> completedExerciseNames,
  }) : _completedExerciseNames = completedExerciseNames;

  /// Calculates summary values without persisting derived statistics.
  factory WorkoutSummary.fromWorkout({
    required Workout workout,
    required List<Exercise> exercises,
  }) {
    final List<WorkoutSet> completedSets = workout.sets
        .where((WorkoutSet set) => set.status == WorkoutSetStatus.completed)
        .toList(growable: false);
    final Set<String> completedExerciseIds =
        completedSets.map((WorkoutSet set) => set.exerciseId).toSet();
    final Map<String, Exercise> exercisesById = <String, Exercise>{
      for (final Exercise exercise in exercises) exercise.id: exercise,
    };
    final List<String> completedExerciseNames = workout.exerciseIds
        .where(completedExerciseIds.contains)
        .map((String id) => exercisesById[id]?.name ?? id)
        .toList(growable: false);
    final DateTime completedAt =
        workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
    final DateTime startedAt = workout.startedAt ?? completedAt;

    return WorkoutSummary(
      workout: workout,
      duration: completedAt.difference(startedAt),
      exercisesCompleted: completedExerciseIds.length,
      setsCompleted: completedSets.length,
      totalReps: completedSets.fold<int>(
        0,
        (int total, WorkoutSet set) => total + (set.reps ?? 0),
      ),
      totalVolumeKg: completedSets.fold<double>(
        0,
        (double total, WorkoutSet set) =>
            total + ((set.weightKg ?? 0) * (set.reps ?? 0)),
      ),
      completedExerciseNames: completedExerciseNames,
    );
  }

  /// Completed workout retained as the source for summary details.
  final Workout workout;

  /// Elapsed time from workout start until completion.
  final Duration duration;

  /// Number of exercises with at least one completed set.
  final int exercisesCompleted;

  /// Number of sets marked completed.
  final int setsCompleted;

  /// Sum of completed set repetitions.
  final int totalReps;

  /// Sum of weight multiplied by repetitions for completed weighted sets.
  final double totalVolumeKg;

  final List<String> _completedExerciseNames;

  /// Completed exercise names in the workout's prescribed order.
  List<String> get completedExerciseNames =>
      List<String>.unmodifiable(_completedExerciseNames);
}
