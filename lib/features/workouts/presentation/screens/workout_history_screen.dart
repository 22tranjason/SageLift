import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/conditioning.dart';
import '../../domain/models/workout.dart';
import '../providers/workout_history_provider.dart';

/// Lists persisted completed workouts with their calculated statistics.
class WorkoutHistoryScreen extends ConsumerWidget {
  /// Creates the completed workout history screen.
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkoutHistoryItem>> history = ref.watch(
      completedWorkoutHistoryProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) {
            return const Center(child: Text('Unable to load workout history.'));
          },
          data: (List<WorkoutHistoryItem> items) {
            if (items.isEmpty) {
              return const Center(child: Text('No completed workouts yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: 12);
              },
              itemBuilder: (BuildContext context, int index) {
                final WorkoutHistoryItem item = items[index];
                return Card(
                  child: ListTile(
                    key: ValueKey<String>('history-workout-${item.workout.id}'),
                    title: Text(item.workout.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 4),
                        Text(
                          item.workout.track == WorkoutTrack.crossFit
                              ? 'CrossFit'
                              : 'Strength — PPL',
                        ),
                        Text(_dateLabel(item.workout.completedAt)),
                        Text(
                            'Duration: ${_durationLabel(item.summary.duration)}'),
                        Text(
                          'Sets: ${item.summary.setsCompleted} • '
                          'Reps: ${item.summary.totalReps}',
                        ),
                        Text(
                          'Volume: '
                          '${item.summary.totalVolumeKg.toStringAsFixed(0)} kg',
                        ),
                        if (item.workout.conditioningResult != null)
                          Text(_conditioningLabel(item.workout)),
                      ],
                    ),
                    onTap: () {
                      unawaited(
                        context.pushNamed(
                          AppRoute.workoutDetails.name,
                          pathParameters: <String, String>{
                            'id': item.workout.id,
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return 'Completion date unavailable';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _durationLabel(Duration duration) {
    return '${duration.inMinutes} min';
  }

  String _conditioningLabel(Workout workout) {
    final ConditioningResult result = workout.conditioningResult!;
    final String rounds = '${result.roundsCompleted} rounds'
        '${result.additionalReps > 0 ? ' + ${result.additionalReps} reps' : ''}';
    final String time = result.completionTime == null
        ? ''
        : ' • ${result.completionTime!.inMinutes}:'
            '${(result.completionTime!.inSeconds % 60).toString().padLeft(2, '0')}';
    final String scaling = result.scaling == null ? '' : ' • ${result.scaling}';
    return '$rounds$time$scaling';
  }
}
