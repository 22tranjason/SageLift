import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/exercise_progression_service.dart';
import 'package:sagelift/features/workouts/domain/services/previous_exercise_workout.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_progression_provider.dart';

import '../../../../support/workout_draft_fakes.dart';

Workout completed(String id, int day, double weight) {
  final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid);
  return base.copyWith(
    id: id,
    status: WorkoutStatus.completed,
    completedAt: DateTime.utc(2026, 9, day),
    sets: <WorkoutSet>[
      base.sets.single.copyWith(
          status: WorkoutSetStatus.completed,
          weightKg: weight,
          reps: 8,
          notes: 'Target 6–10 reps')
    ],
  );
}

void main() {
  test(
      'historical lookup excludes newer/equal/self and selects earlier deterministically',
      () {
    final Workout viewed = completed('viewed', 20, 82.5);
    final Workout alpha = completed('a-earlier', 19, 80);
    final List<Workout> sessions = <Workout>[
      completed('newer', 21, 90),
      completed('equal', 20, 90),
      viewed,
      completed('z-earlier', 19, 70),
      alpha,
      completed('older', 18, 65),
    ];
    expect(
        previousExerciseWorkout(
            workouts: sessions, exerciseId: 'press', viewedWorkout: viewed),
        alpha);
    expect(
        previousExerciseWorkout(
            workouts: sessions.reversed,
            exerciseId: 'press',
            viewedWorkout: viewed),
        alpha);
    expect(
        previousExerciseWorkout(
            workouts: sessions, exerciseId: 'missing', viewedWorkout: viewed),
        isNull);
  });

  test(
      'planned/active sessions use latest history; timestamp fallback is strict',
      () {
    final Workout latest = completed('latest', 21, 90);
    final Workout current = draftTestWorkout(track: WorkoutTrack.hybrid);
    for (final WorkoutStatus status in <WorkoutStatus>[
      WorkoutStatus.planned,
      WorkoutStatus.inProgress
    ]) {
      expect(
          previousExerciseWorkout(
              workouts: <Workout>[latest],
              exerciseId: 'press',
              viewedWorkout: current.copyWith(status: status)),
          latest);
    }
    final Workout fallback = completed('fallback', 20, 80)
        .copyWith(completedAt: null, startedAt: DateTime.utc(2026, 9, 20));
    expect(
        previousExerciseWorkout(
            workouts: <Workout>[completed('equal', 20, 82.5), latest],
            exerciseId: 'press',
            viewedWorkout: fallback),
        isNull);
  });

  test('summary and per-set context agree on the actual earlier result',
      () async {
    final Workout viewed = completed('viewed', 20, 82.5);
    final DraftWorkoutRepository repository = DraftWorkoutRepository(<Workout>[
      viewed,
      completed('newer', 21, 90),
      completed('equal', 20, 95),
      completed('earlier', 19, 80),
    ]);
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      workoutRepositoryProvider.overrideWithValue(repository),
      exerciseRepositoryProvider.overrideWithValue(DraftExerciseRepository()),
    ]);
    addTearDown(container.dispose);
    final previous = await container.read(
        previousWorkoutExercisePerformanceProvider(
                const ExerciseProgressionRequest(
                    workoutId: 'viewed', exerciseId: 'press'))
            .future);
    expect(previous!.workout.id, 'earlier');
    expect(previous.sets.single.weightKg, 80);
    final progress = await container
        .read(workoutProgressionSummaryProvider('viewed').future);
    expect(progress.single.status, ExerciseProgressionStatus.improvedByWeight);
    expect(repository.values['viewed'], viewed);
  });

  test('equal or newer history only produces explicit first-session comparison',
      () async {
    final DraftWorkoutRepository repository = DraftWorkoutRepository(<Workout>[
      completed('viewed', 20, 82.5),
      completed('equal', 20, 80),
      completed('newer', 21, 90),
    ]);
    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      workoutRepositoryProvider.overrideWithValue(repository),
      exerciseRepositoryProvider.overrideWithValue(DraftExerciseRepository()),
    ]);
    addTearDown(container.dispose);
    expect(
        await container.read(previousWorkoutExercisePerformanceProvider(
                const ExerciseProgressionRequest(
                    workoutId: 'viewed', exerciseId: 'press'))
            .future),
        isNull);
    expect(
        (await container
                .read(workoutProgressionSummaryProvider('viewed').future))
            .single
            .status,
        ExerciseProgressionStatus.firstSession);
  });
}
