import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';
import 'package:sagelift/features/workouts/presentation/screens/progress_screen.dart';

import '../../../../support/workout_draft_fakes.dart';

void main() {
  Future<void> open(WidgetTester tester, List<Workout> sessions) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          workoutRepositoryProvider.overrideWithValue(
            DraftWorkoutRepository(sessions),
          ),
          exerciseRepositoryProvider.overrideWithValue(
            DraftExerciseRepository(),
          ),
        ],
        child: const MaterialApp(home: ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('picker hides unused catalogue entries without deleting history',
      (WidgetTester tester) async {
    final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid);
    final Workout logged =
        base.copyWith(status: WorkoutStatus.completed, sets: <WorkoutSet>[
      base.sets.first.copyWith(
          exerciseId: 'logged-only',
          status: WorkoutSetStatus.completed,
          reps: 8,
          weightKg: 5.0),
    ]);
    await open(tester, <Workout>[logged]);
    DropdownButtonFormField<String> picker =
        tester.widget(find.byType(DropdownButtonFormField<String>));
    // The built dropdown exposes only recorded exercises by default.
    expect(picker.initialValue, 'logged-only');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Press'), findsWidgets);
    expect(find.text('logged-only'), findsWidgets);
  });

  testWidgets('progress handles empty and single-session mobile history', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, <Workout>[]);
    expect(
      find.text(
        'No logged exercises yet. Complete and log a workout to see progress.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'chart selection reveals actual sets and reps without judging heavier loads',
    (WidgetTester tester) async {
      final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid);
      final Workout one = base.copyWith(
        id: 'old',
        status: WorkoutStatus.completed,
        completedAt: DateTime.utc(2020, 1, 1),
        sets: <WorkoutSet>[
          base.sets.first.copyWith(
            status: WorkoutSetStatus.completed,
            weightKg: 70.0,
            reps: 10,
          ),
        ],
      );
      final Workout two = one.copyWith(
        id: 'new',
        completedAt: DateTime.utc(2026, 10, 31),
        sets: <WorkoutSet>[one.sets.first.copyWith(weightKg: 80.0, reps: 6)],
      );
      await open(tester, <Workout>[two, one]);
      expect(find.textContaining('1/1/2020'), findsWidgets);
      final Finder chart = find.byKey(const ValueKey<String>('progress-chart'));
      await tester.tapAt(tester.getTopLeft(chart) + const Offset(54, 54));
      await tester.pumpAndSettle();
      expect(find.textContaining('Set 1: 70 kg × 10 reps'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('single session stays inspectable on mobile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid).copyWith(
      id: 'single',
      status: WorkoutStatus.completed,
      completedAt: DateTime.utc(2026, 10, 31),
      sets: <WorkoutSet>[
        draftTestWorkout().sets.first.copyWith(
              status: WorkoutSetStatus.completed,
              weightKg: 80.0,
              reps: 6,
            ),
      ],
    );
    await open(tester, <Workout>[base]);
    expect(
      find.byKey(const ValueKey<String>('progress-chart')),
      findsOneWidget,
    );
    final Finder row = find.byKey(
      const ValueKey<String>('progress-session-single'),
    );
    await tester.scrollUntilVisible(
      row,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.textContaining('Set 1: 80 kg × 6 reps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('same-date sessions remain separate and open their own sets', (
    WidgetTester tester,
  ) async {
    final Workout base = draftTestWorkout(track: WorkoutTrack.hybrid).copyWith(
      id: 'one',
      status: WorkoutStatus.completed,
      completedAt: DateTime.utc(2026, 10, 31),
      sets: <WorkoutSet>[
        draftTestWorkout().sets.first.copyWith(
              status: WorkoutSetStatus.completed,
              weightKg: 70.0,
              reps: 10,
            ),
      ],
    );
    final Workout other = base.copyWith(
      id: 'two',
      sets: <WorkoutSet>[base.sets.first.copyWith(weightKg: 80.0, reps: 6)],
    );
    await open(tester, <Workout>[base, other]);
    final Finder row = find.byKey(
      const ValueKey<String>('progress-session-two'),
    );
    await tester.scrollUntilVisible(
      row,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.textContaining('Set 1: 80 kg × 6 reps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
