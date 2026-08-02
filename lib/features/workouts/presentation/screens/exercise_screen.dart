import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../providers/today_workout_provider.dart';
import '../providers/workout_completion_controller.dart';
import '../providers/workout_history_provider.dart';
import '../providers/workout_set_progress_controller.dart';

/// Focused set-entry screen for one exercise in the selected workout.
class ExerciseScreen extends ConsumerWidget {
  /// Creates an exercise screen for [exerciseIndex] in workout order.
  const ExerciseScreen({required this.exerciseIndex, super.key});

  /// Zero-based position of the focused exercise in the workout.
  final int exerciseIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayWorkout?> todayWorkout = ref.watch(
      todayWorkoutProvider,
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: todayWorkout.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) {
            return const Center(child: Text('Unable to load exercise.'));
          },
          data: (TodayWorkout? workoutData) {
            if (workoutData == null ||
                exerciseIndex < 0 ||
                exerciseIndex >= workoutData.exercises.length) {
              return const Center(child: Text('Exercise is not available.'));
            }
            final Exercise exercise = workoutData.exercises[exerciseIndex];
            final List<WorkoutSet> sets = workoutData.workout.sets
                .where((WorkoutSet set) => set.exerciseId == exercise.id)
                .toList(growable: false);
            return _ExerciseContent(
              exercise: exercise,
              sets: sets,
              exerciseIndex: exerciseIndex,
              exerciseCount: workoutData.exercises.length,
              workoutId: workoutData.workout.id,
              workoutIsCompleted:
                  workoutData.workout.status == WorkoutStatus.completed,
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseContent extends ConsumerWidget {
  const _ExerciseContent({
    required this.exercise,
    required this.sets,
    required this.exerciseIndex,
    required this.exerciseCount,
    required this.workoutId,
    required this.workoutIsCompleted,
  });

  final Exercise exercise;
  final List<WorkoutSet> sets;
  final int exerciseIndex;
  final int exerciseCount;
  final String workoutId;
  final bool workoutIsCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, WorkoutSetProgress> progress = ref.watch(
      workoutSetProgressControllerProvider,
    );
    final WorkoutSetProgressController controller = ref.read(
      workoutSetProgressControllerProvider.notifier,
    );
    final AsyncValue<PreviousExercisePerformance?> previousPerformance =
        ref.watch(previousExercisePerformanceProvider(exercise.id));
    final String? repRange = sets.isEmpty ? null : _repRangeFor(sets.first);
    final String? restGuidance =
        sets.isEmpty ? null : _restGuidanceFor(sets.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          if (repRange != null || restGuidance != null)
            Text(
              <String>[
                if (repRange != null) '$repRange reps',
                if (restGuidance != null) restGuidance,
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          previousPerformance.when(
            loading: () => const SizedBox.shrink(),
            error: (Object error, StackTrace stackTrace) {
              return const Text('No previous workout.');
            },
            data: (PreviousExercisePerformance? performance) {
              if (performance == null) {
                return const Text('No previous workout.');
              }
              return _PreviousPerformanceCard(performance: performance);
            },
          ),
          const SizedBox(height: 8),
          for (final WorkoutSet set in sets) ...<Widget>[
            _SetEntryCard(
              set: set,
              repRange: _repRangeFor(set),
              progress: progress[set.id] ?? const WorkoutSetProgress(),
              onWeightChanged: (String weight) {
                controller.updateWeight(set.id, weight);
              },
              onRepsChanged: (String reps) {
                controller.updateReps(set.id, reps);
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('previous-exercise-button'),
                  onPressed: exerciseIndex == 0
                      ? null
                      : () => _replaceExercise(context, exerciseIndex - 1),
                  child: const Text('Previous Exercise'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('next-exercise-button'),
                  onPressed: exerciseIndex == exerciseCount - 1
                      ? null
                      : () => _replaceExercise(context, exerciseIndex + 1),
                  child: const Text('Next Exercise'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (exerciseIndex == exerciseCount - 1 &&
              !workoutIsCompleted) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('finish-workout-button'),
                onPressed: () async {
                  final Workout? completedWorkout = await ref
                      .read(workoutCompletionControllerProvider)
                      .finishWorkout(workoutId);
                  if (!context.mounted || completedWorkout == null) return;
                  context.goNamed(
                    AppRoute.workoutSummary.name,
                    pathParameters: <String, String>{'id': workoutId},
                  );
                },
                child: const Text('Finish Workout'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: context.pop,
              child: const Text('Back to Workout Overview'),
            ),
          ),
        ],
      ),
    );
  }

  void _replaceExercise(BuildContext context, int index) {
    context.pushReplacementNamed(
      AppRoute.exercise.name,
      pathParameters: <String, String>{'index': '$index'},
    );
  }
}

String? _repRangeFor(WorkoutSet set) {
  final RegExpMatch? match = RegExp(
    r'(\d+\s*[–-]\s*\d+)\s*reps',
    caseSensitive: false,
  ).firstMatch(set.notes ?? '');
  if (match != null) {
    return match.group(1)?.replaceAll('-', '–').replaceAll(' ', '');
  }
  return set.targetReps?.toString();
}

String? _restGuidanceFor(WorkoutSet set) {
  final RegExpMatch? match = RegExp(
    r'rest\s+[^;]+',
    caseSensitive: false,
  ).firstMatch(set.notes ?? '');
  return match?.group(0);
}

class _PreviousPerformanceCard extends StatelessWidget {
  const _PreviousPerformanceCard({required this.performance});

  final PreviousExercisePerformance performance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Last time'),
            const SizedBox(height: 4),
            for (final WorkoutSet set in performance.sets) Text(_setLabel(set)),
            const SizedBox(height: 4),
            const Text('Let\'s beat that 💪'),
          ],
        ),
      ),
    );
  }

  String _setLabel(WorkoutSet set) {
    final String weight = set.weightKg?.toStringAsFixed(0) ?? '—';
    final String reps = set.reps?.toString() ?? '—';
    return '$weight kg × $reps reps';
  }
}

class _SetEntryCard extends StatelessWidget {
  const _SetEntryCard({
    required this.set,
    required this.repRange,
    required this.progress,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  final WorkoutSet set;
  final String? repRange;
  final WorkoutSetProgress progress;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Set ${set.setNumber}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('weight-${set.id}'),
                    initialValue: progress.weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      isDense: true,
                    ),
                    onChanged: onWeightChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('reps-${set.id}'),
                    initialValue: progress.reps,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      hintText: repRange,
                      isDense: true,
                    ),
                    onChanged: onRepsChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
