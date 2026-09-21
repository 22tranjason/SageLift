import 'dart:convert';

import '../../../../core/storage/key_value_store.dart';
import '../../domain/models/workout_draft.dart';
import '../../domain/services/for_time_timer.dart';

/// Additive JSON snapshots in the existing settings store.
///
/// The settings backup already includes these values. No Hive adapters or
/// completed-workout records are changed.
class LocalWorkoutDraftRepository {
  /// Creates a repository over the initialized local settings store.
  LocalWorkoutDraftRepository(this._store);

  final KeyValueStore _store;
  Future<void> _tail = Future<void>.value();
  final Map<String, WorkoutDraft> _pending = <String, WorkoutDraft>{};

  String _key(String id) => 'workouts.draft.v1.$id';

  /// Loads a session after any earlier writes have settled.
  Future<WorkoutDraft> load(String id) async {
    await _tail;
    final WorkoutDraft? pending = _pending[id];
    if (pending != null) return pending;
    final String? encoded = await _store.read<String>(_key(id));
    if (encoded == null) return WorkoutDraft(workoutId: id);
    final Map<String, dynamic> json =
        jsonDecode(encoded) as Map<String, dynamic>;
    if (json['version'] != 1 || json['workoutId'] != id) {
      throw const FormatException('Unsupported workout draft.');
    }
    final Map<String, dynamic> conditioning =
        json['conditioning'] as Map<String, dynamic>;
    final Map<String, dynamic> timer =
        conditioning['timer'] as Map<String, dynamic>;
    final String? startedAt = timer['startedAt'] as String?;
    return WorkoutDraft(
      workoutId: id,
      sets: (json['sets'] as Map<String, dynamic>).map(
        (String id, dynamic value) {
          final Map<String, dynamic> entry = value as Map<String, dynamic>;
          return MapEntry<String, WorkoutSetProgress>(
            id,
            WorkoutSetProgress(
              weight: entry['weight'] as String,
              reps: entry['reps'] as String,
            ),
          );
        },
      ),
      conditioning: WorkoutConditioningProgress(
        rounds: conditioning['rounds'] as String,
        additionalReps: conditioning['additionalReps'] as String,
        minutes: conditioning['minutes'] as String,
        seconds: conditioning['seconds'] as String,
        hasManualTime: conditioning['hasManualTime'] as bool,
        scaling: conditioning['scaling'] as String,
        isCompleted: conditioning['isCompleted'] as bool,
        movements: (conditioning['movements'] as Map<String, dynamic>).map(
          (String id, dynamic value) {
            final Map<String, dynamic> entry = value as Map<String, dynamic>;
            return MapEntry<String, ConditioningMovementProgress>(
              id,
              ConditioningMovementProgress(
                load: entry['load'] as String,
                implementCount: entry['implementCount'] as String,
                modification: entry['modification'] as String,
              ),
            );
          },
        ),
        timer: ForTimeTimer(
          elapsed: Duration(microseconds: timer['elapsedMicroseconds'] as int),
          startedAt: startedAt == null ? null : DateTime.parse(startedAt),
        ),
      ),
    );
  }

  /// Queues every edit immediately and retains failed snapshots for retry.
  Future<void> save(WorkoutDraft draft) {
    _pending[draft.workoutId] = draft;
    return _enqueue(() async {
      await _store.write<String>(_key(draft.workoutId), _encode(draft));
      if (identical(_pending[draft.workoutId], draft)) {
        _pending.remove(draft.workoutId);
      }
    });
  }

  /// Drains writes and retries the latest unsaved snapshots before a reload.
  ///
  /// A storage failure propagates so the caller can keep the app open.
  Future<void> flush() async {
    await _tail;
    while (_pending.isNotEmpty) {
      await Future.wait<void>(_pending.values.toList().map(save));
      await _tail;
    }
  }

  /// Removes only this session, after all preceding writes have settled.
  Future<void> remove(String id) => _enqueue(() async {
        await _store.delete(_key(id));
        _pending.remove(id);
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> result = _tail.then((_) => operation());
    // Keep later writes possible after a failed write. The returned future still
    // reports the failure, and the latest unsaved snapshot remains in _pending.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String _encode(WorkoutDraft draft) {
    final WorkoutConditioningProgress conditioning = draft.conditioning;
    return jsonEncode(<String, Object?>{
      'version': 1,
      'workoutId': draft.workoutId,
      'sets': draft.sets.map((String id, WorkoutSetProgress entry) =>
          MapEntry<String, Object>(id, <String, String>{
            'weight': entry.weight,
            'reps': entry.reps,
          })),
      'conditioning': <String, Object?>{
        'rounds': conditioning.rounds,
        'additionalReps': conditioning.additionalReps,
        'minutes': conditioning.minutes,
        'seconds': conditioning.seconds,
        'hasManualTime': conditioning.hasManualTime,
        'scaling': conditioning.scaling,
        'isCompleted': conditioning.isCompleted,
        'movements': conditioning.movements.map(
          (String id, ConditioningMovementProgress entry) =>
              MapEntry<String, Object>(id, <String, String>{
            'load': entry.load,
            'implementCount': entry.implementCount,
            'modification': entry.modification,
          }),
        ),
        'timer': <String, Object?>{
          'elapsedMicroseconds': conditioning.timer.elapsed.inMicroseconds,
          // Null means paused; UTC avoids local timezone interpretation on reload.
          'startedAt': conditioning.timer.startedAt?.toUtc().toIso8601String(),
        },
      },
    });
  }
}
