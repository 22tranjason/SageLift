import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';

/// Adds the initial placeholder workout catalogue to an empty local database.
class WorkoutSeedService {
  /// Creates a seed service over the workout and exercise repositories.
  const WorkoutSeedService({
    required ExerciseRepository exerciseRepository,
    required WorkoutRepository workoutRepository,
  })  : _exerciseRepository = exerciseRepository,
        _workoutRepository = workoutRepository;

  final ExerciseRepository _exerciseRepository;
  final WorkoutRepository _workoutRepository;

  /// Inserts placeholder exercises and the six default workouts when empty.
  ///
  /// Existing data is never changed, so repeated startup calls are safe.
  Future<void> seedIfEmpty() async {
    final List<Exercise> existingExercises = await _exerciseRepository.getAll();
    final List<Workout> existingWorkouts = await _workoutRepository.getAll();
    if (existingExercises.isNotEmpty || existingWorkouts.isNotEmpty) return;

    for (final Exercise exercise in _placeholderExercises) {
      await _exerciseRepository.save(exercise);
    }
    for (final Workout workout in _defaultWorkouts) {
      await _workoutRepository.save(workout);
    }
  }

  static const List<Exercise> _placeholderExercises = <Exercise>[
    Exercise(
      id: 'seed-exercise-barbell-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.chest,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-overhead-press',
      name: 'Overhead Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-triceps-pressdown',
      name: 'Triceps Pressdown',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-lat-pulldown',
      name: 'Lat Pulldown',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-barbell-row',
      name: 'Barbell Row',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-biceps-curl',
      name: 'Biceps Curl',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-back-squat',
      name: 'Back Squat',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-romanian-deadlift',
      name: 'Romanian Deadlift',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-leg-press',
      name: 'Leg Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.machine,
    ),
  ];

  static final List<Workout> _defaultWorkouts = <Workout>[
    _workout(
      id: 'seed-workout-push-a',
      name: 'Push A',
      exerciseIds: <String>[
        'seed-exercise-barbell-bench-press',
        'seed-exercise-overhead-press',
        'seed-exercise-triceps-pressdown',
      ],
    ),
    _workout(
      id: 'seed-workout-pull-a',
      name: 'Pull A',
      exerciseIds: <String>[
        'seed-exercise-lat-pulldown',
        'seed-exercise-barbell-row',
        'seed-exercise-biceps-curl',
      ],
    ),
    _workout(
      id: 'seed-workout-legs-a',
      name: 'Legs A',
      exerciseIds: <String>[
        'seed-exercise-back-squat',
        'seed-exercise-romanian-deadlift',
        'seed-exercise-leg-press',
      ],
    ),
    _workout(
      id: 'seed-workout-push-b',
      name: 'Push B',
      exerciseIds: <String>[
        'seed-exercise-overhead-press',
        'seed-exercise-barbell-bench-press',
        'seed-exercise-triceps-pressdown',
      ],
    ),
    _workout(
      id: 'seed-workout-pull-b',
      name: 'Pull B',
      exerciseIds: <String>[
        'seed-exercise-barbell-row',
        'seed-exercise-lat-pulldown',
        'seed-exercise-biceps-curl',
      ],
    ),
    _workout(
      id: 'seed-workout-legs-b',
      name: 'Legs B',
      exerciseIds: <String>[
        'seed-exercise-leg-press',
        'seed-exercise-back-squat',
        'seed-exercise-romanian-deadlift',
      ],
    ),
  ];

  static Workout _workout({
    required String id,
    required String name,
    required List<String> exerciseIds,
  }) {
    return Workout(
      id: id,
      name: name,
      scheduledDate: DateTime.utc(2000),
      status: WorkoutStatus.planned,
      exerciseIds: exerciseIds,
    );
  }
}
