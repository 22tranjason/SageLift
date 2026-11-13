import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/key_value_store.dart';
import '../data/food_log_repository.dart';
import '../domain/food_log.dart';

/// Local diary state.
final AsyncNotifierProvider<FoodLogController, FoodLog> foodLogProvider =
    AsyncNotifierProvider<FoodLogController, FoodLog>(FoodLogController.new);

/// Serialises mutations and publishes only successfully persisted values.
class FoodLogController extends AsyncNotifier<FoodLog> {
  bool _saving = false;
  @override
  Future<FoodLog> build() =>
      FoodLogRepository(ref.watch(keyValueStoreProvider)).load();
  Future<void> _change(FoodLog Function(FoodLog) transform) async {
    if (_saving) throw StateError('Save already in progress');
    final FoodLog? current = state.valueOrNull;
    if (current == null) throw StateError('Diary not loaded');
    _saving = true;
    try {
      final FoodLog next = transform(current);
      await FoodLogRepository(ref.read(keyValueStoreProvider)).save(next);
      state = AsyncData<FoodLog>(next);
    } finally {
      _saving = false;
    }
  }

  /// Adds a reusable labelled food.
  Future<void> addFood(Food food) =>
      _change((FoodLog log) => log.copyWith(foods: <Food>[...log.foods, food]));

  /// Adds or replaces an entry without duplicate records.
  Future<void> saveEntry(FoodEntry entry) {
    if (!entry.amount.isFinite ||
        entry.amount <= 0 ||
        (entry.byWeight && entry.food.grams == null)) {
      return Future<void>.error(ArgumentError('Invalid portion'));
    }
    return _change((FoodLog log) => log.copyWith(entries: <FoodEntry>[
          ...log.entries.where((FoodEntry e) => e.id != entry.id),
          entry
        ]));
  }

  /// Removes only the selected diary entry.
  Future<void> deleteEntry(String id) => _change((FoodLog log) => log.copyWith(
      entries: log.entries.where((FoodEntry e) => e.id != id).toList()));

  /// Pins or unpins a food without altering logged meals.
  Future<void> toggleFavourite(String id) => _change((FoodLog log) {
        final Set<String> ids = <String>{...log.favourites};
        if (!ids.remove(id)) ids.add(id);
        return log.copyWith(favourites: ids);
      });
}
