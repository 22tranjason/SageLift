import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../providers/today_workout_provider.dart';
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
    final DateTime now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
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
                'Today\'s workout',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              todayWorkout.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object error, StackTrace stackTrace) {
                  return const Text('Unable to load today\'s workout.');
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
                          onPressed: () {
                            context.pushNamed(AppRoute.workoutOverview.name);
                          },
                          child: const Text('Start Workout'),
                        ),
                      ),
                    ],
                  );
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
