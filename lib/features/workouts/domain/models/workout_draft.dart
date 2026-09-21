import '../services/for_time_timer.dart';
import 'conditioning.dart';

/// Raw set entries retained without turning an unfinished set into history.
class WorkoutSetProgress {
  /// Creates blank or entered values.
  const WorkoutSetProgress({this.weight = '', this.reps = ''});

  /// Entered weight, including partially typed values.
  final String weight;

  /// Entered repetitions.
  final String reps;

  /// Whether either field has an entry.
  bool get hasRecordedValues =>
      weight.trim().isNotEmpty || reps.trim().isNotEmpty;

  /// Replaces selected entries.
  WorkoutSetProgress copyWith({String? weight, String? reps}) =>
      WorkoutSetProgress(
          weight: weight ?? this.weight, reps: reps ?? this.reps);
}

/// Raw load and scaling entries for a prescribed conditioning movement.
class ConditioningMovementProgress {
  /// Creates blank or entered movement values.
  const ConditioningMovementProgress({
    this.load = '',
    this.implementCount = '',
    this.modification = '',
  });

  /// Entered per-implement load.
  final String load;

  /// Entered number of implements.
  final String implementCount;

  /// Entered movement modification.
  final String modification;

  /// Replaces selected entries.
  ConditioningMovementProgress copyWith({
    String? load,
    String? implementCount,
    String? modification,
  }) =>
      ConditioningMovementProgress(
        load: load ?? this.load,
        implementCount: implementCount ?? this.implementCount,
        modification: modification ?? this.modification,
      );
}

/// Conditioning entries and timestamp-based timer for an unfinished workout.
class WorkoutConditioningProgress {
  /// Creates blank or restored conditioning values.
  WorkoutConditioningProgress({
    this.rounds = '',
    this.additionalReps = '',
    this.minutes = '',
    this.seconds = '',
    this.hasManualTime = false,
    Map<String, ConditioningMovementProgress> movements =
        const <String, ConditioningMovementProgress>{},
    this.scaling = '',
    this.isCompleted = false,
    this.timer = const ForTimeTimer(),
  }) : movements = Map<String, ConditioningMovementProgress>.unmodifiable(
          movements,
        );

  /// Entered completed rounds.
  final String rounds;

  /// Entered repetitions after the final round.
  final String additionalReps;

  /// Editable elapsed minutes.
  final String minutes;

  /// Editable remaining seconds.
  final String seconds;

  /// User-edited time takes precedence until explicitly replaced by timer time.
  final bool hasManualTime;

  /// Entries keyed by stable movement ID.
  final Map<String, ConditioningMovementProgress> movements;

  /// Overall conditioning scaling.
  final String scaling;

  /// Whether the prescribed conditioning was completed.
  final bool isCompleted;

  /// Accumulated elapsed duration and optional running-start timestamp.
  final ForTimeTimer timer;

  /// Replaces selected entries.
  WorkoutConditioningProgress copyWith({
    String? rounds,
    String? additionalReps,
    String? minutes,
    String? seconds,
    bool? hasManualTime,
    Map<String, ConditioningMovementProgress>? movements,
    String? scaling,
    bool? isCompleted,
    ForTimeTimer? timer,
  }) =>
      WorkoutConditioningProgress(
        rounds: rounds ?? this.rounds,
        additionalReps: additionalReps ?? this.additionalReps,
        minutes: minutes ?? this.minutes,
        seconds: seconds ?? this.seconds,
        hasManualTime: hasManualTime ?? this.hasManualTime,
        movements: movements ?? this.movements,
        scaling: scaling ?? this.scaling,
        isCompleted: isCompleted ?? this.isCompleted,
        timer: timer ?? this.timer,
      );

  /// Stops the timer, updating editable time unless a manual correction exists.
  WorkoutConditioningProgress finishTimer(DateTime now) {
    final ForTimeTimer stopped = timer.finish(now);
    return copyWith(timer: stopped).withTimerTime();
  }

  /// Copies the timer duration to editable fields, respecting manual overrides.
  WorkoutConditioningProgress withTimerTime({bool replaceManual = false}) {
    if (hasManualTime && !replaceManual) return this;
    if (timer.elapsed == Duration.zero && !replaceManual) return this;
    return copyWith(
      minutes: timer.elapsed.inMinutes.toString(),
      seconds: timer.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0'),
      hasManualTime: false,
    );
  }

  /// Builds a completed result; callers must finalize a running timer first.
  ConditioningResult resultFor(ConditioningPlan plan) {
    final Duration enteredTime = Duration(
      minutes: int.tryParse(minutes) ?? 0,
      seconds: int.tryParse(seconds) ?? 0,
    );
    final Duration effectiveTime = hasManualTime ? enteredTime : timer.elapsed;
    return ConditioningResult(
      roundsCompleted: int.tryParse(rounds) ?? 0,
      additionalReps: int.tryParse(additionalReps) ?? 0,
      completionTime: effectiveTime == Duration.zero ? null : effectiveTime,
      movementResults: <ConditioningMovementResult>[
        for (final ConditioningMovement movement in plan.movements)
          ConditioningMovementResult(
            movementId: movement.id,
            actualLoad: double.tryParse(movements[movement.id]?.load ?? ''),
            implementCount:
                int.tryParse(movements[movement.id]?.implementCount ?? ''),
            modification:
                (movements[movement.id]?.modification ?? '').trim().isEmpty
                    ? null
                    : movements[movement.id]!.modification.trim(),
          ),
      ],
      scaling: scaling.trim().isEmpty ? null : scaling.trim(),
      isCompleted: isCompleted,
    );
  }
}

/// An active session snapshot stored separately from completed workout history.
class WorkoutDraft {
  /// Creates an empty or restored session.
  WorkoutDraft({
    required this.workoutId,
    Map<String, WorkoutSetProgress> sets = const <String, WorkoutSetProgress>{},
    WorkoutConditioningProgress? conditioning,
  })  : sets = Map<String, WorkoutSetProgress>.unmodifiable(sets),
        conditioning = conditioning ?? WorkoutConditioningProgress();

  /// Stable workout/session ID, never just the program workout name.
  final String workoutId;

  /// Strength entries keyed by set ID within this session.
  final Map<String, WorkoutSetProgress> sets;

  /// Conditioning entries and timer.
  final WorkoutConditioningProgress conditioning;

  /// Replaces one portion of the session snapshot.
  WorkoutDraft copyWith({
    Map<String, WorkoutSetProgress>? sets,
    WorkoutConditioningProgress? conditioning,
  }) =>
      WorkoutDraft(
        workoutId: workoutId,
        sets: sets ?? this.sets,
        conditioning: conditioning ?? this.conditioning,
      );
}
