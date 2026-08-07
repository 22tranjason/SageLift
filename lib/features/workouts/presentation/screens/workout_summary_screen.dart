import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/conditioning.dart';
import '../../domain/services/exercise_progression_service.dart';
import '../providers/workout_completion_controller.dart';
import '../providers/workout_progression_provider.dart';

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
    final AsyncValue<List<WorkoutExerciseProgression>> progressions = ref.watch(
      workoutProgressionSummaryProvider(workoutId),
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
                    value: _dateLabel(
                      value.workout.startedAt ??
                          value.workout.completedAt ??
                          value.workout.scheduledDate,
                    ),
                  ),
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
                  if (value.workout.conditioningResult != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Conditioning',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    _ConditioningResultCard(
                      result: value.workout.conditioningResult!,
                      prescribedRounds:
                          value.workout.conditioningPlan?.prescribedRounds,
                    ),
                  ],
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
                  Text(
                    'Progress since last time',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  progressions.when(
                    loading: () => const SizedBox.shrink(),
                    error: (Object error, StackTrace stackTrace) {
                      return const SizedBox.shrink();
                    },
                    data: (List<WorkoutExerciseProgression> values) {
                      if (values.isEmpty) return const SizedBox.shrink();
                      return Card(
                        child: Column(
                          children: <Widget>[
                            for (final WorkoutExerciseProgression progression
                                in values)
                              ListTile(
                                title: Text(progression.exerciseName),
                                subtitle: Text(progression.nextStep),
                                trailing: Text(
                                  _progressionLabel(progression.status),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
    const List<String> weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final DateTime localDate = date.toLocal();
    return '${weekdays[localDate.weekday - 1]}, '
        '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return 'Not recorded';
    final DateTime localTime = time.toLocal();
    final String hour =
        (localTime.hour % 12 == 0 ? 12 : localTime.hour % 12).toString();
    final String minute = localTime.minute.toString().padLeft(2, '0');
    final String suffix = localTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _durationLabel(Duration duration) {
    return '${duration.inMinutes} min';
  }

  String _progressionLabel(ExerciseProgressionStatus status) {
    switch (status) {
      case ExerciseProgressionStatus.firstSession:
        return 'First session';
      case ExerciseProgressionStatus.improvedByWeight:
        return 'Improved by weight';
      case ExerciseProgressionStatus.improvedByReps:
        return 'Improved by reps';
      case ExerciseProgressionStatus.matched:
        return 'Matched';
      case ExerciseProgressionStatus.belowPrevious:
        return 'Below previous';
    }
  }
}

class _ConditioningResultCard extends StatelessWidget {
  const _ConditioningResultCard({
    required this.result,
    required this.prescribedRounds,
  });

  final ConditioningResult result;
  final int? prescribedRounds;

  @override
  Widget build(BuildContext context) {
    final String rounds = '${result.roundsCompleted} rounds'
        '${result.additionalReps > 0 ? ' + ${result.additionalReps} reps' : ''}';
    final Duration? time = result.completionTime;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (prescribedRounds != null)
              Text('Target: $prescribedRounds rounds'),
            Text('Result: $rounds'),
            if (time != null)
              Text(
                'Time: ${time.inMinutes}:'
                '${(time.inSeconds % 60).toString().padLeft(2, '0')}',
              ),
            if (result.weightKg != null)
              Text('Weight: ${result.weightKg!.toStringAsFixed(0)} kg'),
            if (result.scaling != null) Text('Scaling: ${result.scaling}'),
            Text(result.isCompleted ? 'Completed' : 'Not completed'),
          ],
        ),
      ),
    );
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
