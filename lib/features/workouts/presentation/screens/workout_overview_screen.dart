import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/today_workout_provider.dart';
import '../widgets/workout_exercise_list.dart';

/// Temporary pre-workout route showing the selected workout and exercises.
class WorkoutOverviewScreen extends ConsumerWidget {
  /// Creates the workout overview screen.
  const WorkoutOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayWorkout?> todayWorkout = ref.watch(
      todayWorkoutProvider,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Overview')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: todayWorkout.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) {
              return const Text('Unable to load workout overview.');
            },
            data: (TodayWorkout? workoutData) {
              if (workoutData == null) {
                return const Text('No workout is available yet.');
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      workoutData.workout.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    WorkoutExerciseList(exercises: workoutData.exercises),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
