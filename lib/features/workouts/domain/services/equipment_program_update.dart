import '../models/workout.dart';
import '../models/workout_set.dart';

/// Equipment changes apply only to untouched default plans and future clones.
/// Catalogue entries and performed sessions retain their factual identities.
class EquipmentProgramUpdate {
  EquipmentProgramUpdate._();

  /// Historical cable fly ID retained in the catalogue.
  static const String cableFly = 'seed-exercise-cable-chest-fly';

  /// Flat-bench dumbbell fly catalogue ID.
  static const String dumbbellFly = 'seed-exercise-dumbbell-fly';

  /// Existing historical pushdown catalogue ID.
  static const String pushdown = 'seed-exercise-cable-triceps-pushdown';

  /// Historical walkout ID retained in the catalogue.
  static const String walkout = 'seed-exercise-bodyweight-hamstring-walkout';
  static const String _isolationNotes =
      'Target 10–15 reps; rest 75 sec; leave 2–3 reps in reserve; no mandatory failure.';

  static const List<String> _chest = <String>[
    'seed-exercise-barbell-bench-press',
    'seed-exercise-incline-dumbbell-press',
    cableFly,
    'seed-exercise-overhead-dumbbell-triceps-extension',
  ];
  static const List<String> _legs = <String>[
    'seed-exercise-barbell-back-squat',
    'seed-exercise-romanian-deadlift',
    'seed-exercise-dumbbell-reverse-lunge',
    walkout,
    'seed-exercise-standing-dumbbell-calf-raise',
  ];

  /// Caller must also protect every persisted draft, even unknown versions.
  static Workout migrateUnstarted(Workout workout) {
    if (workout.track != WorkoutTrack.hybrid ||
        workout.status != WorkoutStatus.planned ||
        workout.startedAt != null ||
        workout.completedAt != null ||
        workout.sets.any(
          (WorkoutSet set) =>
              set.status != WorkoutSetStatus.planned ||
              set.weightKg != null ||
              set.reps != null ||
              set.rpe != null,
        )) {
      return workout;
    }
    final bool chest = workout.name == 'Chest + Triceps';
    final bool legs = workout.name == 'Legs + Calves';
    if (!chest && !legs) return workout;
    final List<String> expected = chest ? _chest : _legs;
    final List<int> counts = chest ? <int>[3, 3, 3, 3] : <int>[3, 3, 2, 3, 4];
    final List<int> reps =
        chest ? <int>[6, 10, 15, 15] : <int>[6, 10, 12, 10, 15];
    final List<String> notes = chest
        ? <String>[
            'Target 4–6 reps; rest 180 sec; leave 2–3 reps in reserve; no mandatory failure.',
            'Target 8–10 reps; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
            _isolationNotes,
            _isolationNotes,
          ]
        : <String>[
            'Target 4–6 reps; rest 180 sec; leave 2–3 reps in reserve; no mandatory failure.',
            'Target 6–10 reps; rest 150–180 sec; leave 2–3 reps in reserve; no mandatory failure.',
            'Target 8–12 reps per leg; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.',
            'Target 6–10 reps; each controlled heel walk out and back is one rep. Keep hips comfortably raised; use a short range initially. Rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
            'Target 10–15 reps; rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
          ];
    if (workout.exerciseIds.join('|') != expected.join('|') ||
        workout.sets.length != counts.reduce((int a, int b) => a + b)) {
      return workout;
    }
    for (int index = 0; index < expected.length; index++) {
      final List<WorkoutSet> sets = workout.sets
          .where((WorkoutSet set) => set.exerciseId == expected[index])
          .toList();
      if (sets.length != counts[index] ||
          sets.map((WorkoutSet set) => set.setNumber).toSet().length !=
              counts[index] ||
          sets.any(
            (WorkoutSet set) =>
                set.setNumber < 1 ||
                set.setNumber > counts[index] ||
                set.targetReps != reps[index] ||
                set.notes != notes[index],
          )) {
        return workout;
      }
    }
    if (chest) {
      final List<String> newIds = <String>[
        for (int number = 1; number <= 3; number++)
          '${workout.id}-$pushdown-set-$number-equipment-v2',
      ];
      if (workout.sets.any((WorkoutSet set) => newIds.contains(set.id))) {
        return workout;
      }
      return workout.copyWith(
        exerciseIds: <String>[
          for (final String id in workout.exerciseIds)
            id == cableFly ? dumbbellFly : id,
          pushdown,
        ],
        sets: <WorkoutSet>[
          for (final WorkoutSet set in workout.sets)
            if (set.exerciseId == cableFly)
              set.copyWith(exerciseId: dumbbellFly, targetWeightKg: null)
            else
              set,
          for (int number = 1; number <= 3; number++)
            WorkoutSet(
              id: newIds[number - 1],
              exerciseId: pushdown,
              setNumber: number,
              status: WorkoutSetStatus.planned,
              targetReps: 15,
              notes: _isolationNotes,
            ),
        ],
      );
    }
    return workout.copyWith(
      exerciseIds:
          workout.exerciseIds.where((String id) => id != walkout).toList(),
      sets: workout.sets
          .where((WorkoutSet set) => set.exerciseId != walkout)
          .toList(),
    );
  }
}
