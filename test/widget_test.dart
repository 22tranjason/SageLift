import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/app/sagelift_app.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/workouts/domain/models/exercise.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/repositories/exercise_repository.dart';
import 'package:sagelift/features/workouts/domain/repositories/workout_repository.dart';
import 'package:sagelift/features/workouts/presentation/providers/today_workout_provider.dart';

void main() {
  testWidgets('Today renders the seeded workout and opens its overview', (
    WidgetTester tester,
  ) async {
    const Exercise benchPress = Exercise(
      id: 'seed-exercise-barbell-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    const Exercise inclinePress = Exercise(
      id: 'seed-exercise-incline-dumbbell-press',
      name: 'Incline Dumbbell Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.dumbbells,
    );
    final Workout workout = Workout(
      id: 'seed-workout-push-a',
      name: 'Push A',
      scheduledDate: DateTime.utc(2000),
      status: WorkoutStatus.planned,
      exerciseIds: <String>[benchPress.id, inclinePress.id],
      sets: <WorkoutSet>[
        WorkoutSet(
          id: 'seed-set-push-a-bench-1',
          exerciseId: benchPress.id,
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(<Exercise>[benchPress, inclinePress]),
          ),
          workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepository(<Workout>[workout]),
          ),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good Morning Jason'), findsOneWidget);
    expect(find.text('Push A'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
    expect(find.text('Start Workout'), findsOneWidget);

    final Finder startWorkoutButton = find.text('Start Workout');
    await tester.ensureVisible(startWorkoutButton);
    await tester.pumpAndSettle();
    await tester.tap(startWorkoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Workout Overview'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
  });
  testWidgets('focused exercise flow preserves set values between exercises', (
    WidgetTester tester,
  ) async {
    const Exercise benchPress = Exercise(
      id: 'bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    const Exercise inclinePress = Exercise(
      id: 'incline-press',
      name: 'Incline Dumbbell Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.dumbbells,
    );
    final Workout workout = Workout(
      id: 'push-a',
      name: 'Push A',
      scheduledDate: DateTime.utc(2000),
      status: WorkoutStatus.planned,
      exerciseIds: <String>[benchPress.id, inclinePress.id],
      sets: <WorkoutSet>[
        WorkoutSet(
          id: 'bench-1',
          exerciseId: benchPress.id,
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        WorkoutSet(
          id: 'bench-2',
          exerciseId: benchPress.id,
          setNumber: 2,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        WorkoutSet(
          id: 'incline-1',
          exerciseId: inclinePress.id,
          setNumber: 1,
          targetReps: 12,
          status: WorkoutSetStatus.planned,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(<Exercise>[benchPress, inclinePress]),
          ),
          workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepository(<Workout>[workout]),
          ),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Workout'));
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Set 1'), findsOneWidget);
    expect(find.text('Set 2'), findsOneWidget);
    expect(find.text('No previous workout.'), findsOneWidget);
    expect(find.text('Target reps: 10'), findsNWidgets(2));
    expect(find.text('Target 6–10 reps; rest 2–3 min'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('previous-exercise-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-bench-1')),
      '80',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reps-bench-1')),
      '10',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('completed-bench-1')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Next Exercise'));
    await tester.tap(find.text('Next Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
    expect(find.text('Target reps: 12'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('previous-exercise-button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('next-exercise-button')),
          )
          .onPressed,
      isNull,
    );

    await tester.ensureVisible(find.text('Previous Exercise'));
    await tester.tap(find.text('Previous Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('weight-bench-1')),
          )
          .initialValue,
      '80',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey<String>('reps-bench-1')),
          )
          .initialValue,
      '10',
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey<String>('completed-bench-1')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('finishing a workout persists it and shows accurate summary data',
      (
    WidgetTester tester,
  ) async {
    const Exercise benchPress = Exercise(
      id: 'completion-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    const Exercise row = Exercise(
      id: 'completion-row',
      name: 'Barbell Row',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    final Workout workout = Workout(
      id: 'completion-push-a',
      name: 'Push A',
      scheduledDate: DateTime.utc(2026, 7, 30),
      status: WorkoutStatus.planned,
      exerciseIds: <String>[benchPress.id, row.id],
      sets: <WorkoutSet>[
        WorkoutSet(
          id: 'completion-bench-1',
          exerciseId: benchPress.id,
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
        ),
        WorkoutSet(
          id: 'completion-row-1',
          exerciseId: row.id,
          setNumber: 1,
          targetReps: 8,
          status: WorkoutSetStatus.planned,
        ),
      ],
    );
    final _FakeWorkoutRepository workoutRepository = _FakeWorkoutRepository(
      <Workout>[workout],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(<Exercise>[benchPress, row]),
          ),
          workoutRepositoryProvider.overrideWithValue(workoutRepository),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Workout'));
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Finish Workout'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-completion-bench-1')),
      '80',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reps-completion-bench-1')),
      '10',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('completed-completion-bench-1')),
    );
    await tester.ensureVisible(find.text('Next Exercise'));
    await tester.tap(find.text('Next Exercise'));
    await tester.pumpAndSettle();

    expect(find.text('Finish Workout'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('weight-completion-row-1')),
      '50',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('reps-completion-row-1')),
      '8',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('completed-completion-row-1')),
    );
    await tester.ensureVisible(find.text('Finish Workout'));
    await tester.tap(
      find.byKey(const ValueKey<String>('finish-workout-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout Summary'), findsOneWidget);
    expect(find.text('Exercises completed'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Sets completed'), findsOneWidget);
    expect(find.text('Total reps'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('Total volume'), findsOneWidget);
    expect(find.text('1200 kg'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);

    final Workout? completedWorkout = await workoutRepository.getById(
      workout.id,
    );
    expect(completedWorkout?.status, WorkoutStatus.completed);
    expect(completedWorkout?.startedAt, isNotNull);
    expect(completedWorkout?.completedAt, isNotNull);
    expect(completedWorkout?.sets[0].weightKg, 80);
    expect(completedWorkout?.sets[0].reps, 10);

    await tester.ensureVisible(find.text('Done'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Workout completed'), findsOneWidget);
  });

  testWidgets('History shows an empty state without completed workouts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(const <Exercise>[]),
          ),
          workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepository(const <Workout>[]),
          ),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No completed workouts yet.'), findsOneWidget);
  });

  testWidgets('History orders workouts and displays recorded workout details', (
    WidgetTester tester,
  ) async {
    const Exercise benchPress = Exercise(
      id: 'history-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    final Workout olderWorkout = _completedWorkout(
      id: 'history-older',
      name: 'Older Push',
      exerciseId: benchPress.id,
      startedAt: DateTime.utc(2026, 7, 28, 6),
      completedAt: DateTime.utc(2026, 7, 28, 6, 20),
      weightKg: 70,
      reps: 8,
    );
    final Workout newerWorkout = _completedWorkout(
      id: 'history-newer',
      name: 'Newer Push',
      exerciseId: benchPress.id,
      startedAt: DateTime.utc(2026, 7, 30, 6),
      completedAt: DateTime.utc(2026, 7, 30, 6, 30),
      weightKg: 80,
      reps: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(<Exercise>[benchPress]),
          ),
          workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepository(<Workout>[olderWorkout, newerWorkout]),
          ),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Newer Push'), findsOneWidget);
    expect(find.text('Older Push'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Newer Push')).dy,
      lessThan(tester.getTopLeft(find.text('Older Push')).dy),
    );
    expect(find.text('Duration: 30 min'), findsOneWidget);
    expect(find.text('Sets: 1 • Reps: 10'), findsOneWidget);
    expect(find.text('Volume: 800 kg'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('history-workout-history-newer')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout Details'), findsOneWidget);
    expect(find.text('Newer Push'), findsOneWidget);
    expect(find.text('Start time'), findsOneWidget);
    expect(find.text('Finish time'), findsOneWidget);
    expect(find.text('Exercises completed'), findsOneWidget);
    expect(find.text('Completed exercises'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsNWidgets(2));
    expect(find.text('Completed sets'), findsOneWidget);
    expect(find.text('80 kg × 10 reps'), findsOneWidget);
  });

  testWidgets('Exercise shows its most recent persisted previous performance', (
    WidgetTester tester,
  ) async {
    const Exercise benchPress = Exercise(
      id: 'previous-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      equipment: Equipment.barbell,
    );
    final Workout activeWorkout = Workout(
      id: 'active-workout',
      name: 'Today Push',
      scheduledDate: DateTime.utc(2026, 7, 30),
      status: WorkoutStatus.planned,
      exerciseIds: <String>[benchPress.id],
      sets: <WorkoutSet>[
        WorkoutSet(
          id: 'active-set',
          exerciseId: benchPress.id,
          setNumber: 1,
          targetReps: 10,
          status: WorkoutSetStatus.planned,
        ),
      ],
    );
    final Workout previousWorkout = _completedWorkout(
      id: 'previous-workout',
      name: 'Previous Push',
      exerciseId: benchPress.id,
      startedAt: DateTime.utc(2026, 7, 28, 6),
      completedAt: DateTime.utc(2026, 7, 28, 6, 30),
      weightKg: 75,
      reps: 9,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(_InMemoryKeyValueStore()),
          exerciseRepositoryProvider.overrideWithValue(
            _FakeExerciseRepository(<Exercise>[benchPress]),
          ),
          workoutRepositoryProvider.overrideWithValue(
            _FakeWorkoutRepository(<Workout>[activeWorkout, previousWorkout]),
          ),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Start Workout'));
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    expect(find.text('Last workout:'), findsOneWidget);
    expect(find.text('Set 1: 75 kg × 9 reps'), findsOneWidget);
  });
}

Workout _completedWorkout({
  required String id,
  required String name,
  required String exerciseId,
  required DateTime startedAt,
  required DateTime completedAt,
  required double weightKg,
  required int reps,
}) {
  return Workout(
    id: id,
    name: name,
    scheduledDate: DateTime.utc(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    ),
    status: WorkoutStatus.completed,
    exerciseIds: <String>[exerciseId],
    sets: <WorkoutSet>[
      WorkoutSet(
        id: '$id-set-1',
        exerciseId: exerciseId,
        setNumber: 1,
        weightKg: weightKg,
        reps: reps,
        status: WorkoutSetStatus.completed,
      ),
    ],
    startedAt: startedAt,
    completedAt: completedAt,
  );
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<T?> read<T>(String key) async => _values[key] as T?;

  @override
  Future<void> write<T>(String key, T value) async {
    _values[key] = value;
  }
}

class _FakeExerciseRepository implements ExerciseRepository {
  _FakeExerciseRepository(List<Exercise> exercises)
      : _exercises = Map<String, Exercise>.fromEntries(
          exercises.map(
            (Exercise exercise) => MapEntry<String, Exercise>(
              exercise.id,
              exercise,
            ),
          ),
        );

  final Map<String, Exercise> _exercises;

  @override
  Future<void> delete(String id) async {
    _exercises.remove(id);
  }

  @override
  Future<List<Exercise>> getAll() async => _exercises.values.toList();

  @override
  Future<Exercise?> getById(String id) async => _exercises[id];

  @override
  Future<void> save(Exercise exercise) async {
    _exercises[exercise.id] = exercise;
  }

  @override
  Future<List<Exercise>> searchByName(String query) async {
    return _exercises.values
        .where(
          (Exercise exercise) => exercise.name.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
  }
}

class _FakeWorkoutRepository implements WorkoutRepository {
  _FakeWorkoutRepository(List<Workout> workouts)
      : _workouts = Map<String, Workout>.fromEntries(
          workouts.map(
            (Workout workout) => MapEntry<String, Workout>(
              workout.id,
              workout,
            ),
          ),
        );

  final Map<String, Workout> _workouts;

  @override
  Future<void> delete(String id) async {
    _workouts.remove(id);
  }

  @override
  Future<List<Workout>> getAll() async => _workouts.values.toList();

  @override
  Future<Workout?> getById(String id) async => _workouts[id];

  @override
  Future<List<Workout>> getForDate(DateTime date) async => <Workout>[];

  @override
  Future<void> save(Workout workout) async {
    _workouts[workout.id] = workout;
  }
}
