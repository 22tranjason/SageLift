import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_program.dart';

/// Adds future Hybrid templates without changing any historical records.
class WorkoutSeedService {
  /// Creates a seed service over the workout and exercise repositories.
  const WorkoutSeedService({
    required ExerciseRepository exerciseRepository,
    required WorkoutRepository workoutRepository,
  })  : _exerciseRepository = exerciseRepository,
        _workoutRepository = workoutRepository;

  final ExerciseRepository _exerciseRepository;
  final WorkoutRepository _workoutRepository;

  /// Inserts missing Hybrid catalogue entries and templates idempotently.
  ///
  /// Existing PPL, CrossFit, and completed Hybrid records remain unchanged.
  /// Unfinished Hybrid records lose only their retired conditioning section.
  Future<void> seedIfEmpty() async {
    await _seedMissingHybridData();
    for (final Workout workout in await _workoutRepository.getAll()) {
      final Workout cleaned =
          WorkoutProgram.withoutUnfinishedConditioning(workout);
      if (!identical(cleaned, workout)) await _workoutRepository.save(cleaned);
    }
    await _reconcileRecommendedPlannedWorkout();
  }

  Future<void> _seedMissingHybridData() async {
    final List<Exercise> exercises = await _exerciseRepository.getAll();
    for (final Exercise exercise in _hybridExercises) {
      if (!exercises.any((Exercise value) => value.id == exercise.id)) {
        await _exerciseRepository.save(exercise);
      }
    }

    final List<Workout> workouts = await _workoutRepository.getAll();
    for (final Workout workout in _hybridWorkouts) {
      if (!workouts.any((Workout value) => value.id == workout.id)) {
        await _workoutRepository.save(workout);
      }
    }
  }

