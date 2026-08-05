import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/workout_completion_insights_service.dart';

void main() {
  test('calculates factual coaching inputs from a completed workout', () {
    final Workout workout = Workout(
      id: 'completed-push-a',
      name: 'Push A',
      scheduledDate: DateTime.utc(2026, 8, 5),
      status: WorkoutStatus.completed,
      exerciseIds: const <String>['bench', 'press'],
      sets: const <WorkoutSet>[
        WorkoutSet(
          id: 'bench-1',
          exerciseId: 'bench',
          setNumber: 1,
          targetReps: 8,
          status: WorkoutSetStatus.completed,
        ),
        WorkoutSet(
          id: 'bench-2',
          exerciseId: 'bench',
          setNumber: 2,
          targetReps: 8,
          status: WorkoutSetStatus.skipped,
        ),
        WorkoutSet(
          id: 'press-1',
          exerciseId: 'press',
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.skipped,
        ),
      ],
      startedAt: DateTime.utc(2026, 8, 5, 6, 23),
      completedAt: DateTime.utc(2026, 8, 5, 7, 5),
    );

    final WorkoutCompletionInsights insights =
        const WorkoutCompletionInsightsService().analyze(workout);

    expect(insights.duration, const Duration(minutes: 42));
    expect(insights.skippedExerciseIds, <String>['press']);
    expect(insights.skippedSets, 2);
    expect(insights.skippedReps, 18);
    expect(insights.completedPercentage, closeTo(33.33, 0.01));
  });
}
