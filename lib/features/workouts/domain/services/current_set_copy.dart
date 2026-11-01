import '../models/workout_draft.dart';
import '../models/workout_set.dart';

/// Resolves copyable input from the immediately preceding current-session set.
class CurrentSetCopy {
  CurrentSetCopy._();

  /// Returns actual current input only; never reads previous workout history.
  static WorkoutSetProgress? source(WorkoutSet target, List<WorkoutSet> sets,
      Map<String, WorkoutSetProgress> entries) {
    final List<WorkoutSet> above = sets
        .where((WorkoutSet s) =>
            s.exerciseId == target.exerciseId &&
            s.setNumber == target.setNumber - 1)
        .toList();
    if (above.length != 1) return null;
    final WorkoutSet set = above.single;
    final WorkoutSetProgress? draft = entries[set.id];
    final String weight = draft?.weight ??
        set.weightKg?.toString().replaceFirst(RegExp(r'\.0$'), '') ??
        '';
    final String reps = draft?.reps ?? set.reps?.toString() ?? '';
    final double? parsedWeight = double.tryParse(weight.trim());
    final int? parsedReps = int.tryParse(reps.trim());
    final String validWeight =
        parsedWeight != null && parsedWeight.isFinite && parsedWeight >= 0
            ? weight
            : '';
    final String validReps = parsedReps != null && parsedReps >= 0 ? reps : '';
    if (validWeight.isEmpty && validReps.isEmpty) return null;
    return WorkoutSetProgress(weight: validWeight, reps: validReps);
  }
}
