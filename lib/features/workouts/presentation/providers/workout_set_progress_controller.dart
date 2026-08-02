import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory values entered for one workout set during the focused workout flow.
class WorkoutSetProgress {
  /// Creates values for a workout set.
  const WorkoutSetProgress({
    this.weight = '',
    this.reps = '',
  });

  /// Entered weight value, retained as text until persistence is introduced.
  final String weight;

  /// Entered repetitions, retained as text until persistence is introduced.
  final String reps;

  /// Whether at least one performance value has been entered for this set.
  bool get hasRecordedValues =>
      weight.trim().isNotEmpty || reps.trim().isNotEmpty;

  /// Returns this progress with selected fields replaced.
  WorkoutSetProgress copyWith({
    String? weight,
    String? reps,
  }) {
    return WorkoutSetProgress(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
    );
  }
}

/// Owns in-memory set entries while the user navigates a workout's exercises.
final NotifierProvider<WorkoutSetProgressController,
        Map<String, WorkoutSetProgress>> workoutSetProgressControllerProvider =
    NotifierProvider<WorkoutSetProgressController,
        Map<String, WorkoutSetProgress>>(
  WorkoutSetProgressController.new,
);

/// Riverpod controller for temporary workout-set entry state.
class WorkoutSetProgressController
    extends Notifier<Map<String, WorkoutSetProgress>> {
  @override
  Map<String, WorkoutSetProgress> build() => <String, WorkoutSetProgress>{};

  /// Records an entered [weight] for [setId].
  void updateWeight(String setId, String weight) {
    _update(setId, _valueFor(setId).copyWith(weight: weight));
  }

  /// Records entered repetitions for [setId].
  void updateReps(String setId, String reps) {
    _update(setId, _valueFor(setId).copyWith(reps: reps));
  }

  /// Removes entries from the previously active workout.
  void clear() {
    state = <String, WorkoutSetProgress>{};
  }

  WorkoutSetProgress _valueFor(String setId) {
    return state[setId] ?? const WorkoutSetProgress();
  }

  void _update(String setId, WorkoutSetProgress progress) {
    state = <String, WorkoutSetProgress>{...state, setId: progress};
  }
}
