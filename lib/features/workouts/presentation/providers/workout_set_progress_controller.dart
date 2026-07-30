import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory values entered for one workout set during the focused workout flow.
class WorkoutSetProgress {
  /// Creates values for a workout set.
  const WorkoutSetProgress({
    this.weight = '',
    this.completedReps = '',
    this.isCompleted = false,
  });

  /// Entered weight value, retained as text until persistence is introduced.
  final String weight;

  /// Entered completed repetitions, retained as text until persistence is introduced.
  final String completedReps;

  /// Whether the user has marked this set complete.
  final bool isCompleted;

  /// Returns this progress with selected fields replaced.
  WorkoutSetProgress copyWith({
    String? weight,
    String? completedReps,
    bool? isCompleted,
  }) {
    return WorkoutSetProgress(
      weight: weight ?? this.weight,
      completedReps: completedReps ?? this.completedReps,
      isCompleted: isCompleted ?? this.isCompleted,
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

  /// Records completed repetitions for [setId].
  void updateCompletedReps(String setId, String completedReps) {
    _update(setId, _valueFor(setId).copyWith(completedReps: completedReps));
  }

  /// Marks [setId] as completed or incomplete.
  void updateCompletion(String setId, bool isCompleted) {
    _update(setId, _valueFor(setId).copyWith(isCompleted: isCompleted));
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
