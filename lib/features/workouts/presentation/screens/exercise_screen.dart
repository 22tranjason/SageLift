import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/workout_set.dart';
import '../providers/today_workout_provider.dart';
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
      appBar: AppBar(title: const Text('Exercise')),
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
  });

  final Exercise exercise;
  final List<WorkoutSet> sets;
  final int exerciseIndex;
  final int exerciseCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, WorkoutSetProgress> progress = ref.watch(
      workoutSetProgressControllerProvider,
    );
    final WorkoutSetProgressController controller = ref.read(
      workoutSetProgressControllerProvider.notifier,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (sets.isNotEmpty && sets.first.notes != null)
            Text(sets.first.notes!),
          const SizedBox(height: 16),
          for (final WorkoutSet set in sets) ...<Widget>[
            _SetEntryCard(
              set: set,
              progress: progress[set.id] ?? const WorkoutSetProgress(),
              onWeightChanged: (String weight) {
                controller.updateWeight(set.id, weight);
              },
              onCompletedRepsChanged: (String completedReps) {
                controller.updateCompletedReps(set.id, completedReps);
              },
              onCompletionChanged: (bool isCompleted) {
                controller.updateCompletion(set.id, isCompleted);
              },
            ),
            const SizedBox(height: 12),
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

class _SetEntryCard extends StatelessWidget {
  const _SetEntryCard({
    required this.set,
    required this.progress,
    required this.onWeightChanged,
    required this.onCompletedRepsChanged,
    required this.onCompletionChanged,
  });

  final WorkoutSet set;
  final WorkoutSetProgress progress;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onCompletedRepsChanged;
  final ValueChanged<bool> onCompletionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Set ${set.setNumber}'),
            Text('Target reps: ${set.targetReps ?? '—'}'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('weight-${set.id}'),
                    initialValue: progress.weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Weight'),
                    onChanged: onWeightChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('reps-${set.id}'),
                    initialValue: progress.completedReps,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Completed reps',
                    ),
                    onChanged: onCompletedRepsChanged,
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              key: ValueKey<String>('completed-${set.id}'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Completed'),
              value: progress.isCompleted,
              onChanged: (bool? value) {
                onCompletionChanged(value ?? false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
