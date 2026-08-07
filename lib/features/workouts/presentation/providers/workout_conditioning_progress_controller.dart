import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory conditioning values entered while a CrossFit workout is active.
class WorkoutConditioningProgress {
  /// Creates blank or previously entered conditioning values.
  const WorkoutConditioningProgress({
    this.rounds = '',
    this.additionalReps = '',
    this.minutes = '',
    this.seconds = '',
    this.weight = '',
    this.scaling = '',
    this.isCompleted = false,
  });

  /// Entered number of completed rounds.
  final String rounds;

  /// Entered repetitions after the final complete round.
  final String additionalReps;

  /// Entered elapsed whole minutes.
  final String minutes;

  /// Entered elapsed remaining seconds.
  final String seconds;

  /// Entered optional conditioning load.
  final String weight;

  /// Entered movement scaling or modification.
  final String scaling;

  /// Whether the prescribed conditioning was fully completed.
  final bool isCompleted;

  /// Returns this draft with selected values replaced.
  WorkoutConditioningProgress copyWith({
    String? rounds,
    String? additionalReps,
    String? minutes,
    String? seconds,
    String? weight,
    String? scaling,
    bool? isCompleted,
  }) {
    return WorkoutConditioningProgress(
      rounds: rounds ?? this.rounds,
      additionalReps: additionalReps ?? this.additionalReps,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      weight: weight ?? this.weight,
      scaling: scaling ?? this.scaling,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Owns per-workout conditioning drafts without persisting them prematurely.
final NotifierProvider<WorkoutConditioningProgressController,
        Map<String, WorkoutConditioningProgress>>
    workoutConditioningProgressControllerProvider = NotifierProvider<
        WorkoutConditioningProgressController,
        Map<String, WorkoutConditioningProgress>>(
  WorkoutConditioningProgressController.new,
);

/// Riverpod controller for CrossFit conditioning entry values.
class WorkoutConditioningProgressController
    extends Notifier<Map<String, WorkoutConditioningProgress>> {
  @override
  Map<String, WorkoutConditioningProgress> build() =>
      <String, WorkoutConditioningProgress>{};

  /// Replaces the draft for [workoutId].
  void update(String workoutId, WorkoutConditioningProgress progress) {
    state = <String, WorkoutConditioningProgress>{
      ...state,
      workoutId: progress
    };
  }

  /// Removes all session drafts after a workout has been started or finished.
  void clear() => state = <String, WorkoutConditioningProgress>{};
}
