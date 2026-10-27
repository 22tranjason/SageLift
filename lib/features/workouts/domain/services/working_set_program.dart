import '../models/workout.dart';
import '../models/workout_set.dart';
import 'equipment_program_update.dart';

/// Current working-set defaults, including recognised earlier four-day plans.
/// Matching prescriptions protects customised plans and all performed records.
class WorkingSetProgram {
  WorkingSetProgram._();

  static const String _warmUp =
      '8–10 min: easy walking and joint mobility, then 2–4 gradual ramp-up sets for the first lift; add light preparation sets before the next compound lift. Warm-ups are not working sets. Keep a controlled technique; no maximal attempts. When every working set reaches the top of its range with 2–3 reps in reserve, add the smallest available weight next time. Reduce load or sets if recovery or technique suffers; fatigue is not the goal.';
  static const String _prefix = 'seed-exercise-';
  static const String _oldCurl = '${_prefix}alternating-dumbbell-curl';
  static const String _curl = '${_prefix}ez-bar-curl';
  static const _Prescription _walkout = _Prescription(
    'bodyweight-hamstring-walkout',
    10,
    '6–10',
    '90',
    3,
    3,
    notes:
        'Target 6–10 reps; each controlled heel walk out and back is one rep. Keep hips comfortably raised; use a short range initially. Rest 90 sec; leave 2–3 reps in reserve; no mandatory failure.',
  );
  static const Map<String, List<_Prescription>> _profiles =
      <String, List<_Prescription>>{
    'Chest + Triceps': <_Prescription>[
      _Prescription('barbell-bench-press', 6, '4–6', '180', 4, 3),
      _Prescription('incline-dumbbell-press', 10, '8–10', '120', 3, 3),
      _Prescription('dumbbell-fly', 15, '10–15', '75', 3, 3),
      _Prescription(
          'overhead-dumbbell-triceps-extension', 15, '10–15', '75', 3, 3),
      _Prescription('cable-triceps-pushdown', 15, '10–15', '75', 3, 3),
    ],
    'Back + Biceps': <_Prescription>[
      _Prescription('barbell-bent-over-row', 8, '6–8', '150–180', 4, 3),
      _Prescription('cable-lat-pulldown', 12, '8–12', '120', 3, 3),
      _Prescription('chest-supported-dumbbell-row', 12, '8–12', '120', 3, 2),
      _Prescription('ez-bar-curl', 12, '8–12', '75', 3, 3),
      _Prescription('dumbbell-hammer-curl', 15, '10–15', '75', 3, 2),
    ],
    'Shoulders + Traps': <_Prescription>[
      _Prescription('standing-barbell-overhead-press', 6, '4–6', '180', 4, 3),
      _Prescription('dumbbell-lateral-raise', 15, '12–15', '75', 3, 3),
      _Prescription('dumbbell-rear-delt-fly', 15, '12–15', '75', 3, 3),
      _Prescription('dumbbell-shrug', 15, '10–15', '90', 3, 3),
    ],
    'Legs + Calves': <_Prescription>[
      _Prescription('barbell-back-squat', 6, '4–6', '180', 4, 3),
      _Prescription('romanian-deadlift', 10, '6–10', '150–180', 3, 3),
      _Prescription('dumbbell-reverse-lunge', 12, '8–12', '120', 3, 2,
          notes:
              'Target 8–12 reps per leg; rest 120 sec; leave 2–3 reps in reserve; no mandatory failure.'),
      _Prescription('standing-dumbbell-calf-raise', 15, '10–15', '90', 4, 4),
    ],
  };

  static String _currentId(String id) => id == EquipmentProgramUpdate.cableFly
      ? EquipmentProgramUpdate.dumbbellFly
      : id == _oldCurl
          ? _curl
          : id;

