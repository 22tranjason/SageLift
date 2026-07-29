import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/exercise.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';

void main() {
  group('Exercise', () {
    const Exercise exercise = Exercise(
      id: 'exercise-1',
      name: 'Barbell squat',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
      instructions: 'Brace before descending.',
      notes: 'Use safety pins.',
    );

    test('uses value equality and supports clearing optional fields', () {
      expect(exercise, equals(exercise.copyWith()));
      expect(exercise.hashCode, exercise.copyWith().hashCode);

      final Exercise cleared =
          exercise.copyWith(instructions: null, notes: null);

      expect(cleared.instructions, isNull);
      expect(cleared.notes, isNull);
    });
  });

  group('WorkoutSet', () {
    const WorkoutSet workoutSet = WorkoutSet(
      id: 'set-1',
      exerciseId: 'exercise-1',
      setNumber: 1,
      status: WorkoutSetStatus.completed,
      weightKg: 100,
      reps: 5,
      targetWeightKg: 102.5,
      targetReps: 5,
      rpe: 8,
      notes: 'Controlled tempo.',
    );

    test('uses value equality and supports clearing optional measurements', () {
      expect(workoutSet, equals(workoutSet.copyWith()));
      expect(workoutSet.hashCode, workoutSet.copyWith().hashCode);

      final WorkoutSet cleared = workoutSet.copyWith(rpe: null, notes: null);

      expect(cleared.rpe, isNull);
      expect(cleared.notes, isNull);
    });
  });

  group('Workout', () {
    final WorkoutSet workoutSet = const WorkoutSet(
      id: 'set-1',
      exerciseId: 'exercise-1',
      setNumber: 1,
      status: WorkoutSetStatus.planned,
    );

    Workout createWorkout({List<String>? exerciseIds, List<WorkoutSet>? sets}) {
      return Workout(
        id: 'workout-1',
        name: 'Lower body',
        scheduledDate: DateTime.utc(2026, 7, 29),
        status: WorkoutStatus.planned,
        exerciseIds: exerciseIds ?? <String>['exercise-1', 'exercise-2'],
        sets: sets ?? <WorkoutSet>[workoutSet],
        notes: 'Move deliberately.',
      );
    }

    test('compares ordered collection contents by value', () {
      final Workout first = createWorkout();
      final Workout equal = createWorkout();
      final Workout reordered = createWorkout(
        exerciseIds: <String>['exercise-2', 'exercise-1'],
      );

      expect(first, equals(equal));
      expect(first.hashCode, equal.hashCode);
      expect(first, isNot(equals(reordered)));
    });

    test('defensively copies and exposes unmodifiable collections', () {
      final List<String> exerciseIds = <String>['exercise-1'];
      final List<WorkoutSet> sets = <WorkoutSet>[workoutSet];
      final Workout workout =
          createWorkout(exerciseIds: exerciseIds, sets: sets);

      exerciseIds.add('exercise-2');
      sets.clear();

      expect(workout.exerciseIds, equals(<String>['exercise-1']));
      expect(workout.sets, equals(<WorkoutSet>[workoutSet]));
      expect(
        () => workout.exerciseIds.add('exercise-3'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => workout.sets.clear(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('supports intentionally clearing nullable fields', () {
      final Workout workout = createWorkout().copyWith(
        startedAt: DateTime.utc(2026, 7, 29, 6),
        completedAt: DateTime.utc(2026, 7, 29, 7),
      );

      final Workout cleared = workout.copyWith(
        startedAt: null,
        completedAt: null,
        notes: null,
      );

      expect(cleared.startedAt, isNull);
      expect(cleared.completedAt, isNull);
      expect(cleared.notes, isNull);
    });
  });
}
