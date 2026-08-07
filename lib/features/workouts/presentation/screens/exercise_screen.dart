import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../domain/models/conditioning.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/workout.dart';
import '../../domain/models/workout_set.dart';
import '../../domain/services/exercise_progression_service.dart';
import '../providers/today_workout_provider.dart';
import '../providers/workout_completion_controller.dart';
import '../providers/workout_conditioning_progress_controller.dart';
import '../providers/workout_history_provider.dart';
import '../providers/workout_progression_provider.dart';
import '../providers/workout_set_progress_controller.dart';

/// Focused set-entry screen for one exercise in the selected workout.
class ExerciseScreen extends ConsumerWidget {
  /// Creates an exercise screen for [exerciseIndex] in workout order.
  const ExerciseScreen({
    required this.workoutId,
    required this.exerciseIndex,
    super.key,
  });

  /// Stable identifier of the selected PPL or CrossFit workout session.
  final String workoutId;

  /// Zero-based position of the focused exercise in the workout.
  final int exerciseIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayWorkout?> todayWorkout = ref.watch(
      workoutSessionProvider(workoutId),
    );

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: todayWorkout.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) {
            return const Center(child: Text('Unable to load exercise.'));
          },
          data: (TodayWorkout? workoutData) {
            if (workoutData == null ||
                exerciseIndex < 0 ||
                exerciseIndex >= workoutData.exercises.length) {
              return const Center(child: Text('Exercise is not available.'));
            }
            final Exercise exercise = workoutData.exercises[exerciseIndex];
            final List<WorkoutSet> sets = workoutData.workout.sets
                .where((WorkoutSet set) => set.exerciseId == exercise.id)
                .toList(growable: false);
            return _ExerciseContent(
              exercise: exercise,
              sets: sets,
              exerciseIndex: exerciseIndex,
              exerciseCount: workoutData.exercises.length,
              workoutId: workoutId,
              workoutIsCompleted:
                  workoutData.workout.status == WorkoutStatus.completed,
              conditioningPlan: workoutData.workout.conditioningPlan,
            );
          },
        ),
      ),
    );
  }
}

class _ExerciseContent extends ConsumerWidget {
  const _ExerciseContent({
    required this.exercise,
    required this.sets,
    required this.exerciseIndex,
    required this.exerciseCount,
    required this.workoutId,
    required this.workoutIsCompleted,
    required this.conditioningPlan,
  });