  Future<void> _reconcileRecommendedPlannedWorkout() async {
    final List<Workout> workouts = await _workoutRepository.getAll();
    if (workouts.any(
      (Workout workout) =>
          workout.track == WorkoutTrack.hybrid &&
          workout.status == WorkoutStatus.inProgress,
    )) {
      return;
    }
    final String recommendedName = WorkoutProgram.recommendedNextWorkoutName(
      workouts,
      track: WorkoutTrack.hybrid,
    );
    if (workouts.any(
      (Workout workout) =>
          workout.track == WorkoutTrack.hybrid &&
          workout.status == WorkoutStatus.planned &&
          workout.name == recommendedName,
    )) {
      return;
    }
    final List<Workout> templates = workouts
        .where(
          (Workout workout) =>
              workout.track == WorkoutTrack.hybrid &&
              workout.name == recommendedName,
        )
        .toList(growable: false)
      ..sort((Workout first, Workout second) => first.id.compareTo(second.id));
    if (templates.isEmpty) {
      return;
    }
    final DateTime now = DateTime.now();
    await _workoutRepository.save(
      WorkoutProgram.createPlannedSession(
        template: templates.first,
        id: 'program-migration-'
            '${recommendedName.toLowerCase().replaceAll(' ', '-')}-'
            '${now.microsecondsSinceEpoch}-${workouts.length}',
        scheduledDate: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  static final List<Exercise> _hybridExercises = <Exercise>[
    _exercise('seed-exercise-barbell-bench-press', 'Barbell Bench Press',
        MuscleGroup.chest, Equipment.barbell),
    _exercise('seed-exercise-incline-dumbbell-press', 'Incline Dumbbell Press',
        MuscleGroup.chest, Equipment.dumbbells),
    _exercise(
        'seed-exercise-seated-dumbbell-shoulder-press',
        'Seated Dumbbell Shoulder Press',
        MuscleGroup.shoulders,
        Equipment.dumbbells),
    _exercise('seed-exercise-dumbbell-lateral-raise', 'Dumbbell Lateral Raise',
        MuscleGroup.shoulders, Equipment.dumbbells),
    _exercise('seed-exercise-overhead-dumbbell-triceps-extension',
        'Overhead Triceps Extension', MuscleGroup.arms, Equipment.dumbbells),
    _exercise('seed-exercise-barbell-bent-over-row', 'Barbell Bent-Over Row',
        MuscleGroup.back, Equipment.barbell),
    _exercise('seed-exercise-cable-lat-pulldown', 'Cable Lat Pulldown',
        MuscleGroup.back, Equipment.cableMachine),
    _exercise('seed-exercise-one-arm-dumbbell-row', 'One-Arm Dumbbell Row',
        MuscleGroup.back, Equipment.dumbbells),
    _exercise('seed-exercise-dumbbell-rear-delt-fly', 'Dumbbell Rear-Delt Fly',
        MuscleGroup.shoulders, Equipment.dumbbells),
    _exercise('seed-exercise-dumbbell-hammer-curl', 'Dumbbell Hammer Curl',
        MuscleGroup.arms, Equipment.dumbbells),
    _exercise('seed-exercise-barbell-back-squat', 'Barbell Back Squat',
        MuscleGroup.legs, Equipment.barbell),
    _exercise('seed-exercise-romanian-deadlift', 'Romanian Deadlift',
        MuscleGroup.legs, Equipment.barbell),
    _exercise('seed-exercise-dumbbell-reverse-lunge', 'Dumbbell Reverse Lunge',
        MuscleGroup.legs, Equipment.dumbbells),
    _exercise('seed-exercise-standing-dumbbell-calf-raise',
        'Standing Dumbbell Calf Raise', MuscleGroup.legs, Equipment.dumbbells),
    _exercise(
        'seed-exercise-plank', 'Plank', MuscleGroup.core, Equipment.bodyweight),
    _exercise('seed-exercise-incline-barbell-bench-press',
        'Incline Barbell Bench Press', MuscleGroup.chest, Equipment.barbell),
    _exercise('seed-exercise-flat-dumbbell-bench-press',
        'Flat Dumbbell Bench Press', MuscleGroup.chest, Equipment.dumbbells),
    _exercise(
        'seed-exercise-standing-barbell-overhead-press',
        'Standing Barbell Overhead Press',
        MuscleGroup.shoulders,
        Equipment.barbell),
    _exercise('seed-exercise-conventional-deadlift', 'Conventional Deadlift',
        MuscleGroup.legs, Equipment.barbell),
    _exercise(
        'seed-exercise-chest-supported-dumbbell-row',
        'Chest-Supported Dumbbell Row on Incline Bench',
        MuscleGroup.back,
        Equipment.dumbbells),
    _exercise('seed-exercise-cable-seated-row', 'Cable Seated Row',
        MuscleGroup.back, Equipment.cableMachine),
    _exercise('seed-exercise-cable-face-pull', 'Cable Face Pull',
        MuscleGroup.shoulders, Equipment.cableMachine),
    _exercise('seed-exercise-alternating-dumbbell-curl',
        'Alternating Dumbbell Curl', MuscleGroup.arms, Equipment.dumbbells),
    _exercise('seed-exercise-barbell-front-squat', 'Barbell Front Squat',
        MuscleGroup.legs, Equipment.barbell),
    _exercise('seed-exercise-barbell-hip-thrust', 'Barbell Hip Thrust',
        MuscleGroup.glutes, Equipment.barbell),
    _exercise(
        'seed-exercise-dumbbell-bulgarian-split-squat',
        'Dumbbell Bulgarian Split Squat',
        MuscleGroup.legs,
        Equipment.dumbbells),
    _exercise('seed-exercise-lying-leg-raise', 'Lying Leg Raise',
        MuscleGroup.core, Equipment.bodyweight),
    _exercise('hybrid-kettlebell-swing', 'Kettlebell Swing',
        MuscleGroup.fullBody, Equipment.kettlebell,
        category: ExerciseCategory.conditioning),
    _exercise('hybrid-kettlebell-reverse-lunge', 'Kettlebell Reverse Lunge',
        MuscleGroup.legs, Equipment.kettlebell,
        category: ExerciseCategory.conditioning),
  ];

  static final List<Workout> _hybridWorkouts = <Workout>[
    _hybridWorkout(
      id: 'seed-workout-push-a-hybrid',
      name: 'Push A Hybrid',
      warmUp:
          'About 5 min: easy walk or jog, shoulder circles, band pull-aparts, and two light bench-press ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-barbell-bench-press', 8, 4,
            'Target 6–8 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-incline-dumbbell-press', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-seated-dumbbell-shoulder-press',
            10, 3, 'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-lateral-raise', 15, 3,
            'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription(
            'seed-exercise-overhead-dumbbell-triceps-extension',
            15,
            3,
            'Target 10–15 reps; rest about 45 sec'),
      ],
    ),
    _hybridWorkout(
      id: 'seed-workout-pull-a-hybrid',
      name: 'Pull A Hybrid',
      warmUp:
          'About 5 min: easy walk or jog, band rows, shoulder circles, and two light row ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-barbell-bent-over-row', 8, 4,
            'Target 6–8 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-cable-lat-pulldown', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-one-arm-dumbbell-row', 10, 3,
            'Target 8–10 reps per side; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-rear-delt-fly', 15, 3,
            'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-hammer-curl', 12, 3,
            'Target 10–12 reps; rest about 45 sec'),
      ],
    ),
    _hybridWorkout(
      id: 'seed-workout-legs-a-hybrid',
      name: 'Legs A Hybrid',
      warmUp:
          'About 5 min: easy walk, bodyweight squats, hip hinges, and two light squat ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-barbell-back-squat', 8, 4,
            'Target 6–8 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-romanian-deadlift', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-reverse-lunge', 10, 3,
            'Target 8–10 reps per leg; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-standing-dumbbell-calf-raise', 15,
            3, 'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription(
            'seed-exercise-plank', 45, 3, 'Hold 30–45 sec; rest about 45 sec'),
      ],
    ),
    _hybridWorkout(
      id: 'seed-workout-push-b-hybrid',
      name: 'Push B Hybrid',
      warmUp:
          'About 5 min: easy walk or jog, shoulder mobility, band pull-aparts, and two light press ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-incline-barbell-bench-press', 8, 4,
            'Target 6–8 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-flat-dumbbell-bench-press', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-standing-barbell-overhead-press',
            8, 3, 'Target 6–8 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-lateral-raise', 15, 3,
            'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription(
            'seed-exercise-overhead-dumbbell-triceps-extension',
            12,
            3,
            'Target 10–15 reps; rest about 45 sec'),
      ],
    ),
    _hybridWorkout(
      id: 'seed-workout-pull-b-hybrid',
      name: 'Pull B Hybrid',
      warmUp:
          'About 5 min: easy walk, hip hinges, band rows, and several light deadlift ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-conventional-deadlift', 6, 3,
            'Target 5–6 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-chest-supported-dumbbell-row', 10,
            3, 'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-cable-seated-row', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-cable-face-pull', 15, 3,
            'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription('seed-exercise-alternating-dumbbell-curl', 12, 3,
            'Target 10–12 reps; rest about 45 sec'),
      ],
    ),
    _hybridWorkout(
      id: 'seed-workout-legs-b-hybrid',
      name: 'Legs B Hybrid',
      warmUp:
          'About 5 min: easy walk, bodyweight lunges, hip hinges, and two light front-squat ramp-up sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription('seed-exercise-barbell-front-squat', 8, 4,
            'Target 6–8 reps; rest about 90 sec'),
        _ExercisePrescription('seed-exercise-barbell-hip-thrust', 10, 3,
            'Target 8–10 reps; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-dumbbell-bulgarian-split-squat',
            10, 3, 'Target 8–10 reps per leg; rest about 75 sec'),
        _ExercisePrescription('seed-exercise-standing-dumbbell-calf-raise', 15,
            3, 'Target 12–15 reps; rest about 45 sec'),
        _ExercisePrescription('seed-exercise-lying-leg-raise', 12, 3,
            'Target 10–15 reps; rest about 45 sec'),
      ],
    ),
  ];

  static Exercise _exercise(
    String id,
    String name,
    MuscleGroup muscleGroup,
    Equipment equipment, {
    ExerciseCategory category = ExerciseCategory.strength,
  }) {
    return Exercise(
      id: id,
      name: name,
      category: category,
      primaryMuscleGroup: muscleGroup,
      equipment: equipment,
    );
  }

  static Workout _hybridWorkout({
    required String id,
    required String name,
    required String warmUp,
    required List<_ExercisePrescription> prescriptions,
  }) {
    return Workout(
      id: id,
      name: name,
      scheduledDate: DateTime.utc(2000),
      status: WorkoutStatus.planned,
      track: WorkoutTrack.hybrid,
      warmUp: warmUp,
      sessionDurationTarget: 'Up to about 60 min',
      exerciseIds: prescriptions
          .map((_ExercisePrescription value) => value.exerciseId)
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
  const _ExercisePrescription(
    this.exerciseId,
    this.targetReps,
    this.setCount,
    this.notes,
  );

  final String exerciseId;
  final int targetReps;
  final int setCount;
  final String notes;
}
