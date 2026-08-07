import '../../domain/models/conditioning.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_program.dart';

/// Adds Jason's PPL and CrossFit programmes without replacing local history.
class WorkoutSeedService {
  /// Creates a seed service over the workout and exercise repositories.
  const WorkoutSeedService({
    required ExerciseRepository exerciseRepository,
    required WorkoutRepository workoutRepository,
  })  : _exerciseRepository = exerciseRepository,
        _workoutRepository = workoutRepository;

  final ExerciseRepository _exerciseRepository;
  final WorkoutRepository _workoutRepository;

  /// Inserts both programmes when the workout database is completely empty.
  ///
  /// Repeated calls never reseed or delete history. They safely upgrade planned
  /// Push A sessions, adds the independent CrossFit seed to established PPL
  /// databases, and reconciles one planned session for each programme.
  Future<void> seedIfEmpty() async {
    final List<Exercise> existingExercises = await _exerciseRepository.getAll();
    final List<Workout> existingWorkouts = await _workoutRepository.getAll();
    if (existingExercises.isNotEmpty || existingWorkouts.isNotEmpty) {
      await _upgradePlannedPushA(
        existingExercises: existingExercises,
        existingWorkouts: existingWorkouts,
      );
      await _seedMissingCrossFitData();
      await _upgradePlannedCrossFitWorkouts();
      await _reconcileRecommendedPlannedWorkout(WorkoutTrack.strengthPpl);
      await _reconcileRecommendedPlannedWorkout(WorkoutTrack.crossFit);
      return;
    }

    for (final Exercise exercise in _allExercises) {
      await _exerciseRepository.save(exercise);
    }
    for (final Workout workout in _allWorkouts) {
      await _workoutRepository.save(workout);
    }
  }

