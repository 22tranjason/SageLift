import 'dart:convert';

import '../../../core/storage/key_value_store.dart';

/// Nhi-only session state stored separately from Jason's workout records.
class BeginnerRepository {
  /// Uses the existing backed-up metadata store.
  BeginnerRepository(this.store);

  /// Local storage interface.
  final KeyValueStore store;

  /// Versioned Nhi-only key.
  static const String key = 'nhi.beginner.v1';

  /// Reads a resumable draft and completion records.
  Future<Map<String, dynamic>> load() async {
    final String? raw = await store.read<String>(key);
    return raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Saves draft changes without touching workout data.
  Future<void> save(Map<String, dynamic> state) =>
      store.write<String>(key, jsonEncode(state));

  /// Commits completion and clears the draft in a single write.
  Future<Map<String, dynamic>> complete(
    Map<String, dynamic> state,
    String effort,
  ) async {
    final List<dynamic> sessions = List<dynamic>.from(
      state['sessions'] as List? ?? <dynamic>[],
    );
    sessions.add(<String, dynamic>{
      'completedAt': DateTime.now().toIso8601String(),
      'plannedRounds': state['rounds'] ?? 1,
      'checkedExercises': state['done'] ?? <String>[],
      'effort': effort,
    });
    final Map<String, dynamic> next = <String, dynamic>{'sessions': sessions};
    await save(next);
    return next;
  }
}
