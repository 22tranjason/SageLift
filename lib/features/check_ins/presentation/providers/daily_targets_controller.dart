import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory values entered for today's daily targets.
class DailyTargets {
  /// Creates immutable values for the current day's targets.
  DailyTargets({
    this.proteinGrams = 0,
    this.waterMillilitres = 0,
    this.steps = 0,
    List<DailyHabitProgress> habits = const <DailyHabitProgress>[],
  }) : _habits = List<DailyHabitProgress>.unmodifiable(habits);

  /// Protein entered for the current day, in grams.
  final double proteinGrams;

  /// Water entered for the current day, in millilitres.
  final double waterMillilitres;

  /// Manually entered steps until a health integration is available.
  final int steps;

  final List<DailyHabitProgress> _habits;

  /// Today's available habits and their in-memory completion state.
  List<DailyHabitProgress> get habits => _habits;

  /// Returns this state with selected values replaced.
  DailyTargets copyWith({
    double? proteinGrams,
    double? waterMillilitres,
    int? steps,
    List<DailyHabitProgress>? habits,
  }) {
    return DailyTargets(
      proteinGrams: proteinGrams ?? this.proteinGrams,
      waterMillilitres: waterMillilitres ?? this.waterMillilitres,
      steps: steps ?? this.steps,
      habits: habits ?? _habits,
    );
  }
}

/// One habit displayed in today's in-memory target list.
class DailyHabitProgress {
  /// Creates a habit completion value for today.
  const DailyHabitProgress({
    required this.id,
    required this.name,
    this.isCompleted = false,
  });

  /// Stable identifier from the eventual habit source.
  final String id;

  /// Display name of the habit.
  final String name;

  /// Whether the user has marked this habit complete today.
  final bool isCompleted;

  /// Returns this habit with a new completion state.
  DailyHabitProgress copyWith({bool? isCompleted}) {
    return DailyHabitProgress(
      id: id,
      name: name,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Owns locally entered daily targets until check-in persistence is added.
final NotifierProvider<DailyTargetsController, DailyTargets>
    dailyTargetsControllerProvider =
    NotifierProvider<DailyTargetsController, DailyTargets>(
  DailyTargetsController.new,
);

/// Updates today's local targets without a backend dependency.
class DailyTargetsController extends Notifier<DailyTargets> {
  @override
  DailyTargets build() => DailyTargets();

  /// Adds [grams] of protein to today's total.
  void addProtein(double grams) {
    if (grams <= 0) return;
    state = state.copyWith(proteinGrams: state.proteinGrams + grams);
  }

  /// Adds [millilitres] of water to today's total.
  void addWater(double millilitres) {
    if (millilitres <= 0) return;
    state = state.copyWith(
      waterMillilitres: state.waterMillilitres + millilitres,
    );
  }

  /// Replaces the manually entered step count for today.
  void setSteps(int steps) {
    if (steps < 0) return;
    state = state.copyWith(steps: steps);
  }

  /// Supplies habits that apply today when a habit source becomes available.
  void setHabits(List<DailyHabitProgress> habits) {
    state = state.copyWith(habits: habits);
  }

  /// Toggles the completion state of the habit identified by [habitId].
  void toggleHabit(String habitId) {
    state = state.copyWith(
      habits: state.habits
          .map(
            (DailyHabitProgress habit) => habit.id == habitId
                ? habit.copyWith(isCompleted: !habit.isCompleted)
                : habit,
          )
          .toList(growable: false),
    );
  }
}
