import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/for_time_timer.dart';

/// In-memory load and modification entered for one conditioning movement.
class ConditioningMovementProgress {
  /// Creates values for a prescribed conditioning movement.
  const ConditioningMovementProgress({
    this.load = '',
    this.implementCount = '',
    this.modification = '',
  });

  /// Entered per-implement load.
  final String load;

  /// Entered number of implements, when it differs from the prescription.
  final String implementCount;

  /// Entered scaling or modification.
  final String modification;

  /// Returns this movement draft with selected values replaced.
  ConditioningMovementProgress copyWith({
    String? load,
    String? implementCount,
    String? modification,
  }) {
    return ConditioningMovementProgress(
      load: load ?? this.load,
      implementCount: implementCount ?? this.implementCount,
      modification: modification ?? this.modification,
    );
  }
}

/// In-memory conditioning values entered while a CrossFit workout is active.
class WorkoutConditioningProgress {
  /// Creates blank or previously entered conditioning values.
  WorkoutConditioningProgress({
    this.rounds = '',
    this.additionalReps = '',
    this.minutes = '',
    this.seconds = '',
    Map<String, ConditioningMovementProgress> movements =
        const <String, ConditioningMovementProgress>{},
    this.scaling = '',
    this.isCompleted = false,
    this.timer = const ForTimeTimer(),
  }) : _movements = Map<String, ConditioningMovementProgress>.unmodifiable(
          movements,
        );

  /// Entered number of completed rounds.
  final String rounds;

  /// Entered repetitions after the final complete round.
  final String additionalReps;

  /// Entered elapsed whole minutes.
  final String minutes;

  /// Entered elapsed remaining seconds.
  final String seconds;

  final Map<String, ConditioningMovementProgress> _movements;

  /// Drafts keyed by prescribed conditioning-movement ID.
  Map<String, ConditioningMovementProgress> get movements => _movements;

  /// Entered movement scaling or modification.
  final String scaling;

  /// Whether the prescribed conditioning was fully completed.
  final bool isCompleted;

  /// Timestamp-based stopwatch state for For Time conditioning.
  final ForTimeTimer timer;

  /// Returns this draft with selected values replaced.
  WorkoutConditioningProgress copyWith({
    String? rounds,
    String? additionalReps,
    String? minutes,
    String? seconds,
    Map<String, ConditioningMovementProgress>? movements,
    String? scaling,
    bool? isCompleted,
    ForTimeTimer? timer,
  }) {
    return WorkoutConditioningProgress(
      rounds: rounds ?? this.rounds,
      additionalReps: additionalReps ?? this.additionalReps,
      minutes: minutes ?? this.minutes,
      seconds: seconds ?? this.seconds,
      movements: movements ?? _movements,
      scaling: scaling ?? this.scaling,
      isCompleted: isCompleted ?? this.isCompleted,
      timer: timer ?? this.timer,
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

  /// Updates the movement-specific draft within [workoutId]'s conditioning work.
  void updateMovement(
    String workoutId,
    String movementId,
    ConditioningMovementProgress progress,
  ) {
    final WorkoutConditioningProgress current =
        state[workoutId] ?? WorkoutConditioningProgress();
    update(
      workoutId,
      current.copyWith(
        movements: <String, ConditioningMovementProgress>{
          ...current.movements,
          movementId: progress,
        },
      ),
    );
  }

  /// Starts the timestamp-based For Time stopwatch for [workoutId].
  void startTimer(String workoutId, DateTime now) {
    final WorkoutConditioningProgress current =
        state[workoutId] ?? WorkoutConditioningProgress();
    update(workoutId, current.copyWith(timer: current.timer.start(now)));
  }

  /// Pauses the stopwatch and preserves its calculated elapsed time.
  void pauseTimer(String workoutId, DateTime now) {
    final WorkoutConditioningProgress current =
        state[workoutId] ?? WorkoutConditioningProgress();
    update(workoutId, current.copyWith(timer: current.timer.pause(now)));
  }

  /// Stops the stopwatch and writes its elapsed duration into editable fields.
  void finishTimer(String workoutId, DateTime now) {
    final WorkoutConditioningProgress current =
        state[workoutId] ?? WorkoutConditioningProgress();
    final ForTimeTimer timer = current.timer.finish(now);
    final Duration elapsed = timer.elapsed;
    update(
      workoutId,
      current.copyWith(
        timer: timer,
        minutes: elapsed.inMinutes.toString(),
        seconds: elapsed.inSeconds.remainder(60).toString().padLeft(2, '0'),
      ),
    );
  }

  /// Removes all session drafts after a workout has been started or finished.
  void clear() => state = <String, WorkoutConditioningProgress>{};
}
