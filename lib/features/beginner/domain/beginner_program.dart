/// A beginner movement with a simpler option.
class BeginnerExercise {
  /// Creates display guidance for one exercise.
  const BeginnerExercise(this.name, this.reps, this.cue, this.easier);

  /// Movement name.
  final String name;

  /// Comfortable repetition range.
  final String reps;

  /// Technique guidance.
  final String cue;

  /// A less demanding alternative.
  final String easier;
}

/// Repeatable full-body movement sequence.
const List<BeginnerExercise> beginnerExercises = <BeginnerExercise>[
  BeginnerExercise(
    'Chair sit-to-stand',
    '6–10 reps',
    'Use a stable chair against a wall. Stand tall, then sit slowly.',
    'Use your hands or a higher chair.',
  ),
  BeginnerExercise(
    'Wall push-up',
    '6–10 reps',
    'Hands at chest height. Keep your body straight and bend your elbows gently.',
    'Stand closer to the wall.',
  ),
  BeginnerExercise(
    'Supported dumbbell row',
    '6–10 reps each side',
    'Support one hand on a sturdy bench. Keep your back comfortable and pull a light weight toward your hip.',
    'Practise without a weight.',
  ),
  BeginnerExercise(
    'Glute bridge',
    '6–10 reps',
    'Lie on your back, knees bent. Gently lift your hips without arching your back.',
    'Use a smaller lift or squeeze your glutes without lifting.',
  ),
  BeginnerExercise(
    'Supported calf raise',
    '8–12 reps',
    'Hold a wall or stable support. Rise onto your toes, then lower slowly.',
    'Use a smaller range or seated heel raises.',
  ),
];
