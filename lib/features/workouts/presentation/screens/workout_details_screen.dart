import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/workout.dart';
import '../providers/workout_completion_controller.dart';
import '../providers/workout_history_provider.dart';

/// Shows the persisted details and recorded sets of a completed workout.
class WorkoutDetailsScreen extends ConsumerWidget {
  /// Creates a details screen for the completed workout identified by [workoutId].
  const WorkoutDetailsScreen({required this.workoutId, super.key});

  /// Stable identifier of the completed workout to display.
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CompletedWorkoutDetails?> details = ref.watch(
      completedWorkoutDetailsProvider(workoutId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Details')),
      body: SafeArea(
        child: details.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) {
            return const Center(child: Text('Unable to load workout details.'));
          },
          data: (CompletedWorkoutDetails? value) {
            if (value == null) {
              return const Center(
                  child: Text('Workout details are not available.'));
            }
            final WorkoutSummary summary = value.summary;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summary.workout.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _DetailRow(
                    label: 'Date',
                    value: _dateLabel(summary.workout.completedAt),
                  ),
                  _DetailRow(
                    label: 'Start time',
                    value: _timeLabel(summary.workout.startedAt),
                  ),
                  _DetailRow(
                    label: 'Finish time',
                    value: _timeLabel(summary.workout.completedAt),
                  ),
                  _DetailRow(
                    label: 'Duration',
                    value: '${summary.duration.inMinutes} min',
                  ),
                  _DetailRow(
                    label: 'Exercises completed',
                    value: '${summary.exercisesCompleted}',
                  ),
                  _DetailRow(
                    label: 'Sets completed',
                    value: '${summary.setsCompleted}',
                  ),
                  _DetailRow(
                    label: 'Total reps',
                    value: '${summary.totalReps}',
                  ),
                  _DetailRow(
                    label: 'Total volume',
                    value: '${summary.totalVolumeKg.toStringAsFixed(0)} kg',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Completed exercises',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final String name
                            in summary.completedExerciseNames)
                          ListTile(title: Text(name)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Completed sets',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final CompletedSetDetail setDetail
                            in value.completedSets)
                          ListTile(
                            title: Text(
                              '${setDetail.exerciseName} — '
                              'Set ${setDetail.set.setNumber}',
                            ),
                            subtitle: Text(_setLabel(setDetail)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('delete-workout-button'),
                      onPressed: () => _deleteWorkout(
                        context,
                        ref,
                        summary.workout,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete Workout'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Not recorded';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return 'Not recorded';
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _setLabel(CompletedSetDetail setDetail) {
    final String weight = setDetail.set.weightKg?.toStringAsFixed(0) ?? '—';
    final String reps = setDetail.set.reps?.toString() ?? '—';
    return '$weight kg × $reps reps';
  }

  Future<void> _deleteWorkout(
    BuildContext context,
    WidgetRef ref,
    Workout workout,
  ) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Delete workout?'),
            content: Text(
              'Delete ${workout.name} from ${_dateLabel(workout.completedAt)}? '
              'This only removes this workout record.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(workoutCompletionControllerProvider)
          .deleteCompletedWorkout(workout.id);
      if (!context.mounted) return;
      context.goNamed(AppRoute.workoutHistory.name);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete workout.')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[Text(label), Text(value)],
      ),
    );
  }
}