  /// Upgrades only clean recognised plans; callers also protect saved drafts.
  /// Future historical clones call this after clearing performed values.
  static Workout migrateUnstarted(Workout workout) {
    final List<_Prescription>? profile = _profiles[workout.name];
    if (profile == null ||
        workout.track != WorkoutTrack.hybrid ||
        workout.status != WorkoutStatus.planned ||
        workout.startedAt != null ||
        workout.completedAt != null ||
        workout.notes != null ||
        workout.warmUp != _warmUp ||
        workout.sessionDurationTarget !=
            (workout.name == 'Legs + Calves'
                ? 'About 65–75 min including warm-up'
                : 'About 50–60 min including warm-up') ||
        workout.sets.any((WorkoutSet s) =>
            s.status != WorkoutSetStatus.planned ||
            s.weightKg != null ||
            s.reps != null ||
            s.rpe != null) ||
        workout.sets.map((WorkoutSet s) => s.id).toSet().length !=
            workout.sets.length) {
      return workout;
    }
    final List<String> targetIds =
        profile.map((_Prescription p) => p.id).toList();
    final List<String> ids = workout.exerciseIds.map(_currentId).toList();
    final bool oldChest = workout.name == 'Chest + Triceps' &&
        workout.exerciseIds.contains(EquipmentProgramUpdate.cableFly) &&
        ids.join('|') == targetIds.take(4).join('|');
    final List<String> oldLegIds = <String>[
      ...targetIds.take(3),
      EquipmentProgramUpdate.walkout,
      targetIds.last,
    ];
    final bool oldLegs =
        workout.name == 'Legs + Calves' && ids.join('|') == oldLegIds.join('|');
    if (ids.join('|') != targetIds.join('|') && !oldChest && !oldLegs) {
      return workout;
    }
    final Map<String, List<WorkoutSet>> byId = <String, List<WorkoutSet>>{};
    for (final String originalId in workout.exerciseIds) {
      final String id = _currentId(originalId);
      final _Prescription p = id == EquipmentProgramUpdate.walkout
          ? _walkout
          : profile.firstWhere((_Prescription p) => p.id == id);
      final List<WorkoutSet> sets = workout.sets
          .where((WorkoutSet s) => s.exerciseId == originalId)
          .toList();
      if (sets.length < p.oldMinimum ||
          sets.length > p.count ||
          sets.map((WorkoutSet s) => s.setNumber).toSet().length !=
              sets.length ||
          sets.any((WorkoutSet s) =>
              s.setNumber < 1 ||
              s.setNumber > sets.length ||
              s.targetReps != p.reps ||
              s.notes != p.notes)) {
        return workout;
      }
      byId[id] = sets;
    }
    if (byId.values.fold<int>(
            0, (int total, List<WorkoutSet> sets) => total + sets.length) !=
        workout.sets.length) {
      return workout;
    }
    if (workout.exerciseIds.join('|') == targetIds.join('|') &&
        profile.every((_Prescription p) => byId[p.id]?.length == p.count)) {
      return workout;
    }
    final List<WorkoutSet> updated = <WorkoutSet>[
      for (final _Prescription p in profile) ...<WorkoutSet>[
        for (final WorkoutSet set in byId[p.id] ?? <WorkoutSet>[])
          if (set.exerciseId == p.id)
            set
          else
            set.copyWith(exerciseId: p.id, targetWeightKg: null),
        for (int number = (byId[p.id]?.length ?? 0) + 1;
            number <= p.count;
            number++)
          WorkoutSet(
            id: '${workout.id}-${p.id}-set-$number-working-sets-v3',
            exerciseId: p.id,
            setNumber: number,
            targetReps: p.reps,
            targetWeightKg: byId[p.id]?.first.exerciseId == p.id
                ? byId[p.id]?.first.targetWeightKg
                : null,
            notes: p.notes,
            status: WorkoutSetStatus.planned,
          ),
      ],
    ];
    if (updated.map((WorkoutSet s) => s.id).toSet().length != updated.length) {
      return workout;
    }
    return workout.copyWith(exerciseIds: targetIds, sets: updated);
  }
}

class _Prescription {
  const _Prescription(
      this.name, this.reps, this.range, this.rest, this.count, this.oldMinimum,
      {String? notes})
      : _notes = notes;
  final String name;
  final int reps;
  final String range;
  final String rest;
  final int count;
  final int oldMinimum;
  final String? _notes;
  String get id => 'seed-exercise-$name';
  String get notes =>
      _notes ??
      'Target $range reps; rest $rest sec; leave 2–3 reps in reserve; no mandatory failure.';
}
