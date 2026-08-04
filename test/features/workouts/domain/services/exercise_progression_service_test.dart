import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/services/exercise_progression_service.dart';

void main() {
  const ExerciseProgressionService service = ExerciseProgressionService();
  final RepRange range = service.repRangeFor(_plannedSet(1))!;

  test('first session does not invent a weight', () {
    final ExerciseProgressionGuidance guidance = service.suggest(
      programmedSets: <WorkoutSet>[_plannedSet(1), _plannedSet(2)],
      previousCompletedSets: const <WorkoutSet>[],
    );

    expect(guidance.status, ExerciseProgressionStatus.firstSession);
    expect(
      guidance.message,
      'First session — choose a comfortable starting weight.',
    );
    expect(guidance.setSuggestions.first.suggestedWeightKg, isNull);
  });

  test('classifies more reps at the same weight as improved by reps', () {
    final ExerciseProgressionStatus status = service.classify(
      currentCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 8),
        _completedSet(2, weightKg: 80, reps: 8),
        _completedSet(3, weightKg: 80, reps: 9),
      ],
      previousCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 8),
        _completedSet(2, weightKg: 80, reps: 8),
        _completedSet(3, weightKg: 80, reps: 8),
      ],
      repRange: range,
    );

    expect(status, ExerciseProgressionStatus.improvedByReps);
  });

  test('classifies higher weight inside range as improved by weight', () {
    final ExerciseProgressionStatus status = service.classify(
      currentCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 82.5, reps: 8),
      ],
      previousCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 10),
      ],
      repRange: range,
    );

    expect(status, ExerciseProgressionStatus.improvedByWeight);
  });

  test('classifies equal weight and reps as matched', () {
    final ExerciseProgressionStatus status = service.classify(
      currentCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 8),
      ],
      previousCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 8),
      ],
      repRange: range,
    );

    expect(status, ExerciseProgressionStatus.matched);
  });

  test('classifies fewer reps at the same weight as below previous', () {
    final ExerciseProgressionStatus status = service.classify(
      currentCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 7),
      ],
      previousCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 8),
      ],
      repRange: range,
    );

    expect(status, ExerciseProgressionStatus.belowPrevious);
    expect(
      service.nextStepFor(status),
      'Repeat the same weight and try to restore the previous reps.',
    );
  });

  test('reaching the top of the range recommends a small weight increase', () {
    final ExerciseProgressionGuidance guidance = service.suggest(
      programmedSets: <WorkoutSet>[
        _plannedSet(1),
        _plannedSet(2),
        _plannedSet(3),
      ],
      previousCompletedSets: <WorkoutSet>[
        _completedSet(1, weightKg: 80, reps: 10),
        _completedSet(2, weightKg: 80, reps: 10),
        _completedSet(3, weightKg: 80, reps: 10),
      ],
    );

    expect(guidance.message, contains('smallest available amount'));
    expect(guidance.message, contains('aim for 6–8 reps'));
    expect(
      guidance.setSuggestions.map(
        (SetProgressionSuggestion suggestion) => suggestion.targetReps,
      ),
      everyElement(equals(6)),
    );
    expect(
      guidance.setSuggestions.map(
        (SetProgressionSuggestion suggestion) => suggestion.suggestedWeightKg,
      ),
      everyElement(isNull),
    );
  });
}

WorkoutSet _plannedSet(int setNumber) {
  return WorkoutSet(
    id: 'planned-$setNumber',
    exerciseId: 'exercise',
    setNumber: setNumber,
    targetReps: 10,
    status: WorkoutSetStatus.planned,
    notes: 'Target 6–10 reps; rest 2 min',
  );
}

WorkoutSet _completedSet(
  int setNumber, {
  required double weightKg,
  required int reps,
}) {
  return WorkoutSet(
    id: 'completed-$setNumber-$weightKg-$reps',
    exerciseId: 'exercise',
    setNumber: setNumber,
    weightKg: weightKg,
    reps: reps,
    status: WorkoutSetStatus.completed,
    notes: 'Target 6–10 reps; rest 2 min',
  );
}
