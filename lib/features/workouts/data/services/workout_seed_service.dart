import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_program.dart';

/// Adds Jason's initial push, pull, legs programme to an empty local database.
class WorkoutSeedService {
  /// Creates a seed service over the workout and exercise repositories.
  const WorkoutSeedService({
    required ExerciseRepository exerciseRepository,
    required WorkoutRepository workoutRepository,
  })  : _exerciseRepository = exerciseRepository,
        _workoutRepository = workoutRepository;

  final ExerciseRepository _exerciseRepository;
  final WorkoutRepository _workoutRepository;

  /// Inserts the programme when the workout database is completely empty.
  ///
  /// Repeated calls never reseed or delete history. They safely upgrade planned
  /// Push A sessions and reconcile one missing recommended planned session for
  /// users whose older app version left only completed program records.
  Future<void> seedIfEmpty() async {
    final List<Exercise> existingExercises = await _exerciseRepository.getAll();
    final List<Workout> existingWorkouts = await _workoutRepository.getAll();
    if (existingExercises.isNotEmpty || existingWorkouts.isNotEmpty) {
      await _upgradePlannedPushA(
        existingExercises: existingExercises,
        existingWorkouts: existingWorkouts,
      );
      await _reconcileRecommendedPlannedWorkout();
      return;
    }

    for (final Exercise exercise in _exercises) {
      await _exerciseRepository.save(exercise);
    }
    for (final Workout workout in _workouts) {
      await _workoutRepository.save(workout);
    }
  }

