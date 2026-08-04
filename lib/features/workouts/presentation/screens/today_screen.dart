import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/workout.dart';
import '../providers/today_workout_provider.dart';
import '../providers/workout_completion_controller.dart';
import '../widgets/workout_exercise_list.dart';

/// The first-use daily dashboard for workouts and health targets.
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
                'Daily targets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const _DailyTargetsCard(),
              const SizedBox(height: 24),
              Text(
                'Next Workout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              todayWorkout.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) {
                  return const Text('Unable to load the next workout.');
                },
                data: (TodayWorkout? workoutData) {
                  if (workoutData == null) {
                    return const Text('No workout is available yet.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        workoutData.workout.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      WorkoutExerciseList(exercises: workoutData.exercises),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final Workout? startedWorkout = await ref
                                .read(workoutCompletionControllerProvider)
                                .startWorkout(workoutData.workout);
                            if (!context.mounted || startedWorkout == null) {
                              return;
                            }
                            unawaited(
                              context.pushNamed(
                                AppRoute.workoutOverview.name,
                              ),
                            );
                          },
                          child: const Text('Start Workout'),
                        ),
                      ),
                    ],
                  );
                },
              ),
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

class _DailyTargetsCard extends StatelessWidget {
  const _DailyTargetsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Column(
        children: <Widget>[
          ListTile(title: Text('Protein'), trailing: Text('0 / 160 g')),
          ListTile(title: Text('Water'), trailing: Text('0 / 3 L')),
          ListTile(title: Text('Steps'), trailing: Text('0 / 10,000')),
          ListTile(title: Text('Habits'), trailing: Text('No habits yet')),
        ],
      ),
    );
  }
}
