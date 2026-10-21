import '../models/workout.dart';
import '../models/workout_set.dart';

/// Version 2 of the four-day Back + Biceps defaults.
///
/// The old curl catalogue entry is deliberately retained for factual history.
/// Shape-based, idempotent migration also handles backups predating this release.
class BackBicepsProgramV2 {
  BackBicepsProgramV2._();

  static const String _row = 'seed-exercise-chest-supported-dumbbell-row';
  static const String _hammer = 'seed-exercise-dumbbell-hammer-curl';
  static const String _oldCurl = 'seed-exercise-alternating-dumbbell-curl';
  static const String _curl = 'seed-exercise-ez-bar-curl';
  static const List<String> _v1Exercises = <String>[
    'seed-exercise-barbell-bent-over-row',
    'seed-exercise-cable-lat-pulldown',
    _row,
    _oldCurl,
    _hammer,
  ];

  /// Updates only unstarted, unrecorded v1 plans; callers protect saved drafts.
  /// New sessions cloned from old history pass through here after clearing logs.
  static Workout migrateUnstarted(Workout workout) {
    if (workout.track != WorkoutTrack.hybrid ||
        workout.name != 'Back + Biceps' ||
        workout.status != WorkoutStatus.planned ||
        workout.startedAt != null ||
        workout.completedAt != null ||
        workout.exerciseIds.join('|') != _v1Exercises.join('|') ||
        workout.sets.length != 13 ||
        workout.sets.any(
          (WorkoutSet set) =>
              set.status != WorkoutSetStatus.planned ||
              set.weightKg != null ||
              set.reps != null ||
              set.rpe != null,
        )) {
      return workout;
    }
    for (final String id in _v1Exercises) {
      final List<WorkoutSet> sets =
          workout.sets.where((WorkoutSet set) => set.exerciseId == id).toList();
      final int expected = id == _row || id == _hammer ? 2 : 3;
      if (sets.length != expected ||
          sets.map((WorkoutSet set) => set.setNumber).toSet().length !=
              expected ||
          sets.any(
            (WorkoutSet set) => set.setNumber < 1 || set.setNumber > expected,
          )) {
        return workout;
      }
    }
    return workout.copyWith(
      exerciseIds: workout.exerciseIds
          .map((String id) => id == _oldCurl ? _curl : id)
          .toList(),
      sets: <WorkoutSet>[
        for (final String id in _v1Exercises) ...<WorkoutSet>[
          for (final WorkoutSet set in workout.sets.where(
            (WorkoutSet set) => set.exerciseId == id,
          ))
            if (id == _oldCurl)
              set.copyWith(
                id: '${set.id}-ez-bar-v2',
                exerciseId: _curl,
                targetWeightKg: null,
                targetReps: 12,
                notes:
                    'Target 8–12 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.',
              )
            else
              set,
          if (id == _row || id == _hammer)
            workout.sets
                .firstWhere((WorkoutSet set) => set.exerciseId == id)
                .copyWith(id: '${workout.id}-$id-set-3-v2', setNumber: 3),
        ],
      ],
    );
  }
}
