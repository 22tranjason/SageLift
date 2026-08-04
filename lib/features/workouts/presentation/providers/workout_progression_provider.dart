import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/exercise_progression_service.dart';
import 'today_workout_provider.dart';

/// Identifies the exercise in a workout for which guidance is requested.
class ExerciseProgressionRequest {
  /// Creates a request for [exerciseId] within [workoutId].
  const ExerciseProgressionRequest({
    required this.workoutId,
    required this.exerciseId,
  });

  /// Workout containing the planned or active exercise sets.
  final String workoutId;

  /// Catalogue exercise to compare with prior persisted sets.
  final String exerciseId;

  @override
  bool operator ==(Object other) {
    return other is ExerciseProgressionRequest &&
        other.workoutId == workoutId &&
        other.exerciseId == exerciseId;
  }

  @override
  int get hashCode => Object.hash(workoutId, exerciseId);
}

/// Loads non-persistent next-session guidance for one exercise.
final FutureProviderFamily<ExerciseProgressionGuidance?,
        ExerciseProgressionRequest> exerciseProgressionGuidanceProvider =
    FutureProvider.family<ExerciseProgressionGuidance?,
        ExerciseProgressionRequest>(
  (Ref ref, ExerciseProgressionRequest request) async {
    final WorkoutRepository workoutRepository = ref.watch(
      workoutRepositoryProvider,
    );
    final Workout? workout = await workoutRepository.getById(
      request.workoutId,
    );
    if (workout == null) return null;

    final List<WorkoutSet> programmedSets = _setsForExercise(
      workout,
      request.exerciseId,
    );
    if (programmedSets.isEmpty) return null;

    final List<WorkoutSet> previousSets = await _previousCompletedSets(
      workoutRepository: workoutRepository,
      exerciseId: request.exerciseId,
      excludedWorkoutId: request.workoutId,
    );
    return const ExerciseProgressionService().suggest(
      programmedSets: programmedSets,
      previousCompletedSets: previousSets,
    );
  },
);

/// Loads per-exercise factual classifications for a completed workout summary.
final FutureProviderFamily<List<WorkoutExerciseProgression>, String>
    workoutProgressionSummaryProvider =
    FutureProvider.family<List<WorkoutExerciseProgression>, String>(
  (Ref ref, String workoutId) async {
    final WorkoutRepository workoutRepository = ref.watch(
      workoutRepositoryProvider,
    );
    final ExerciseRepository exerciseRepository = ref.watch(
      exerciseRepositoryProvider,
    );
    final Workout? workout = await workoutRepository.getById(workoutId);
    if (workout == null || workout.status != WorkoutStatus.completed) {
      return const <WorkoutExerciseProgression>[];
    }

    final ExerciseProgressionService service =
        const ExerciseProgressionService();
    final List<WorkoutExerciseProgression> progressions =
        <WorkoutExerciseProgression>[];
    for (final String exerciseId in workout.exerciseIds) {
      final List<WorkoutSet> currentSets = _setsForExercise(
        workout,
        exerciseId,
      )
          .where((WorkoutSet set) => set.status == WorkoutSetStatus.completed)
          .toList(
            growable: false,
          );
      if (currentSets.isEmpty) continue;

      final List<WorkoutSet> previousSets = await _previousCompletedSets(
        workoutRepository: workoutRepository,
        exerciseId: exerciseId,
        excludedWorkoutId: workout.id,
      );
      final Exercise? exercise = await exerciseRepository.getById(exerciseId);
      final ExerciseProgressionStatus status = service.classify(
        currentCompletedSets: currentSets,
        previousCompletedSets: previousSets,
        repRange: service.repRangeFor(currentSets.first),
      );
      progressions.add(
        WorkoutExerciseProgression(
          exerciseName: exercise?.name ?? exerciseId,
          status: status,
          nextStep: service.nextStepFor(status),
        ),
      );
    }
    return List<WorkoutExerciseProgression>.unmodifiable(progressions);
  },
);

/// Factual progression classification for one exercise in a completed workout.
class WorkoutExerciseProgression {
  /// Creates one completed workout exercise classification.
  const WorkoutExerciseProgression({
    required this.exerciseName,
    required this.status,
    required this.nextStep,
  });

  /// Resolved human-readable exercise name.
  final String exerciseName;

  /// Comparison with the most recent earlier completed session.
  final ExerciseProgressionStatus status;

  /// Concise factual guidance for the following session.
  final String nextStep;
}

List<WorkoutSet> _setsForExercise(Workout workout, String exerciseId) {
  return workout.sets
      .where((WorkoutSet set) => set.exerciseId == exerciseId)
      .toList(growable: false);
}

Future<List<WorkoutSet>> _previousCompletedSets({
  required WorkoutRepository workoutRepository,
  required String exerciseId,
  required String excludedWorkoutId,
}) async {
  final List<Workout> completedWorkouts = (await workoutRepository.getAll())
      .where(
        (Workout workout) =>
            workout.id != excludedWorkoutId &&
            workout.status == WorkoutStatus.completed,
      )
      .toList()
    ..sort(_compareByCompletionDateDescending);

  for (final Workout workout in completedWorkouts) {
    final List<WorkoutSet> completedSets = _setsForExercise(
      workout,
      exerciseId,
    )
        .where((WorkoutSet set) => set.status == WorkoutSetStatus.completed)
        .toList(
          growable: false,
        );
    if (completedSets.isNotEmpty) return completedSets;
  }
  return const <WorkoutSet>[];
}

int _compareByCompletionDateDescending(Workout first, Workout second) {
  return _completionDate(second).compareTo(_completionDate(first));
}

DateTime _completionDate(Workout workout) {
  return workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
}
