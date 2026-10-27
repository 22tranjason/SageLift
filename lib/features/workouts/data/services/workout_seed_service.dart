import '../../../../core/storage/key_value_store.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/back_biceps_program_v2.dart';
import '../../domain/services/equipment_program_update.dart';
import '../../domain/services/workout_program.dart';

/// Adds future Hybrid templates without changing any historical records.
class WorkoutSeedService {
  /// Creates a seed service over the workout and exercise repositories.
  const WorkoutSeedService({
    required ExerciseRepository exerciseRepository,
    required WorkoutRepository workoutRepository,
    KeyValueStore? settingsStore,
  })  : _exerciseRepository = exerciseRepository,
        _workoutRepository = workoutRepository,
        _settingsStore = settingsStore;

  final ExerciseRepository _exerciseRepository;
  final WorkoutRepository _workoutRepository;
  final KeyValueStore? _settingsStore;

  /// Inserts missing Hybrid catalogue entries and templates idempotently.
  ///
  /// Existing PPL, CrossFit, and completed Hybrid records remain unchanged.
  /// Unfinished Hybrid records lose only their retired conditioning section.
  Future<void> seedIfEmpty() async {
    await _seedMissingHybridData();
    for (final Workout workout in await _workoutRepository.getAll()) {
      // Any persisted draft, including an unknown version, protects the session.
      final bool hasDraft = await _settingsStore?.read<Object>(
            'workouts.draft.v1.${workout.id}',
          ) !=
          null;
      final Workout migrated = hasDraft
          ? workout
          : EquipmentProgramUpdate.migrateUnstarted(
              BackBicepsProgramV2.migrateUnstarted(workout),
            );
      final Workout cleaned = WorkoutProgram.withoutUnfinishedConditioning(
        migrated,
      );
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
      ..sort(
        (Workout first, Workout second) => first.id.compareTo(second.id),
      );
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
    _exercise(
      'seed-exercise-barbell-bench-press',
      'Barbell Bench Press',
      MuscleGroup.chest,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-incline-dumbbell-press',
      'Incline Dumbbell Press',
      MuscleGroup.chest,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-seated-dumbbell-shoulder-press',
      'Seated Dumbbell Shoulder Press',
      MuscleGroup.shoulders,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-dumbbell-lateral-raise',
      'Dumbbell Lateral Raise',
      MuscleGroup.shoulders,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-overhead-dumbbell-triceps-extension',
      'Overhead Triceps Extension',
      MuscleGroup.arms,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-barbell-bent-over-row',
      'Barbell Bent-Over Row',
      MuscleGroup.back,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-cable-lat-pulldown',
      'Cable Lat Pulldown',
      MuscleGroup.back,
      Equipment.cableMachine,
    ),
    _exercise(
      'seed-exercise-one-arm-dumbbell-row',
      'One-Arm Dumbbell Row',
      MuscleGroup.back,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-dumbbell-rear-delt-fly',
      'Dumbbell Rear-Delt Fly',
      MuscleGroup.shoulders,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-dumbbell-hammer-curl',
      'Dumbbell Hammer Curl',
      MuscleGroup.arms,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-barbell-back-squat',
      'Barbell Back Squat',
      MuscleGroup.legs,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-romanian-deadlift',
      'Romanian Deadlift',
      MuscleGroup.legs,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-dumbbell-reverse-lunge',
      'Dumbbell Reverse Lunge',
      MuscleGroup.legs,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-standing-dumbbell-calf-raise',
      'Standing Dumbbell Calf Raise',
      MuscleGroup.legs,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-plank',
      'Plank',
      MuscleGroup.core,
      Equipment.bodyweight,
    ),
    _exercise(
      'seed-exercise-incline-barbell-bench-press',
      'Incline Barbell Bench Press',
      MuscleGroup.chest,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-flat-dumbbell-bench-press',
      'Flat Dumbbell Bench Press',
      MuscleGroup.chest,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-standing-barbell-overhead-press',
      'Standing Barbell Overhead Press',
      MuscleGroup.shoulders,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-conventional-deadlift',
      'Conventional Deadlift',
      MuscleGroup.legs,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-chest-supported-dumbbell-row',
      'Chest-Supported Dumbbell Row on Incline Bench',
      MuscleGroup.back,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-cable-seated-row',
      'Cable Seated Row',
      MuscleGroup.back,
      Equipment.cableMachine,
    ),
    _exercise(
      'seed-exercise-cable-face-pull',
      'Cable Face Pull',
      MuscleGroup.shoulders,
      Equipment.cableMachine,
    ),
    _exercise(
      'seed-exercise-alternating-dumbbell-curl',
      'Alternating Dumbbell Curl',
      MuscleGroup.arms,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-ez-bar-curl',
      'EZ-Bar Curl',
      MuscleGroup.arms,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-barbell-front-squat',
      'Barbell Front Squat',
      MuscleGroup.legs,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-barbell-hip-thrust',
      'Barbell Hip Thrust',
      MuscleGroup.glutes,
      Equipment.barbell,
    ),
    _exercise(
      'seed-exercise-dumbbell-bulgarian-split-squat',
      'Dumbbell Bulgarian Split Squat',
      MuscleGroup.legs,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-lying-leg-raise',
      'Lying Leg Raise',
      MuscleGroup.core,
      Equipment.bodyweight,
    ),
    _exercise(
      'seed-exercise-cable-chest-fly',
      'Cable Chest Fly',
      MuscleGroup.chest,
      Equipment.cableMachine,
    ),
    _exercise(
      'seed-exercise-dumbbell-fly',
      'Dumbbell Fly (Flat Bench)',
      MuscleGroup.chest,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-cable-triceps-pushdown',
      'Cable Triceps Pushdown',
      MuscleGroup.arms,
      Equipment.cableMachine,
    ),
    _exercise(
      'seed-exercise-dumbbell-shrug',
      'Dumbbell Shrug',
      MuscleGroup.shoulders,
      Equipment.dumbbells,
    ),
    _exercise(
      'seed-exercise-bodyweight-hamstring-walkout',
      'Bodyweight Hamstring Walkout',
      MuscleGroup.legs,
      Equipment.bodyweight,
    ),
    _exercise(
      'hybrid-kettlebell-swing',
      'Kettlebell Swing',
      MuscleGroup.fullBody,
      Equipment.kettlebell,
      category: ExerciseCategory.conditioning,
    ),
    _exercise(
      'hybrid-kettlebell-reverse-lunge',
      'Kettlebell Reverse Lunge',
      MuscleGroup.legs,
      Equipment.kettlebell,
      category: ExerciseCategory.conditioning,
    ),
  ];

  static final List<Workout> _hybridWorkouts = <Workout>[
    _hybridWorkout(
      id: 'seed-four-day-chest-triceps-v1',
      name: 'Chest + Triceps',
      warmUp:
          '8–10 min: easy walking and joint mobility, then 2–4 gradual ramp-up sets for the first lift; add light preparation sets before the next compound lift. Warm-ups are not working sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          'seed-exercise-barbell-bench-press',
          6,
          3,
          'Target 4–6 reps; rest 180 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-incline-dumbbell-press',
          10,
          3,
          'Target 8–10 reps; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-fly',
          15,
          3,
          'Target 10–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-overhead-dumbbell-triceps-extension',
          15,
          3,
          'Target 10–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-cable-triceps-pushdown',
          15,
          3,
          'Target 10–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
      ],
    ),
    _hybridWorkout(
      id: 'seed-four-day-back-biceps-v1',
      name: 'Back + Biceps',
      warmUp:
          '8–10 min: easy walking and joint mobility, then 2–4 gradual ramp-up sets for the first lift; add light preparation sets before the next compound lift. Warm-ups are not working sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          'seed-exercise-barbell-bent-over-row',
          8,
          3,
          'Target 6–8 reps; rest 150–180 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-cable-lat-pulldown',
          12,
          3,
          'Target 8–12 reps; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-chest-supported-dumbbell-row',
          12,
          3,
          'Target 8–12 reps; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-ez-bar-curl',
          12,
          3,
          'Target 8–12 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-hammer-curl',
          15,
          3,
          'Target 10–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
      ],
    ),
    _hybridWorkout(
      id: 'seed-four-day-shoulders-traps-v1',
      name: 'Shoulders + Traps',
      warmUp:
          '8–10 min: easy walking and joint mobility, then 2–4 gradual ramp-up sets for the first lift; add light preparation sets before the next compound lift. Warm-ups are not working sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          'seed-exercise-standing-barbell-overhead-press',
          6,
          3,
          'Target 4–6 reps; rest 180 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-lateral-raise',
          15,
          3,
          'Target 12–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-rear-delt-fly',
          15,
          3,
          'Target 12–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-shrug',
          15,
          3,
          'Target 10–15 reps; rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
      ],
    ),
    _hybridWorkout(
      id: 'seed-four-day-legs-calves-v1',
      name: 'Legs + Calves',
      warmUp:
          '8–10 min: easy walking and joint mobility, then 2–4 gradual ramp-up sets for the first lift; add light preparation sets before the next compound lift. Warm-ups are not working sets.',
      prescriptions: const <_ExercisePrescription>[
        _ExercisePrescription(
          'seed-exercise-barbell-back-squat',
          6,
          3,
          'Target 4–6 reps; rest 180 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-romanian-deadlift',
          10,
          3,
          'Target 6–10 reps; rest 150–180 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-dumbbell-reverse-lunge',
          12,
          2,
          'Target 8–12 reps per leg; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
        _ExercisePrescription(
          'seed-exercise-standing-dumbbell-calf-raise',
          15,
          4,
          'Target 10–15 reps; rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
        ),
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
      warmUp:
          '$warmUp Keep a controlled technique; no maximal attempts. When every working set reaches the top of its range with 2–3 reps in reserve, add the smallest available weight next time. Reduce load or sets if recovery or technique suffers; fatigue is not the goal.',
      sessionDurationTarget: name == 'Legs + Calves'
          ? 'About 65–75 min including warm-up'
          : 'About 50–60 min including warm-up',
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
