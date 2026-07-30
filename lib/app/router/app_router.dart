import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/workouts/presentation/screens/exercise_screen.dart';
import '../../features/workouts/presentation/screens/today_screen.dart';
import '../../features/workouts/presentation/screens/workout_overview_screen.dart';

/// Named routes form the public navigation contract between features.
enum AppRoute {
  /// The default daily dashboard route.
  today,

  /// The temporary route shown after starting a workout.
  workoutOverview,

  /// A focused exercise route identified by its ordered workout index.
  exercise,
}

/// Owns navigation configuration so features never instantiate routers directly.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: AppRoute.today.name,
        builder: (BuildContext context, GoRouterState state) {
          return const TodayScreen();
        },
      ),
      GoRoute(
        path: '/workout-overview',
        name: AppRoute.workoutOverview.name,
        builder: (BuildContext context, GoRouterState state) {
          return const WorkoutOverviewScreen();
        },
      ),
      GoRoute(
        path: '/workout-overview/exercise/:index',
        name: AppRoute.exercise.name,
        builder: (BuildContext context, GoRouterState state) {
          final int? exerciseIndex = int.tryParse(
            state.pathParameters['index'] ?? '',
          );
          return ExerciseScreen(exerciseIndex: exerciseIndex ?? -1);
        },
      ),
    ],
  );
});
