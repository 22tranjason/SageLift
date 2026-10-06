import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/workout.dart';
import '../../domain/services/workout_program.dart';
import '../providers/today_workout_provider.dart';
import '../providers/workout_completion_controller.dart';
import '../widgets/workout_exercise_list.dart';

/// The first-use daily dashboard for workouts.
class TodayScreen extends ConsumerWidget {
  /// Creates the Today screen.
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayWorkout?> todayWorkout = ref.watch(
      todayWorkoutProvider,
    );
    final AsyncValue<Workout?> lastCompletedWorkout = ref.watch(
      lastCompletedWorkoutProvider,
    );
    final DateTime now = DateTime.now();

    final Widget chooseWorkoutButton = Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        key: const ValueKey<String>('choose-workout-button'),
        onPressed: () {
          unawaited(_chooseWorkout(context, ref));
        },
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Choose Workout'),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              unawaited(context.pushNamed(AppRoute.workoutHistory.name));
            },
            child: const Text('History'),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              unawaited(context.pushNamed(AppRoute.settings.name));
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Good Morning Jason',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(_dateLabel(now)),
              const SizedBox(height: 24),
              Text(
                'Next Workout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              todayWorkout.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Unable to load the next workout.'),
                      chooseWorkoutButton,
                    ],
                  );
                },
                data: (TodayWorkout? workoutData) {
                  if (workoutData == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('No workout is available yet.'),
                        chooseWorkoutButton,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        workoutData.workout.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            try {
                              final Workout? startedWorkout = await ref
                                  .read(workoutCompletionControllerProvider)
                                  .startWorkout(workoutData.workout);
                              if (!context.mounted || startedWorkout == null) {
                                return;
                              }
                              unawaited(
                                context.pushNamed(
                                  AppRoute.workoutOverview.name,
                                  pathParameters: <String, String>{
                                    'id': startedWorkout.id,
                                  },
                                ),
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Unable to start workout.'),
                                ),
                              );
                            }
                          },
                          child: Text(
                            workoutData.workout.status ==
                                    WorkoutStatus.inProgress
                                ? 'Resume Workout'
                                : 'Start Workout',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        workoutData.isRecommended
                            ? 'Recommended next'
                            : 'Recommended next: '
                                '${workoutData.recommendedWorkoutName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      chooseWorkoutButton,
                      const SizedBox(height: 8),
                      WorkoutExerciseList(exercises: workoutData.exercises),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              lastCompletedWorkout.when(
                loading: () => const SizedBox.shrink(),
                error: (Object error, StackTrace stackTrace) {
                  return const SizedBox.shrink();
                },
                data: (Workout? workout) {
                  if (workout == null) return const SizedBox.shrink();
                  return _LastWorkoutSection(workout: workout, now: now);
                },
              ),
            ],
          ),
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
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
  }

  Future<void> _chooseWorkout(BuildContext context, WidgetRef ref) async {
    final String? workoutName = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(title: Text('Choose Workout')),
              for (final String name in WorkoutProgram.workoutNames)
                ListTile(
                  title: Text(name),
                  onTap: () => Navigator.of(sheetContext).pop(name),
                ),
            ],
          ),
        );
      },
    );
    if (workoutName == null || !context.mounted) return;
    await _startSelectedWorkout(context, ref, workoutName);
  }

  Future<void> _startSelectedWorkout(
    BuildContext context,
    WidgetRef ref,
    String workoutName, {
    bool replaceInProgress = false,
  }) async {
    try {
      final Workout? startedWorkout = await ref
          .read(workoutCompletionControllerProvider)
          .startSelectedWorkout(
            workoutName,
            replaceInProgress: replaceInProgress,
          );
      if (!context.mounted || startedWorkout == null) {
        return;
      }
      await context.pushNamed(
        AppRoute.workoutOverview.name,
        pathParameters: <String, String>{'id': startedWorkout.id},
      );
    } on WorkoutAlreadyInProgressException catch (error) {
      if (!context.mounted) return;
      final bool confirmed = await _confirmReplaceInProgress(
        context,
        error.workout,
      );
      if (!confirmed || !context.mounted) return;
      await _startSelectedWorkout(
        context,
        ref,
        workoutName,
        replaceInProgress: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to select workout.')),
      );
    }
  }

  Future<bool> _confirmReplaceInProgress(
    BuildContext context,
    Workout activeWorkout,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Replace active workout?'),
            content: Text(
              '${activeWorkout.name} is already in progress. '
              'It will remain planned so you can return to it later.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Choose workout'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _LastWorkoutSection extends StatelessWidget {
  const _LastWorkoutSection({required this.workout, required this.now});

  final Workout workout;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Last Workout', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.check),
              title: Text(workout.name),
              subtitle: Text('Completed ${_relativeDateLabel(workout, now)}'),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeDateLabel(Workout workout, DateTime now) {
    final DateTime completedAt =
        workout.completedAt ?? workout.startedAt ?? workout.scheduledDate;
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime completedDay = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );
    final int daysAgo = today.difference(completedDay).inDays;
    if (daysAgo <= 0) return 'today';
    if (daysAgo == 1) return 'yesterday';
    return '$daysAgo days ago';
  }
}