  /// Compatibility reconciliation for existing local databases.
  ///
  /// It preserves completed history and existing planned sessions. A new session
  /// is created only when the recommended program name has no planned record.
  Future<void> _reconcileRecommendedPlannedWorkout() async {
    final List<Workout> workouts = await _workoutRepository.getAll();
    if (workouts.any(
      (Workout workout) => workout.status == WorkoutStatus.inProgress,
    )) {
      return;
    }
    final String recommendedName =
        WorkoutProgram.recommendedNextWorkoutName(workouts);
    if (workouts.any(
      (Workout workout) =>
          workout.status == WorkoutStatus.planned &&
          workout.name == recommendedName,
    )) {
      return;
    }
    final List<Workout> templates = workouts
        .where((Workout workout) => workout.name == recommendedName)
        .toList(growable: false)
      ..sort((Workout first, Workout second) => first.id.compareTo(second.id));
    if (templates.isEmpty) return;
    final DateTime now = DateTime.now();
    final String sessionId = 'program-migration-'
        '${recommendedName.toLowerCase().replaceAll(' ', '-')}-'
        '${now.microsecondsSinceEpoch}-${workouts.length}';
    await _workoutRepository.save(
      WorkoutProgram.createPlannedSession(
        template: templates.first,
        id: sessionId,
        scheduledDate: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  Future<void> _upgradePlannedPushA({
    required List<Exercise> existingExercises,
    required List<Workout> existingWorkouts,
  }) async {
    final Exercise overheadRopeExtension = _exercises.singleWhere(
      (Exercise exercise) => exercise.id == _pushAExtension.exerciseId,
    );
    if (!existingExercises.any(
      (Exercise exercise) => exercise.id == _pushAExtension.exerciseId,
    )) {
      await _exerciseRepository.save(overheadRopeExtension);
    }

    for (final Workout workout in existingWorkouts) {
      if (workout.name != 'Push A' ||
          workout.status != WorkoutStatus.planned ||
          workout.exerciseIds.contains(_pushAExtension.exerciseId)) {
        continue;
      }
      final List<WorkoutSet> extensionSets = <WorkoutSet>[
        for (int setNumber = 1;
            setNumber <= _pushAExtension.setCount;
            setNumber++)
          WorkoutSet(
            id: 'seed-set-${workout.id}-${_pushAExtension.exerciseId}-$setNumber',
            exerciseId: _pushAExtension.exerciseId,
            setNumber: setNumber,
            targetReps: _pushAExtension.targetReps,
            status: WorkoutSetStatus.planned,
            notes: _pushAExtension.notes,
          ),
      ];
      await _workoutRepository.save(
        workout.copyWith(
          exerciseIds: <String>[
            ...workout.exerciseIds,
            _pushAExtension.exerciseId,
          ],
          sets: <WorkoutSet>[...workout.sets, ...extensionSets],
        ),
      );
    }
  }

  static const List<Exercise> _exercises = <Exercise>[
    Exercise(
      id: 'seed-exercise-barbell-bench-press',
      name: 'Barbell Bench Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.chest,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-incline-dumbbell-press',
      name: 'Incline Dumbbell Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.chest,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-seated-dumbbell-shoulder-press',
      name: 'Seated Dumbbell Shoulder Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-dumbbell-lateral-raise',
      name: 'Dumbbell Lateral Raise',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-cable-triceps-pushdown',
      name: 'Cable Triceps Pushdown',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-overhead-rope-triceps-extension',
      name: 'Overhead Rope Triceps Extension',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-barbell-bent-over-row',
      name: 'Barbell Bent-Over Row',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-one-arm-dumbbell-row',
      name: 'One-Arm Dumbbell Row',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-cable-lat-pulldown',
      name: 'Cable Lat Pulldown',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-dumbbell-rear-delt-fly',
      name: 'Dumbbell Rear-Delt Fly',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-dumbbell-hammer-curl',
      name: 'Dumbbell Hammer Curl',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-barbell-back-squat',
      name: 'Barbell Back Squat',
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
      id: 'seed-exercise-dumbbell-reverse-lunge',
      name: 'Dumbbell Reverse Lunge',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-standing-dumbbell-calf-raise',
      name: 'Standing Dumbbell Calf Raise',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-plank',
      name: 'Plank',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.core,
      equipment: Equipment.bodyweight,
    ),
    Exercise(
      id: 'seed-exercise-incline-barbell-bench-press',
      name: 'Incline Barbell Bench Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.chest,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-flat-dumbbell-bench-press',
      name: 'Flat Dumbbell Bench Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.chest,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-standing-barbell-overhead-press',
      name: 'Standing Barbell Overhead Press',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-overhead-dumbbell-triceps-extension',
      name: 'Overhead Dumbbell Triceps Extension',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-conventional-deadlift',
      name: 'Conventional Deadlift',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-chest-supported-dumbbell-row',
      name: 'Chest-Supported Dumbbell Row on Incline Bench',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-cable-seated-row',
      name: 'Cable Seated Row',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.back,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-cable-face-pull',
      name: 'Cable Face Pull',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.shoulders,
      equipment: Equipment.cableMachine,
    ),
    Exercise(
      id: 'seed-exercise-alternating-dumbbell-curl',
      name: 'Alternating Dumbbell Curl',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.arms,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-barbell-front-squat',
      name: 'Barbell Front Squat',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-barbell-hip-thrust',
      name: 'Barbell Hip Thrust',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.glutes,
      equipment: Equipment.barbell,
    ),
    Exercise(
      id: 'seed-exercise-dumbbell-bulgarian-split-squat',
      name: 'Dumbbell Bulgarian Split Squat',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.legs,
      equipment: Equipment.dumbbells,
    ),
    Exercise(
      id: 'seed-exercise-lying-leg-raise',
      name: 'Lying Leg Raise',
      category: ExerciseCategory.strength,
      primaryMuscleGroup: MuscleGroup.core,
      equipment: Equipment.bodyweight,
    ),
  ];

  static final List<Workout> _workouts = <Workout>[
    _workout(
      id: 'seed-workout-push-a',
      name: 'Push A',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-barbell-bench-press',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-incline-dumbbell-press',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-seated-dumbbell-shoulder-press',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-lateral-raise',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-cable-triceps-pushdown',
          targetReps: 15,
          notes: 'Target 10–15 reps; rest 60–90 sec',
        ),
        _pushAExtension,
      ],
    ),
    _workout(
      id: 'seed-workout-pull-a',
      name: 'Pull A',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-barbell-bent-over-row',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-one-arm-dumbbell-row',
          targetReps: 12,
          notes: 'Target 8–12 reps per side; rest 90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-cable-lat-pulldown',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-rear-delt-fly',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-hammer-curl',
          targetReps: 15,
          notes: 'Target 10–15 reps; rest 60–90 sec',
        ),
      ],
    ),
    _workout(
      id: 'seed-workout-legs-a',
      name: 'Legs A',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-barbell-back-squat',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-romanian-deadlift',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-reverse-lunge',
          targetReps: 12,
          notes: 'Target 8–12 reps per leg; rest 90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-standing-dumbbell-calf-raise',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-plank',
          targetReps: 45,
          notes: 'Hold for 30–45 seconds; rest 60 sec',
        ),
      ],
    ),
    _workout(
      id: 'seed-workout-push-b',
      name: 'Push B',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-incline-barbell-bench-press',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-flat-dumbbell-bench-press',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-standing-barbell-overhead-press',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-lateral-raise',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-overhead-dumbbell-triceps-extension',
          targetReps: 15,
          notes: 'Target 10–15 reps; rest 60–90 sec',
        ),
      ],
    ),
    _workout(
      id: 'seed-workout-pull-b',
      name: 'Pull B',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-conventional-deadlift',
          targetReps: 8,
          notes: 'Target 5–8 reps; rest 3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-chest-supported-dumbbell-row',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-cable-seated-row',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-cable-face-pull',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-alternating-dumbbell-curl',
          targetReps: 15,
          notes: 'Target 10–15 reps per arm; rest 60–90 sec',
        ),
      ],
    ),
    _workout(
      id: 'seed-workout-legs-b',
      name: 'Legs B',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          exerciseId: 'seed-exercise-barbell-front-squat',
          targetReps: 10,
          notes: 'Target 6–10 reps; rest 2–3 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-barbell-hip-thrust',
          targetReps: 12,
          notes: 'Target 8–12 reps; rest 2 min',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-dumbbell-bulgarian-split-squat',
          targetReps: 12,
          notes: 'Target 8–12 reps per leg; rest 90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-standing-dumbbell-calf-raise',
          targetReps: 15,
          notes: 'Target 12–15 reps; rest 60–90 sec',
        ),
        _ExercisePrescription(
          exerciseId: 'seed-exercise-lying-leg-raise',
          targetReps: 15,
          notes: 'Target 10–15 reps; rest 60 sec',
        ),
      ],
    ),
  ];

  static const _ExercisePrescription _pushAExtension = _ExercisePrescription(
    exerciseId: 'seed-exercise-overhead-rope-triceps-extension',
    targetReps: 15,
    setCount: 1,
    notes: 'Target 10-15 reps; rest 60-90 sec',
  );

  static Workout _workout({
    required String id,
    required String name,
    required List<_ExercisePrescription> prescriptions,
  }) {
    return Workout(
      id: id,
      name: name,
      scheduledDate: DateTime.utc(2000),
      status: WorkoutStatus.planned,
      exerciseIds: prescriptions
          .map((_ExercisePrescription prescription) => prescription.exerciseId)
          .toList(growable: false),
      sets: <WorkoutSet>[
        for (final _ExercisePrescription prescription in prescriptions)
          for (int setNumber = 1;
              setNumber <= prescription.setCount;
              setNumber++)
            WorkoutSet(
              id: 'seed-set-$id-${prescription.exerciseId}-$setNumber',
              exerciseId: prescription.exerciseId,
              setNumber: setNumber,
              targetReps: prescription.targetReps,
              status: WorkoutSetStatus.planned,
              notes: prescription.notes,
            ),
      ],
    );
  }
}

class _ExercisePrescription {
  const _ExercisePrescription({
    required this.exerciseId,
    required this.targetReps,
    required this.notes,
    this.setCount = 3,
  });

  final String exerciseId;
  final int targetReps;
  final String notes;
  final int setCount;
}
