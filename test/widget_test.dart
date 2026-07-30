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

    final Finder startWorkoutButton = find.widgetWithText(
      FilledButton,
      'Start Workout',
    );
    await tester.ensureVisible(startWorkoutButton);
    await tester.pumpAndSettle();
    await tester.tap(startWorkoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Workout Overview'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('Incline Dumbbell Press'), findsOneWidget);
  });
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
