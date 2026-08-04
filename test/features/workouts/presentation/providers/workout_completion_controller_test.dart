import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/repositories/workout_repository.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_completion_controller.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_set_progress_controller.dart';

void main() {
  test(
      'completing Legs B creates a new planned Push A without deleting history',
      () async {
    final List<Workout> initialWorkouts = WorkoutProgram.workoutNames
        .map(
          (String name) => Workout(
            id: name.toLowerCase().replaceAll(' ', '-'),
            name: name,
            scheduledDate: DateTime.utc(2026, 8, 5),
            status: name == 'Legs B'
                ? WorkoutStatus.planned
                : WorkoutStatus.completed,
            completedAt: name == 'Legs B' ? null : DateTime.utc(2026, 8, 4),
          ),
        )
        .toList(growable: false);
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      initialWorkouts,
    );
    final WorkoutCompletionController controller = WorkoutCompletionController(
      workoutRepository: repository,
      onWorkoutChanged: () {},
      clearSetProgress: () {},
      readSetProgress: () => <String, WorkoutSetProgress>{},
    );

    await controller.finishWorkout('legs-b');

    final List<Workout> workouts = await repository.getAll();
    final Workout completedLegsB = workouts.singleWhere(
      (Workout workout) => workout.id == 'legs-b',
    );
    final Workout nextPushA = workouts.singleWhere(
      (Workout workout) =>
          workout.name == 'Push A' && workout.status == WorkoutStatus.planned,
    );

    expect(completedLegsB.status, WorkoutStatus.completed);
    expect(
        workouts.where(
            (Workout workout) => workout.status == WorkoutStatus.completed),
        hasLength(6));
    expect(nextPushA.id, isNot('push-a'));
  });
}

class _MemoryWorkoutRepository implements WorkoutRepository {
  _MemoryWorkoutRepository(List<Workout> workouts)
      : _workouts = <String, Workout>{
          for (final Workout workout in workouts) workout.id: workout,
        };

  final Map<String, Workout> _workouts;

  @override
  Future<void> delete(String id) async {
    _workouts.remove(id);
  }

  @override
  Future<List<Workout>> getAll() async => _workouts.values.toList();

  @override
  Future<Workout?> getById(String id) async => _workouts[id];

  @override
  Future<List<Workout>> getForDate(DateTime date) async {
    return _workouts.values
        .where(
          (Workout workout) =>
              workout.scheduledDate.year == date.year &&
              workout.scheduledDate.month == date.month &&
              workout.scheduledDate.day == date.day,
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(Workout workout) async {
    _workouts[workout.id] = workout;
  }
}