  final Exercise exercise;
  final List<WorkoutSet> sets;
  final int exerciseIndex;
  final int exerciseCount;
  final String workoutId;
  final bool workoutIsCompleted;
  final ConditioningPlan? conditioningPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Map<String, WorkoutSetProgress> progress = ref.watch(
      workoutSetProgressControllerProvider,
    );
    final WorkoutSetProgressController controller = ref.read(
      workoutSetProgressControllerProvider.notifier,
    );
    final AsyncValue<PreviousExercisePerformance?> previousPerformance =
        ref.watch(previousExercisePerformanceProvider(exercise.id));
    final ExerciseProgressionService progressionService =
        const ExerciseProgressionService();
    final RepRange? repRange =
        sets.isEmpty ? null : progressionService.repRangeFor(sets.first);
    final String? restGuidance =
        sets.isEmpty ? null : progressionService.restGuidanceFor(sets.first);
    final AsyncValue<ExerciseProgressionGuidance?> guidance = ref.watch(
      exerciseProgressionGuidanceProvider(
        ExerciseProgressionRequest(
          workoutId: workoutId,
          exerciseId: exercise.id,
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(exercise.name, style: Theme.of(context).textTheme.headlineSmall),
          if (repRange != null || restGuidance != null)
            Text(
              <String>[
                if (repRange != null) '${repRange.display} reps',
                if (restGuidance != null) restGuidance,
              ].join(' • '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          previousPerformance.when(
            loading: () => const SizedBox.shrink(),
            error: (Object error, StackTrace stackTrace) {
              return const Text('No previous workout.');
            },
            data: (PreviousExercisePerformance? performance) {
              if (performance == null) {
                return const Text('No previous workout.');
              }
              return _PreviousPerformanceCard(performance: performance);
            },
          ),
          const SizedBox(height: 8),
          guidance.when(
            loading: () => const SizedBox.shrink(),
            error: (Object error, StackTrace stackTrace) {
              return const SizedBox.shrink();
            },
            data: (ExerciseProgressionGuidance? value) {
              if (value == null) return const SizedBox.shrink();
              return _SuggestedTodayCard(guidance: value);
            },
          ),
          const SizedBox(height: 8),
          for (final WorkoutSet set in sets) ...<Widget>[
            _SetEntryCard(
              set: set,
              repRange: progressionService.repRangeFor(set)?.display,
              progress: progress[set.id] ?? const WorkoutSetProgress(),
              onWeightChanged: (String weight) {
                controller.updateWeight(set.id, weight);
              },
              onRepsChanged: (String reps) {
                controller.updateReps(set.id, reps);
              },
            ),
            const SizedBox(height: 8),
          ],
          if (exerciseIndex == exerciseCount - 1 && conditioningPlan != null)
            _ConditioningEntryCard(
              workoutId: workoutId,
              plan: conditioningPlan!,
            ),
          if (exerciseIndex == exerciseCount - 1 && conditioningPlan != null)
            const SizedBox(height: 12),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('previous-exercise-button'),
                  onPressed: exerciseIndex == 0
                      ? null
                      : () => _replaceExercise(context, exerciseIndex - 1),
                  child: const Text('Previous Exercise'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('next-exercise-button'),
                  onPressed: exerciseIndex == exerciseCount - 1
                      ? null
                      : () => _replaceExercise(context, exerciseIndex + 1),
                  child: const Text('Next Exercise'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (exerciseIndex == exerciseCount - 1 &&
              !workoutIsCompleted) ...<Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('finish-workout-button'),
                onPressed: () async {
                  final WorkoutConditioningProgress conditioningProgress =
                      ref.read(workoutConditioningProgressControllerProvider)[
                              workoutId] ??
                          WorkoutConditioningProgress();
                  if (conditioningProgress.timer.isRunning &&
                      !await _confirmFinishWhileTimerRuns(context)) {
                    return;
                  }
                  try {
                    final Workout? completedWorkout = await ref
                        .read(workoutCompletionControllerProvider)
                        .finishWorkout(
                          workoutId,
                          conditioningResult: _conditioningResult(ref),
                        );
                    if (!context.mounted || completedWorkout == null) return;
                    context.goNamed(
                      AppRoute.workoutSummary.name,
                      pathParameters: <String, String>{'id': workoutId},
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Unable to save this workout. Please try again.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Finish Workout'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: context.pop,
              child: const Text('Back to Workout Overview'),
            ),
          ),
        ],
      ),
    );
  }

  void _replaceExercise(BuildContext context, int index) {
    context.pushReplacementNamed(
      AppRoute.exercise.name,
      pathParameters: <String, String>{
        'id': workoutId,
        'index': '$index',
      },
    );
  }

  ConditioningResult? _conditioningResult(WidgetRef ref) {
    if (conditioningPlan == null) return null;
    final WorkoutConditioningProgress progress = ref.read(
          workoutConditioningProgressControllerProvider,
        )[workoutId] ??
        WorkoutConditioningProgress();
    final int minutes = int.tryParse(progress.minutes) ?? 0;
    final int seconds = int.tryParse(progress.seconds) ?? 0;
    final Duration? completionTime = minutes == 0 && seconds == 0
        ? null
        : Duration(minutes: minutes, seconds: seconds);
    return ConditioningResult(
      roundsCompleted: int.tryParse(progress.rounds) ?? 0,
      additionalReps: int.tryParse(progress.additionalReps) ?? 0,
      completionTime: completionTime,
      movementResults: <ConditioningMovementResult>[
        for (final ConditioningMovement movement in conditioningPlan!.movements)
          ConditioningMovementResult(
            movementId: movement.id,
            actualLoad:
                double.tryParse(progress.movements[movement.id]?.load ?? ''),
            implementCount: int.tryParse(
              progress.movements[movement.id]?.implementCount ?? '',
            ),
            modification: (progress.movements[movement.id]?.modification ?? '')
                    .trim()
                    .isEmpty
                ? null
                : progress.movements[movement.id]!.modification.trim(),
          ),
      ],
      scaling: progress.scaling.trim().isEmpty ? null : progress.scaling.trim(),
      isCompleted: progress.isCompleted,
    );
  }

  Future<bool> _confirmFinishWhileTimerRuns(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Conditioning is still active'),
            content: const Text(
              'Finish Conditioning before finishing the workout, or confirm '
              'that you want to finish the workout now.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep logging'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Finish workout'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _ConditioningEntryCard extends ConsumerStatefulWidget {
  const _ConditioningEntryCard({required this.workoutId, required this.plan});

  final String workoutId;
  final ConditioningPlan plan;

  @override
  ConsumerState<_ConditioningEntryCard> createState() =>
      _ConditioningEntryCardState();
}

class _ConditioningEntryCardState
    extends ConsumerState<_ConditioningEntryCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkoutConditioningProgress progress = ref.watch(
          workoutConditioningProgressControllerProvider,
        )[widget.workoutId] ??
        WorkoutConditioningProgress();
    final WorkoutConditioningProgressController controller = ref.read(
      workoutConditioningProgressControllerProvider.notifier,
    );
    void update(WorkoutConditioningProgress value) =>
        controller.update(widget.workoutId, value);
    final bool isForTime =
        widget.plan.format == ConditioningFormat.roundsForTime;
    final Duration elapsed = progress.timer.elapsedAt(DateTime.now());
    final AsyncValue<Workout?> previous = ref.watch(
      previousCrossFitConditioningProvider(widget.workoutId),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Conditioning',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(widget.plan.title),
            const SizedBox(height: 4),
            Text(widget.plan.instructions,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            previous.when(
              loading: () => const SizedBox.shrink(),
              error: (Object error, StackTrace stackTrace) =>
                  const SizedBox.shrink(),
              data: (Workout? workout) => workout == null
                  ? const SizedBox.shrink()
                  : _PreviousConditioningCard(
                      workout: workout,
                      plan: widget.plan,
                    ),
            ),
            if (isForTime) ...<Widget>[
              Center(
                child: Text(
                  _durationLabel(elapsed),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (progress.timer.isRunning) {
                      controller.pauseTimer(widget.workoutId, DateTime.now());
                    } else if (progress.timer.elapsed == Duration.zero) {
                      controller.startTimer(widget.workoutId, DateTime.now());
                    } else {
                      controller.startTimer(widget.workoutId, DateTime.now());
                    }
                  },
                  child: Text(progress.timer.isRunning
                      ? 'Pause'
                      : progress.timer.elapsed == Duration.zero
                          ? 'Start Conditioning'
                          : 'Resume'),
                ),
              ),
              if (progress.timer.isRunning ||
                  progress.timer.elapsed > Duration.zero)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => controller.finishTimer(
                        widget.workoutId,
                        DateTime.now(),
                      ),
                      child: const Text('Finish Conditioning'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (widget.plan.prescribedRounds != null)
              Text('Target: ${widget.plan.prescribedRounds} rounds'),
            for (final ConditioningMovement movement in widget.plan.movements)
              _MovementEntryCard(
                movement: movement,
                progress: progress.movements[movement.id] ??
                    const ConditioningMovementProgress(),
                onChanged: (ConditioningMovementProgress value) {
                  controller.updateMovement(
                      widget.workoutId, movement.id, value);
                },
              ),
            Row(
              children: <Widget>[
                Expanded(
                    child: _ConditioningField(
                        label: 'Rounds',
                        value: progress.rounds,
                        onChanged: (String value) =>
                            update(progress.copyWith(rounds: value)))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ConditioningField(
                        label: 'Extra reps',
                        value: progress.additionalReps,
                        onChanged: (String value) =>
                            update(progress.copyWith(additionalReps: value)))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                    child: _ConditioningField(
                        label: 'Minutes',
                        value: progress.minutes,
                        onChanged: (String value) =>
                            update(progress.copyWith(minutes: value)))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ConditioningField(
                        label: 'Seconds',
                        value: progress.seconds,
                        onChanged: (String value) =>
                            update(progress.copyWith(seconds: value)))),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Conditioning completed'),
              value: progress.isCompleted,
              onChanged: (bool? value) =>
                  update(progress.copyWith(isCompleted: value ?? false)),
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(Duration duration) {
    return '${duration.inMinutes.toString().padLeft(2, '0')}:'
        '${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

class _PreviousConditioningCard extends StatelessWidget {
  const _PreviousConditioningCard({required this.workout, required this.plan});

  final Workout workout;
  final ConditioningPlan plan;

  @override
  Widget build(BuildContext context) {
    final ConditioningResult result = workout.conditioningResult!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Last ${workout.name}'),
            Text(_resultLabel(result)),
            for (final ConditioningMovement movement in plan.movements)
              Text(_movementLabel(movement, result)),
            if (result.scaling != null) Text(result.scaling!),
          ],
        ),
      ),
    );
  }

  String _resultLabel(ConditioningResult result) {
    final String time = result.completionTime == null
        ? ''
        : ' — ${result.completionTime!.inMinutes}:'
            '${result.completionTime!.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return '${result.roundsCompleted} rounds$time';
  }

  String _movementLabel(
    ConditioningMovement movement,
    ConditioningResult result,
  ) {
    ConditioningMovementResult? recorded;
    for (final ConditioningMovementResult value in result.movementResults) {
      if (value.movementId == movement.id) {
        recorded = value;
        break;
      }
    }
    if (recorded?.actualLoad != null) {
      final int count = recorded?.implementCount ?? movement.implementCount;
      final String prefix = count > 1 ? '$count × ' : '';
      return '${movement.name}: $prefix${recorded!.actualLoad!.toStringAsFixed(0)} kg';
    }
    return '${movement.name}: '
        '${movement.isBodyweight ? 'Bodyweight' : 'No load recorded'}';
  }
}

class _MovementEntryCard extends StatelessWidget {
  const _MovementEntryCard({
    required this.movement,
    required this.progress,
    required this.onChanged,
  });

  final ConditioningMovement movement;
  final ConditioningMovementProgress progress;
  final ValueChanged<ConditioningMovementProgress> onChanged;

  @override
  Widget build(BuildContext context) {
    final String target = movement.prescribedReps != null
        ? '${movement.prescribedReps} reps'
        : '${movement.prescribedDistance?.toStringAsFixed(0) ?? ''} '
            '${movement.distanceUnit == DistanceUnit.metres ? 'm' : 'km'}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(movement.name, style: Theme.of(context).textTheme.titleSmall),
          Text(movement.isBodyweight ? '$target • Bodyweight' : target),
          if (!movement.isBodyweight)
            Row(
              children: <Widget>[
                Expanded(
                    child: _ConditioningField(
                        label: 'Weight kg',
                        value: progress.load,
                        decimal: true,
                        onChanged: (String value) =>
                            onChanged(progress.copyWith(load: value)))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ConditioningField(
                        label: 'Dumbbells / implements',
                        value: progress.implementCount,
                        onChanged: (String value) => onChanged(
                            progress.copyWith(implementCount: value)))),
              ],
            ),
          TextFormField(
            initialValue: progress.modification,
            decoration: const InputDecoration(
                labelText: 'Modification (optional)', isDense: true),
            onChanged: (String value) =>
                onChanged(progress.copyWith(modification: value)),
          ),
        ],
      ),
    );
  }
}

class _ConditioningField extends StatelessWidget {
  const _ConditioningField(
      {required this.label,
      required this.value,
      required this.onChanged,
      this.decimal = false});

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: onChanged,
    );
  }
}

class _PreviousPerformanceCard extends StatelessWidget {
  const _PreviousPerformanceCard({required this.performance});

  final PreviousExercisePerformance performance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Last time'),
            const SizedBox(height: 4),
            for (final WorkoutSet set in performance.sets) Text(_setLabel(set)),
            const SizedBox(height: 4),
            const Text('Let\'s beat that 💪'),
          ],
        ),
      ),
    );
  }

  String _setLabel(WorkoutSet set) {
    final String weight = set.weightKg?.toStringAsFixed(0) ?? '—';
    final String reps = set.reps?.toString() ?? '—';
    return '$weight kg × $reps reps';
  }
}

