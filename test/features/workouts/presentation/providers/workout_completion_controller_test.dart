import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/features/workouts/domain/models/workout.dart';
import 'package:sagelift/features/workouts/domain/models/workout_draft.dart';
import 'package:sagelift/features/workouts/domain/models/workout_set.dart';
import 'package:sagelift/features/workouts/domain/repositories/workout_repository.dart';
import 'package:sagelift/features/workouts/domain/services/workout_program.dart';
import 'package:sagelift/features/workouts/presentation/providers/workout_completion_controller.dart';

void main() {
  test('completion persists through a separate repository read', () async {
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[_workout('Back + Biceps', WorkoutStatus.inProgress)],
    );
    final WorkoutCompletionController controller = _controller(repository);

    final Workout? completed = await controller.finishWorkout('back-+-biceps');

    expect(completed?.status, WorkoutStatus.completed);
    expect((await repository.getById('back-+-biceps'))?.completedAt, isNotNull);
    expect((await repository.getById('back-+-biceps'))?.name, 'Back + Biceps');
  });

  test('duplicate Finish taps create one completion', () async {
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[_workout('Chest + Triceps', WorkoutStatus.inProgress)],
    );
    final WorkoutCompletionController controller = _controller(repository);

    final List<Workout?> results =
        await Future.wait<Workout?>(<Future<Workout?>>[
      controller.finishWorkout('chest-+-triceps'),
      controller.finishWorkout('chest-+-triceps'),
    ]);

    expect(results.whereType<Workout>(), hasLength(1));
    expect(repository.completedSaveCount, 1);
  });

  test('failed save does not report a successful completion', () async {
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[_workout('Chest + Triceps', WorkoutStatus.inProgress)],
      failCompletedSaves: true,
    );
    final WorkoutCompletionController controller = _controller(repository);

    await expectLater(
      controller.finishWorkout('chest-+-triceps'),
      throwsStateError,
    );

    expect(
      (await repository.getById('chest-+-triceps'))?.status,
      WorkoutStatus.inProgress,
    );
  });

  test(
    'Finish retries failed cleanup without rewriting completed history',
    () async {
      final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
        <Workout>[_workout('Chest + Triceps', WorkoutStatus.inProgress)],
      );
      bool failCleanup = true;
      int removed = 0;
      final WorkoutCompletionController controller =
          WorkoutCompletionController(
        workoutRepository: repository,
        onWorkoutChanged: () {},
        finalizeDraft: (String id, DateTime now) async =>
            WorkoutDraft(workoutId: id),
        removeDraft: (String id) async {
          if (failCleanup) throw StateError('Draft cleanup failed');
          removed++;
        },
        onFinishingChanged: (String id, bool finishing) {},
        now: () => DateTime.utc(2026, 8, 6, 7),
      );
      await expectLater(
        controller.finishWorkout('chest-+-triceps'),
        throwsStateError,
      );
      final Workout saved = (await repository.getById('chest-+-triceps'))!;
      expect(saved.status, WorkoutStatus.completed);
      failCleanup = false;
      expect(await controller.finishWorkout(saved.id), saved);
      expect(removed, 1);
      expect(repository.completedSaveCount, 1);
      expect(await controller.finishWorkout(saved.id), saved);
      expect(repository.completedSaveCount, 1);
    },
  );

  test('Finish retains strength already saved in an active workout', () async {
    final Workout original = _workout(
      'Chest + Triceps',
      WorkoutStatus.inProgress,
    );
    final Workout entered = original.copyWith(
      sets: <WorkoutSet>[
        original.sets.single.copyWith(weightKg: 72.5, reps: 8),
      ],
    );
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[entered],
    );
    final Workout saved = (await _controller(
      repository,
    ).finishWorkout(entered.id))!;
    expect(saved.sets.single.weightKg, 72.5);
    expect(saved.sets.single.reps, 8);
    expect(saved.sets.single.status, WorkoutSetStatus.completed);
  });

  test(
    'manual Thursday selection starts each workout without completing others',
    () async {
      for (final String workoutName in WorkoutProgram.workoutNames) {
        final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
          _programTemplates(),
        );
        final WorkoutCompletionController controller = _controller(repository);

        final Workout? selected = await controller.startSelectedWorkout(
          workoutName,
        );

        expect(selected?.name, workoutName);
        expect(selected?.status, WorkoutStatus.inProgress);
        expect(
          (await repository.getAll()).where(
            (Workout workout) => workout.status == WorkoutStatus.completed,
          ),
          isEmpty,
        );
      }
    },
  );

  test('manual Pull B completion advances to Legs B', () async {
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      _programTemplates(),
    );
    final WorkoutCompletionController controller = _controller(repository);

    final Workout? selected = await controller.startSelectedWorkout(
      'Shoulders + Traps',
    );
    await controller.finishWorkout(selected!.id);

    expect(
      WorkoutProgram.nextIncompleteWorkout(await repository.getAll())?.name,
      'Legs + Calves',
    );
  });

  test('deleting latest history recalculates the next workout', () async {
    final Workout pushA = _completed(
      'Chest + Triceps',
      DateTime.utc(2026, 8, 1, 7),
    );
    final Workout pullA = _completed(
      'Back + Biceps',
      DateTime.utc(2026, 8, 2, 7),
    );
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[..._programTemplates(), pushA, pullA],
    );
    final WorkoutCompletionController controller = _controller(repository);

    await controller.deleteCompletedWorkout(pullA.id);

    expect(await repository.getById(pullA.id), isNull);
    expect(
      WorkoutProgram.nextIncompleteWorkout(await repository.getAll())?.name,
      'Back + Biceps',
    );
  });

  test('deleting a middle history record preserves other history', () async {
    final Workout pushA = _completed(
      'Chest + Triceps',
      DateTime.utc(2026, 8, 1, 7),
    );
    final Workout pullA = _completed(
      'Back + Biceps',
      DateTime.utc(2026, 8, 2, 7),
    );
    final Workout legsA = _completed(
      'Shoulders + Traps',
      DateTime.utc(2026, 8, 3, 7),
    );
    final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
      <Workout>[..._programTemplates(), pushA, pullA, legsA],
    );
    final WorkoutCompletionController controller = _controller(repository);

    await controller.deleteCompletedWorkout(pullA.id);

    expect(await repository.getById(pushA.id), isNotNull);
    expect(await repository.getById(legsA.id), isNotNull);
    expect(await repository.getById(pullA.id), isNull);
    expect(
      WorkoutProgram.recommendedNextWorkoutName(await repository.getAll()),
      'Legs + Calves',
    );
  });

  test(
    'deleting all history returns the programme to Chest + Triceps',
    () async {
      final Workout pushA = _completed(
        'Chest + Triceps',
        DateTime.utc(2026, 8, 1, 7),
      );
      final Workout pullA = _completed(
        'Back + Biceps',
        DateTime.utc(2026, 8, 2, 7),
      );
      final _MemoryWorkoutRepository repository = _MemoryWorkoutRepository(
        <Workout>[pushA, pullA],
      );
      final WorkoutCompletionController controller = _controller(repository);

      await controller.deleteCompletedWorkout(pullA.id);
      await controller.deleteCompletedWorkout(pushA.id);

      expect(
        WorkoutProgram.nextIncompleteWorkout(await repository.getAll())?.name,
        'Chest + Triceps',
      );
    },
  );
}

