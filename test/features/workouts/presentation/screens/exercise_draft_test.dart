import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sagelift/app/router/app_router.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_draft_controller.dart';
import 'package:sagelift/features/workouts/presentation/screens/exercise_screen.dart';

import '../../../../support/workout_draft_fakes.dart';

void main() {
  late DateTime now;
  late ProviderContainer container;
  late DraftWorkoutRepository workouts;
  late GoRouter router;

  Future<void> open(WidgetTester tester, {bool hybrid = false}) async {
    now = DateTime.utc(2026, 9, 21, 9);
    workouts = DraftWorkoutRepository(<Workout>[
      draftTestWorkout(
          track: hybrid ? WorkoutTrack.hybrid : WorkoutTrack.crossFit)
    ]);
    container = ProviderContainer(overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(DraftMemoryStore()),
      workoutRepositoryProvider.overrideWithValue(workouts),
      exerciseRepositoryProvider.overrideWithValue(DraftExerciseRepository()),
      workoutClockProvider.overrideWithValue(() => now),
    ]);
    router = GoRouter(
      initialLocation: '/exercise',
      routes: <RouteBase>[
        GoRoute(
          path: '/exercise',
          builder: (BuildContext context, GoRouterState state) =>
              const ExerciseScreen(workoutId: 'push', exerciseIndex: 0),
        ),
        GoRoute(
          path: '/summary/:id',
          name: AppRoute.workoutSummary.name,
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: Text('Saved summary')),
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      container.dispose();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
      (Widget w) => w is TextField && w.decoration?.labelText == label);

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  testWidgets(
      'unfinished Hybrid hides conditioning and stale timer cannot block Finish',
      (WidgetTester tester) async {
    await open(tester, hybrid: true);
    final WorkoutDraftController controller =
        container.read(workoutDraftControllerProvider('push').notifier);
    controller.startTimer(now);
    controller.updateWeight('set-1', '75');
    controller.updateReps('set-1', '10');
    await tester.pumpAndSettle();
    expect(find.text('Start Conditioning'), findsNothing);
    expect(field('Minutes'), findsNothing);
    await tap(tester, 'Finish Workout');
    expect(find.text('Saved summary'), findsOneWidget);
    expect(workouts.values['push']!.conditioningResult, isNull);
    expect(workouts.values['push']!.sets.single.weightKg, 75);
  });

  testWidgets('Finish Conditioning updates mounted editable time fields',
      (WidgetTester tester) async {
    await open(tester);
    await tap(tester, 'Start Conditioning');
    now = now.add(const Duration(minutes: 2, seconds: 13));
    await tap(tester, 'Finish Conditioning');
    expect(textOf(tester, 'Minutes'), '2');
    expect(textOf(tester, 'Seconds'), '13');
    await tester.enterText(field('Seconds'), '17');
    await tester.pumpAndSettle();
    expect(textOf(tester, 'Seconds'), '17');
    await tap(tester, 'Finish Workout');
    expect(find.text('Saved summary'), findsOneWidget);
    expect(workouts.values['push']!.conditioningResult!.completionTime,
        const Duration(minutes: 2, seconds: 17));
  });

  testWidgets(
      'running timer requires confirmation and captures time at confirmation',
      (WidgetTester tester) async {
    await open(tester);
    await tap(tester, 'Start Conditioning');
    now = now.add(const Duration(seconds: 90));
    await tap(tester, 'Finish Workout');
    expect(find.text('Conditioning is still active'), findsOneWidget);
    expect(workouts.values['push']!.status, WorkoutStatus.inProgress);
    await tap(tester, 'Keep logging');
    expect(
        container
            .read(workoutDraftControllerProvider('push'))
            .requireValue
            .conditioning
            .timer
            .isRunning,
        isTrue);
    await tap(tester, 'Finish Workout');
    now = now.add(const Duration(seconds: 15));
    await tap(tester, 'Finish workout');
    expect(find.text('Saved summary'), findsOneWidget);
    expect(workouts.values['push']!.conditioningResult!.completionTime,
        const Duration(seconds: 105));
  });

  testWidgets(
      'paused timer is saved by Finish Workout without a running dialog',
      (WidgetTester tester) async {
    await open(tester);
    await tap(tester, 'Start Conditioning');
    now = now.add(const Duration(seconds: 65));
    await tap(tester, 'Pause');
    expect(textOf(tester, 'Minutes'), '1');
    expect(textOf(tester, 'Seconds'), '05');
    now = now.add(const Duration(minutes: 5));
    await tap(tester, 'Finish Workout');
    expect(find.text('Conditioning is still active'), findsNothing);
    expect(find.text('Saved summary'), findsOneWidget);
    expect(workouts.values['push']!.conditioningResult!.completionTime,
        const Duration(seconds: 65));
  });

  testWidgets(
      'manual correction is kept by Finish Conditioning until Use timer time',
      (WidgetTester tester) async {
    await open(tester);
    await tap(tester, 'Start Conditioning');
    await tester.enterText(field('Minutes'), '3');
    await tester.pumpAndSettle();
    await tester.enterText(field('Seconds'), '45');
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 4, seconds: 20));
    await tap(tester, 'Finish Conditioning');
    expect(textOf(tester, 'Minutes'), '3');
    expect(textOf(tester, 'Seconds'), '45');
    await tap(tester, 'Use timer time');
    expect(textOf(tester, 'Minutes'), '4');
    expect(textOf(tester, 'Seconds'), '20');
    await tap(tester, 'Finish Workout');
    expect(workouts.values['push']!.conditioningResult!.completionTime,
        const Duration(minutes: 4, seconds: 20));
  });

  testWidgets('navigation away and back restores editable draft fields',
      (WidgetTester tester) async {
    await open(tester);
    await tester.enterText(
        find.byKey(const ValueKey<String>('weight-set-1')), '75');
    await tester.enterText(field('Minutes'), '6');
    await tester.pumpAndSettle();
    router.go('/summary/other');
    await tester.pumpAndSettle();
    router.go('/exercise');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey<String>('weight-set-1')))
            .initialValue,
        '75');
    expect(textOf(tester, 'Minutes'), '6');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