class _SuggestedTodayCard extends StatelessWidget {
  const _SuggestedTodayCard({required this.guidance});

  final ExerciseProgressionGuidance guidance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Suggested today'),
            const SizedBox(height: 4),
            Text(guidance.message),
            const SizedBox(height: 4),
            for (final SetProgressionSuggestion suggestion
                in guidance.setSuggestions)
              Text(_suggestionLabel(suggestion)),
          ],
        ),
      ),
    );
  }

  String _suggestionLabel(SetProgressionSuggestion suggestion) {
    final String reps = suggestion.targetReps == null
        ? 'Use a comfortable rep target'
        : '${suggestion.targetReps} reps';
    final String weight = suggestion.suggestedWeightKg == null
        ? ''
        : '${suggestion.suggestedWeightKg!.toStringAsFixed(0)} kg × ';
    return 'Set ${suggestion.setNumber}: $weight$reps';
  }
}

class _SetEntryCard extends StatelessWidget {
  const _SetEntryCard({
    required this.set,
    required this.repRange,
    required this.progress,
    required this.onWeightChanged,
    required this.onRepsChanged,
  });

  final WorkoutSet set;
  final String? repRange;
  final WorkoutSetProgress progress;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onRepsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Set ${set.setNumber}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('weight-${set.id}'),
                    initialValue: progress.weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Weight',
                      isDense: true,
                    ),
                    onChanged: onWeightChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('reps-${set.id}'),
                    initialValue: progress.reps,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Reps',
                      hintText: repRange,
                      isDense: true,
                    ),
                    onChanged: onRepsChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
