import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sagelift/app/router/app_router.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_draft_controller.dart';
import 'package:sagelift/features/workouts/presentation/screens/exercise_screen.dart';

import '../../../../support/workout_draft_fakes.dart';

void main() {
  late DateTime now;
  late ProviderContainer container;
  late DraftWorkoutRepository workouts;
  late GoRouter router;

  Future<void> open(WidgetTester tester,
      {bool hybrid = false,
      List<Workout>? sessions,
      double textScale = 1}) async {
    now = DateTime.utc(2026, 9, 21, 9);
    workouts = DraftWorkoutRepository(sessions ??
        <Workout>[
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
      child: MaterialApp.router(
          routerConfig: router,
          builder: (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!)),
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
      'small mobile shows matching fractional previous sets and one guidance message',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid);
    final Workout active = base.copyWith(sets: <WorkoutSet>[
      for (int n = 1; n <= 3; n++)
        base.sets.single.copyWith(
            id: 'set-$n',
            setNumber: n,
            targetReps: 10,
            notes: 'Target 6–10 reps'),
    ]);
    final Workout prior = base.copyWith(
        id: 'prior',
        status: WorkoutStatus.completed,
        completedAt: DateTime.utc(2026, 9, 20),
        sets: <WorkoutSet>[
          base.sets.single.copyWith(
              setNumber: 2,
              status: WorkoutSetStatus.completed,
              weightKg: 82.5,
              reps: 8),
          base.sets.single.copyWith(
              setNumber: 3,
              status: WorkoutSetStatus.completed,
              weightKg: 77.5,
              reps: 9),
        ]);
    await open(tester, sessions: <Workout>[active, prior], textScale: 1.5);
    expect(find.text('Last: —'), findsOneWidget);
    expect(find.text('Last: 82.5 kg × 8 reps'), findsOneWidget);
    expect(find.text('Last: 77.5 kg × 9 reps'), findsOneWidget);
    expect(find.text('Suggested today'), findsOneWidget);
    expect(find.text('Keep the same weight and add one rep where practical.'),
        findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey<String>('weight-set-1')),
                matching: find.byType(TextField)))
            .decoration!
            .hintText,
        isNull);
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey<String>('weight-set-2')),
                matching: find.byType(TextField)))
            .decoration!
            .hintText,
        '82.5');
    final Finder reps = find.byKey(const ValueKey<String>('reps-set-2'));
    await tester.ensureVisible(reps);
    await tester.enterText(reps, '8');
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Finish Workout'));
    await tap(tester, 'Finish Workout');
    expect(find.text('Saved summary'), findsOneWidget);
    expect(workouts.values['push']!.sets[1].reps, 8);
    expect(workouts.values['prior'], prior);
  });

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
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey<String>('weight-set-1')),
                matching: find.byType(TextField)))
            .controller!
            .text,
        '75');
    expect(textOf(tester, 'Minutes'), '6');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
