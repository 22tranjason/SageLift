import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../providers/workout_completion_controller.dart';

/// Presents the persisted result of a completed workout.
class WorkoutSummaryScreen extends ConsumerWidget {
  /// Creates a summary screen for [workoutId].
  const WorkoutSummaryScreen({required this.workoutId, super.key});

  /// Stable identifier of the completed workout to summarise.
  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkoutSummary?> summary = ref.watch(
      workoutSummaryProvider(workoutId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Summary')),
      body: SafeArea(
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) {
            return const Center(child: Text('Unable to load workout summary.'));
          },
          data: (WorkoutSummary? value) {
            if (value == null) {
              return const Center(
                  child: Text('Workout summary is not available.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    value.workout.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(
                      label: 'Date',
                      value: _dateLabel(value.workout.scheduledDate)),
                  _SummaryRow(
                      label: 'Start time',
                      value: _timeLabel(value.workout.startedAt)),
                  _SummaryRow(
                      label: 'Finish time',
                      value: _timeLabel(value.workout.completedAt)),
                  _SummaryRow(
                      label: 'Duration', value: _durationLabel(value.duration)),
                  _SummaryRow(
                    label: 'Exercises completed',
                    value: '${value.exercisesCompleted}',
                  ),
                  _SummaryRow(
                      label: 'Sets completed', value: '${value.setsCompleted}'),
                  _SummaryRow(label: 'Total reps', value: '${value.totalReps}'),
                  _SummaryRow(
                    label: 'Total volume',
                    value: '${value.totalVolumeKg.toStringAsFixed(0)} kg',
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
                        for (final String exerciseName
                            in value.completedExerciseNames)
                          ListTile(title: Text(exerciseName)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.goNamed(AppRoute.today.name),
                      child: const Text('Done'),
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

  String _dateLabel(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return 'Not recorded';
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _durationLabel(Duration duration) {
    return '${duration.inMinutes} min';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
