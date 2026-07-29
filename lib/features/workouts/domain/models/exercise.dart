/// Broad classifications used to organise the exercise catalogue.
enum ExerciseCategory {
  /// Resistance or strength-focused movement.
  strength,

  /// Aerobic or cardiovascular movement.
  cardio,

  /// Mobility or flexibility-focused movement.
  mobility,

  /// Conditioning-focused movement.
  conditioning,

  /// A movement that does not fit another category.
  other,
}

/// The main muscle group trained by an exercise.
enum MuscleGroup {
  /// Chest musculature.
  chest,

  /// Back musculature.
  back,

  /// Shoulder musculature.
  shoulders,

  /// Arm musculature.
  arms,

  /// Abdominal and trunk musculature.
  core,

  /// Quadriceps, hamstrings, and calf musculature.
  legs,

  /// Gluteal musculature.
  glutes,

  /// Full-body movement.
  fullBody,
}

/// The primary equipment needed for an exercise.
enum Equipment {
  /// No external equipment is needed.
  bodyweight,

  /// A barbell is needed.
  barbell,

  /// Dumbbells are needed.
  dumbbells,

  /// A kettlebell is needed.
  kettlebell,

  /// A cable machine is needed.
  cableMachine,

  /// A selectorised or plate-loaded machine is needed.
  machine,

  /// A resistance band is needed.
  resistanceBand,

  /// Other or mixed equipment is needed.
  other,
}

/// A reusable entry in the user's exercise catalogue.
class Exercise {
  /// Creates an immutable exercise definition.
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.equipment,
    this.primaryMuscleGroup,
    this.instructions,
    this.notes,
    this.isArchived = false,
  });

  /// Stable, client-generated identifier for this exercise.
  final String id;

  /// Human-readable exercise name.
  final String name;

  /// Broad classification used for filtering and statistics.
  final ExerciseCategory category;

  /// Main muscle group trained, when one applies.
  final MuscleGroup? primaryMuscleGroup;

  /// Primary equipment required to perform the exercise.
  final Equipment equipment;

  /// Optional execution guidance for the exercise.
  final String? instructions;

  /// Optional personal notes that do not form part of the instructions.
  final String? notes;

  /// Whether the exercise is hidden from new plans while retained in history.
  final bool isArchived;

  static const Object _unset = Object();

  /// Returns this exercise with selected values replaced.
  ///
  /// Pass `null` to [primaryMuscleGroup], [instructions], or [notes] to clear it.
  Exercise copyWith({
    String? id,
    String? name,
    ExerciseCategory? category,
    Object? primaryMuscleGroup = _unset,
    Equipment? equipment,
    Object? instructions = _unset,
    Object? notes = _unset,
    bool? isArchived,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      primaryMuscleGroup: identical(primaryMuscleGroup, _unset)
          ? this.primaryMuscleGroup
          : primaryMuscleGroup as MuscleGroup?,
      equipment: equipment ?? this.equipment,
      instructions: identical(instructions, _unset)
          ? this.instructions
          : instructions as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Exercise &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.primaryMuscleGroup == primaryMuscleGroup &&
        other.equipment == equipment &&
        other.instructions == instructions &&
        other.notes == notes &&
        other.isArchived == isArchived;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        primaryMuscleGroup,
        equipment,
        instructions,
        notes,
        isArchived,
      );
}