  /// Compatibility reconciliation for existing local databases.
  ///
  /// It preserves completed history and existing planned sessions. A new session
  /// is created only when the recommended program name has no planned record.
  Future<void> _reconcileRecommendedPlannedWorkout(WorkoutTrack track) async {
    final List<Workout> workouts = await _workoutRepository.getAll();
    if (workouts.any(
      (Workout workout) => workout.status == WorkoutStatus.inProgress,
    )) {
      return;
    }
    final String recommendedName = WorkoutProgram.recommendedNextWorkoutName(
      workouts,
      track: track,
    );
    if (workouts.any(
      (Workout workout) =>
          workout.status == WorkoutStatus.planned &&
          workout.track == track &&
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

  Future<void> _seedMissingCrossFitData() async {
    final List<Exercise> exercises = await _exerciseRepository.getAll();
    for (final Exercise exercise in _crossFitExercises) {
      if (!exercises.any((Exercise existing) => existing.id == exercise.id)) {
        await _exerciseRepository.save(exercise);
      }
    }
    final List<Workout> workouts = await _workoutRepository.getAll();
    for (final Workout workout in _crossFitWorkouts) {
      if (!workouts.any((Workout existing) => existing.id == workout.id)) {
        await _workoutRepository.save(workout);
      }
    }
  }

  /// Adds structured movement plans only to legacy, still-planned CrossFit
  /// templates. Completed sessions retain their original factual records.
  Future<void> _upgradePlannedCrossFitWorkouts() async {
    final List<Workout> workouts = await _workoutRepository.getAll();
    for (final Workout workout in workouts) {
      if (workout.track != WorkoutTrack.crossFit ||
          workout.status != WorkoutStatus.planned ||
          (workout.conditioningPlan?.movements.isNotEmpty ?? false)) {
        continue;
      }
      final List<Workout> seeds = _crossFitWorkouts
          .where((Workout candidate) => candidate.id == workout.id)
          .toList(growable: false);
      if (seeds.isEmpty) continue;
      final Workout seed = seeds.first;
      await _workoutRepository.save(
        workout.copyWith(
          conditioningPlan: seed.conditioningPlan,
          sessionDurationTarget: seed.sessionDurationTarget,
        ),
      );
    }
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

  static const List<Exercise> _crossFitExercises = <Exercise>[
    Exercise(
        id: 'crossfit-push-press',
        name: 'Barbell Push Press',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.shoulders,
        equipment: Equipment.barbell),
    Exercise(
        id: 'crossfit-band-chest-to-bar',
        name: 'Band-Assisted Chest-to-Bar Pull-up',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.back,
        equipment: Equipment.resistanceBand),
    Exercise(
        id: 'crossfit-step-ups',
        name: 'Step-ups',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.bodyweight),
    Exercise(
        id: 'crossfit-db-clean-press',
        name: 'Dumbbell Clean & Press',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.fullBody,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-scaled-wall-walk',
        name: 'Scaled Wall Walk',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.shoulders,
        equipment: Equipment.bodyweight),
    Exercise(
        id: 'crossfit-air-squat',
        name: 'Air Squat',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.bodyweight),
    Exercise(
        id: 'crossfit-reverse-lunge',
        name: 'Alternating Goblet Reverse Lunge',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-db-deadlift',
        name: 'Dumbbell Deadlift',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-barbell-deadlift',
        name: 'Barbell Deadlift',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.barbell),
    Exercise(
        id: 'crossfit-db-rdl',
        name: 'Dumbbell Romanian Deadlift',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-push-up',
        name: 'Push-up',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.chest,
        equipment: Equipment.bodyweight),
    Exercise(
        id: 'crossfit-band-pull-up',
        name: 'Band-Assisted Pull-up',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.back,
        equipment: Equipment.resistanceBand),
    Exercise(
        id: 'crossfit-db-bench-press',
        name: 'Dumbbell Bench Press',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.chest,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-db-row',
        name: 'Dumbbell Row',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.back,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-db-goblet-squat',
        name: 'Dumbbell Goblet Squat',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-db-clean',
        name: 'Dumbbell Clean',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.fullBody,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-goblet-squat',
        name: 'Goblet Squat',
        category: ExerciseCategory.strength,
        primaryMuscleGroup: MuscleGroup.legs,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-db-push-press',
        name: 'Dumbbell Push Press',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.shoulders,
        equipment: Equipment.dumbbells),
    Exercise(
        id: 'crossfit-sit-up',
        name: 'Sit-up',
        category: ExerciseCategory.conditioning,
        primaryMuscleGroup: MuscleGroup.core,
        equipment: Equipment.bodyweight),
  ];

  static const List<Exercise> _allExercises = <Exercise>[
    ..._exercises,
    ..._crossFitExercises,
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

  static final List<Workout> _crossFitWorkouts = <Workout>[
    _crossFitWorkout(
      id: 'seed-workout-crossfit-a',
      name: 'CrossFit A',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'crossfit-push-press',
            targetReps: 5,
            setCount: 5,
            notes: '1-second overhead lockout'),
        _ExercisePrescription(
            exerciseId: 'crossfit-band-chest-to-bar',
            targetReps: 8,
            setCount: 5,
            notes: 'Band-assisted; use a controlled chest-to-bar pull'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.roundsForTime,
        title: '4 rounds for time',
        prescribedRounds: 4,
        instructions:
            '20 Step-ups\n200 m Run\n10 Dumbbell Clean & Press\n5 Scaled Wall Walks',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'step-ups',
              name: 'Step-ups',
              prescribedReps: 20,
              isBodyweight: true),
          ConditioningMovement(
              id: 'run',
              name: 'Run',
              prescribedDistance: 200,
              distanceUnit: DistanceUnit.metres,
              isBodyweight: true),
          ConditioningMovement(
              id: 'db-clean-press',
              name: 'Dumbbell Clean & Press',
              prescribedReps: 10),
          ConditioningMovement(
              id: 'wall-walk',
              name: 'Scaled Wall Walk',
              prescribedReps: 5,
              isBodyweight: true),
        ],
      ),
    ),
    _crossFitWorkout(
      id: 'seed-workout-crossfit-b',
      name: 'CrossFit B',
      warmUp:
          '2 rounds:\n10 Air Squats\n8 Alternating Reverse Lunges\n10 Light Dumbbell Deadlifts\n20 sec Plank\nThen approximately 60 sec easy jog/walk',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'seed-exercise-barbell-back-squat',
            targetReps: 5,
            setCount: 5,
            notes: 'Rest 90–120 sec'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.roundsForTime,
        title: '4 rounds for time',
        prescribedRounds: 4,
        instructions:
            '12 Alternating Goblet Reverse Lunges (6 each leg)\n15 Dumbbell Deadlifts\n12 Step-ups (6 each leg)\n200 m Run\nScaling: replace step-ups with 15 Air Squats if no safe platform is available.',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'goblet-reverse-lunge',
              name: 'Goblet Reverse Lunge',
              prescribedReps: 12),
          ConditioningMovement(
              id: 'dumbbell-deadlift',
              name: 'Dumbbell Deadlift',
              prescribedReps: 15,
              implementCount: 2),
          ConditioningMovement(
              id: 'step-ups',
              name: 'Step-ups',
              prescribedReps: 12,
              isBodyweight: true),
          ConditioningMovement(
              id: 'run',
              name: 'Run',
              prescribedDistance: 200,
              distanceUnit: DistanceUnit.metres,
              isBodyweight: true),
        ],
      ),
    ),
    _crossFitWorkout(
      id: 'seed-workout-crossfit-c',
      name: 'CrossFit C',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'crossfit-barbell-deadlift',
            targetReps: 5,
            setCount: 5,
            notes: 'Strength: 5 × 5'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.amrap,
        title: '12-minute AMRAP',
        durationMinutes: 12,
        instructions:
            '8 Dumbbell Romanian Deadlifts\n10 Push-ups\n12 Air Squats\n200 m Run\nScaling: elevated/incline push-ups are allowed.',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'db-rdl',
              name: 'Dumbbell Romanian Deadlift',
              prescribedReps: 8,
              implementCount: 2),
          ConditioningMovement(
              id: 'push-up',
              name: 'Push-up',
              prescribedReps: 10,
              isBodyweight: true),
          ConditioningMovement(
              id: 'air-squat',
              name: 'Air Squat',
              prescribedReps: 12,
              isBodyweight: true),
          ConditioningMovement(
              id: 'run',
              name: 'Run',
              prescribedDistance: 200,
              distanceUnit: DistanceUnit.metres,
              isBodyweight: true),
        ],
      ),
    ),
    _crossFitWorkout(
      id: 'seed-workout-crossfit-d',
      name: 'CrossFit D',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'crossfit-band-pull-up',
            targetReps: 7,
            setCount: 5,
            notes: 'Target 6–8 reps'),
        _ExercisePrescription(
            exerciseId: 'crossfit-db-bench-press',
            targetReps: 8,
            setCount: 4,
            notes: 'Strength: 4 × 8'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.roundsForTime,
        title: '4 rounds for time',
        prescribedRounds: 4,
        instructions:
            '10 Dumbbell Rows (5 each side)\n10 Push-ups\n12 Dumbbell Goblet Squats\n200 m Run',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'db-row', name: 'Dumbbell Row', prescribedReps: 10),
          ConditioningMovement(
              id: 'push-up',
              name: 'Push-up',
              prescribedReps: 10,
              isBodyweight: true),
          ConditioningMovement(
              id: 'db-goblet-squat',
              name: 'Dumbbell Goblet Squat',
              prescribedReps: 12),
          ConditioningMovement(
              id: 'run',
              name: 'Run',
              prescribedDistance: 200,
              distanceUnit: DistanceUnit.metres,
              isBodyweight: true),
        ],
      ),
    ),
    _crossFitWorkout(
      id: 'seed-workout-crossfit-e',
      name: 'CrossFit E',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'crossfit-db-clean',
            targetReps: 5,
            setCount: 5,
            notes:
                '5 each side; keep load deliberately light and technique-focused.'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.emom,
        title: '15-minute EMOM',
        durationMinutes: 15,
        instructions:
            'Minute 1: 10 Dumbbell Goblet Squats\nMinute 2: 8 Dumbbell Clean & Press (4 each side)\nMinute 3: 40 sec brisk run / shuttle / fast walk\nRepeat for 5 cycles.',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'db-goblet-squat',
              name: 'Dumbbell Goblet Squat',
              prescribedReps: 10),
          ConditioningMovement(
              id: 'db-clean-press',
              name: 'Dumbbell Clean & Press',
              prescribedReps: 8),
          ConditioningMovement(
              id: 'brisk-run',
              name: 'Brisk run / shuttle / fast walk',
              notes: '40 sec',
              isBodyweight: true),
        ],
      ),
    ),
    _crossFitWorkout(
      id: 'seed-workout-crossfit-f',
      name: 'CrossFit F',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
            exerciseId: 'crossfit-goblet-squat',
            targetReps: 10,
            setCount: 4,
            notes: 'Strength: 4 × 10'),
      ],
      conditioningPlan: ConditioningPlan(
        format: ConditioningFormat.amrap,
        title: '20-minute AMRAP',
        durationMinutes: 20,
        instructions:
            '200 m Run\n10 Dumbbell Deadlifts\n10 Step-ups\n8 Dumbbell Push Press\n10 Sit-ups\nScaling: replace step-ups with 15 Air Squats if no safe platform is available.',
        movements: const <ConditioningMovement>[
          ConditioningMovement(
              id: 'run',
              name: 'Run',
              prescribedDistance: 200,
              distanceUnit: DistanceUnit.metres,
              isBodyweight: true),
          ConditioningMovement(
              id: 'dumbbell-deadlift',
              name: 'Dumbbell Deadlift',
              prescribedReps: 10,
              implementCount: 2),
          ConditioningMovement(
              id: 'step-ups',
              name: 'Step-ups',
              prescribedReps: 10,
              isBodyweight: true),
          ConditioningMovement(
              id: 'db-push-press',
              name: 'Dumbbell Push Press',
              prescribedReps: 8),
          ConditioningMovement(
              id: 'sit-up',
              name: 'Sit-up',
              prescribedReps: 10,
              isBodyweight: true),
        ],
      ),
    ),
  ];

  static final List<Workout> _allWorkouts = <Workout>[
    ..._workouts,
    ..._crossFitWorkouts,
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

  static Workout _crossFitWorkout({
    required String id,
    required String name,
    required List<_ExercisePrescription> prescriptions,
    required ConditioningPlan conditioningPlan,
    String? warmUp,
  }) {
    final Workout baseWorkout = _workout(
      id: id,
      name: name,
      prescriptions: prescriptions,
    );
    return baseWorkout.copyWith(
      track: WorkoutTrack.crossFit,
      warmUp: warmUp,
      conditioningPlan: conditioningPlan,
      sessionDurationTarget: '35–45 min',
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