WorkoutCompletionController _controller(_MemoryWorkoutRepository repository) {
  return WorkoutCompletionController(
    workoutRepository: repository,
    onWorkoutChanged: () {},
    finalizeDraft: (String id, DateTime now) async =>
        WorkoutDraft(workoutId: id),
    removeDraft: (String id) async {},
    onFinishingChanged: (String id, bool finishing) {},
    now: () => DateTime.utc(2026, 8, 6, 7),
  );
}

List<Workout> _programTemplates() {
  return WorkoutProgram.workoutNames
      .map((String name) => _workout(name, WorkoutStatus.planned))
      .toList(growable: false);
}

Workout _workout(
  String name,
  WorkoutStatus status, {
  WorkoutTrack track = WorkoutTrack.hybrid,
}) {
  final String id = name.toLowerCase().replaceAll(' ', '-');
  return Workout(
    id: id,
    name: name,
    scheduledDate: DateTime.utc(2000),
    status: status,
    track: track,
    exerciseIds: const <String>['exercise-1'],
    sets: <WorkoutSet>[
      WorkoutSet(
        id: '$id-set-1',
        exerciseId: 'exercise-1',
        setNumber: 1,
        targetReps: 8,
        status: WorkoutSetStatus.planned,
      ),
    ],
    startedAt:
        status == WorkoutStatus.inProgress ? DateTime.utc(2026, 8, 6, 6) : null,
  );
}

Workout _completed(
  String name,
  DateTime completedAt, {
  WorkoutTrack track = WorkoutTrack.hybrid,
}) {
  final Workout planned = _workout(name, WorkoutStatus.planned, track: track);
  return planned.copyWith(
    id: '${planned.id}-${completedAt.microsecondsSinceEpoch}',
    status: WorkoutStatus.completed,
    startedAt: completedAt.subtract(const Duration(minutes: 45)),
    completedAt: completedAt,
  );
}

class _MemoryWorkoutRepository implements WorkoutRepository {
  _MemoryWorkoutRepository(
    List<Workout> workouts, {
    this.failCompletedSaves = false,
  }) : _workouts = <String, Workout>{
          for (final Workout workout in workouts) workout.id: workout,
        };

  final Map<String, Workout> _workouts;
  final bool failCompletedSaves;
  int completedSaveCount = 0;

  @override
  Future<void> delete(String id) async {
    _workouts.remove(id);
  }

  @override
  Future<List<Workout>> getAll() async => _workouts.values.toList();

  @override
  Future<Workout?> getById(String id) async => _workouts[id];

  @override
  Future<List<Workout>> getForDate(DateTime date) async => _workouts.values
      .where(
        (Workout workout) =>
            workout.scheduledDate.year == date.year &&
            workout.scheduledDate.month == date.month &&
            workout.scheduledDate.day == date.day,
      )
      .toList(growable: false);

  @override
  Future<void> save(Workout workout) async {
    if (workout.status == WorkoutStatus.completed) {
      completedSaveCount++;
      if (failCompletedSaves) throw StateError('Hive write failed');
    }
    _workouts[workout.id] = workout;
  }
}
