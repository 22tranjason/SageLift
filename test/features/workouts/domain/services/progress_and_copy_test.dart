import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/current_set_copy.dart';
import 'package:sagelift/features/workouts/domain/services/exercise_progress_history.dart';

void main() {
  const WorkoutSet first = WorkoutSet(
      id: 'a',
      exerciseId: 'press',
      setNumber: 1,
      status: WorkoutSetStatus.planned);
  final WorkoutSet second = first.copyWith(id: 'b', setNumber: 2);
  test(
      'copy source never crosses exercises, gaps or invalid input; zero is valid',
      () {
    final List<WorkoutSet> sets = <WorkoutSet>[
      first,
      second,
      first.copyWith(id: 'other', exerciseId: 'curl')
    ];
    expect(CurrentSetCopy.source(first, sets, <String, WorkoutSetProgress>{}),
        isNull);
    expect(
        CurrentSetCopy.source(second, sets, <String, WorkoutSetProgress>{
          'other': const WorkoutSetProgress(weight: '100', reps: '9')
        }),
        isNull);
    expect(
        CurrentSetCopy.source(second, sets, <String, WorkoutSetProgress>{
          'a': const WorkoutSetProgress(weight: 'NaN', reps: 'no')
        }),
        isNull);
    final WorkoutSetProgress? valid = CurrentSetCopy.source(
        second, sets, <String, WorkoutSetProgress>{
      'a': const WorkoutSetProgress(weight: '0', reps: '6')
    });
    expect(valid?.weight, '0');
    expect(valid?.reps, '6');
    expect(
        CurrentSetCopy.source(
            second.copyWith(setNumber: 3), sets, <String, WorkoutSetProgress>{
          'a': const WorkoutSetProgress(weight: '80', reps: '6')
        }),
        isNull);
  });
  Workout session(String id, DateTime date, List<WorkoutSet> sets,
          {WorkoutStatus status = WorkoutStatus.completed}) =>
      Workout(
          id: id,
          name: 'Chest',
          scheduledDate: date,
          completedAt: date,
          status: status,
          sets: sets,
          exerciseIds: const <String>['press']);
  test(
      'progress includes earliest local saved history, stable repeat dates, actual reps and marked warmups',
      () {
    final DateTime date = DateTime.utc(2020, 1, 1);
    final WorkoutSet performed = first.copyWith(
        status: WorkoutSetStatus.completed, weightKg: 70.0, reps: 10);
    final Workout early = session('earliest', date, <WorkoutSet>[performed]);
    final Workout heavy =
        session('heavy', date.add(const Duration(days: 365)), <WorkoutSet>[
      performed.copyWith(weightKg: 80.0, reps: 6),
      performed.copyWith(
          id: 'warm',
          setNumber: 2,
          weightKg: 100.0,
          notes: 'Warm-up: preparation'),
      performed.copyWith(
          id: 'skip', status: WorkoutSetStatus.skipped, weightKg: 200.0),
    ]);
    final Workout sameDate = session('z', heavy.completedAt!,
        <WorkoutSet>[performed.copyWith(weightKg: 75.0, reps: 8)]);
    final List<ExerciseProgressPoint> points =
        ExerciseProgressHistory.points(<Workout>[
      sameDate,
      heavy,
      early,
      session('active', date, <WorkoutSet>[performed],
          status: WorkoutStatus.inProgress)
    ], 'press');
    expect(points.map((ExerciseProgressPoint p) => p.workout.id),
        <String>['earliest', 'heavy', 'z']);
    expect(points[0].weightKg, 70);
    expect(points[1].weightKg, 80);
    expect(points[1].sets.first.reps, 6);
    expect(points[1].sets, hasLength(2));
    expect(heavy.sets, hasLength(3));
    expect(
        ExerciseProgressHistory.points(<Workout>[early], 'unknown'), isEmpty);
  });
  test('no load, single point, zero and unmarked warmups remain factual', () {
    final WorkoutSet repsOnly =
        first.copyWith(status: WorkoutSetStatus.completed, reps: 8);
    final Workout w =
        session('reps', DateTime.utc(2026), <WorkoutSet>[repsOnly]);
    expect(
        ExerciseProgressHistory.points(<Workout>[w], 'press').single.weightKg,
        isNull);
    final Workout zero =
        w.copyWith(sets: <WorkoutSet>[repsOnly.copyWith(weightKg: 0.0)]);
    expect(
        ExerciseProgressHistory.points(<Workout>[zero], 'press')
            .single
            .weightKg,
        0);
    expect(ExerciseProgressHistory.isWarmUp(repsOnly), isFalse);
  });
}
