/// How a habit's daily target is evaluated.
enum HabitTargetType {
  /// The habit is complete once it is marked done.
  completion,

  /// The habit is measured by a count or numeric quantity.
  quantity,

  /// The habit is measured by elapsed time.
  duration,
}

/// Unit used to interpret a habit target and future completion progress.
enum HabitUnit {
  /// No unit is necessary for a binary completion.
  none,

  /// Discrete repetitions or occurrences.
  count,

  /// Minutes of activity.
  minutes,

  /// Grams of a nutrient or substance.
  grams,

  /// Millilitres of fluid.
  millilitres,
}

/// Days of the week on which a recurring habit applies.
enum Weekday {
  /// Monday.
  monday,

  /// Tuesday.
  tuesday,

  /// Wednesday.
  wednesday,

  /// Thursday.
  thursday,

  /// Friday.
  friday,

  /// Saturday.
  saturday,

  /// Sunday.
  sunday,
}

/// A recurring personal target; it does not record daily completions.
class Habit {
  /// Creates an immutable habit definition.
  Habit({
    required this.id,
    required this.name,
    required this.targetType,
    required this.targetValue,
    required this.unit,
    Set<Weekday> activeDays = const <Weekday>{},
    this.isActive = true,
  }) : _activeDays = Set<Weekday>.unmodifiable(activeDays);

  /// Stable, client-generated identifier for this habit.
  final String id;

  /// Human-readable name of the habit.
  final String name;

  /// Strategy for interpreting the target.
  final HabitTargetType targetType;

  /// Numeric target for an active day.
  final double targetValue;

  /// Unit that gives [targetValue] meaning.
  final HabitUnit unit;

  /// Weekdays on which the habit applies.
  Set<Weekday> get activeDays => _activeDays;
  final Set<Weekday> _activeDays;

  /// Whether the habit is currently available for new check-ins.
  final bool isActive;

  /// Returns this habit with selected values replaced.
  ///
  /// The supplied [activeDays] are copied into an unmodifiable set.
  Habit copyWith({
    String? id,
    String? name,
    HabitTargetType? targetType,
    double? targetValue,
    HabitUnit? unit,
    Set<Weekday>? activeDays,
    bool? isActive,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      targetType: targetType ?? this.targetType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      activeDays: activeDays ?? _activeDays,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Habit &&
        other.id == id &&
        other.name == name &&
        other.targetType == targetType &&
        other.targetValue == targetValue &&
        other.unit == unit &&
        _setEquals(other._activeDays, _activeDays) &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        targetType,
        targetValue,
        unit,
        Object.hashAllUnordered(_activeDays),
        isActive,
      );
}

bool _setEquals<T>(Set<T> left, Set<T> right) {
  if (identical(left, right)) return true;
  return left.length == right.length && left.containsAll(right);
}
