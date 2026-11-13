import 'dart:convert';
import '../../../core/storage/key_value_store.dart';
import '../domain/food_log.dart';

/// Versioned local persistence, included in the existing settings backup.
class FoodLogRepository {
  /// Uses the app's platform-neutral settings storage.
  FoodLogRepository(this.store);

  /// Local settings store.
  final KeyValueStore store;

  /// Separate namespace avoids altering existing daily protein and Nhi records.
  static const String key = 'jason.foodLog.v1';

  /// Reads diary state; corrupt data is surfaced, never silently overwritten.
  Future<FoodLog> load() async {
    final String? raw = await store.read<String>(key);
    if (raw == null) return FoodLog();
    final Map<String, dynamic> data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported food log');
    }
    return FoodLog(
      foods: (data['foods'] as List<dynamic>)
          .map((dynamic f) => _food(f as Map<String, dynamic>))
          .toList(),
      favourites: (data['favourites'] as List<dynamic>).cast<String>().toSet(),
      entries: (data['entries'] as List<dynamic>).map((dynamic value) {
        final Map<String, dynamic> e = value as Map<String, dynamic>;
        final Food food = _food(e['food'] as Map<String, dynamic>);
        final double amount = (e['amount'] as num).toDouble();
        final bool weight = e['byWeight'] as bool;
        if (!amount.isFinite || amount <= 0 || (weight && food.grams == null)) {
          throw const FormatException('Invalid portion');
        }
        return FoodEntry(
            id: e['id'] as String,
            day: e['day'] as String,
            food: food,
            amount: amount,
            byWeight: weight);
      }).toList(),
    );
  }

  /// Saves one atomic snapshot; caller changes its state only after success.
  Future<void> save(FoodLog log) => store.write<String>(
      key,
      jsonEncode(<String, Object?>{
        'version': 1,
        'foods': log.foods.map(_json).toList(),
        'favourites': log.favourites.toList(),
        'entries': log.entries
            .map((FoodEntry e) => <String, Object?>{
                  'id': e.id,
                  'day': e.day,
                  'food': _json(e.food),
                  'amount': e.amount,
                  'byWeight': e.byWeight
                })
            .toList(),
      }));
  Map<String, Object?> _json(Food f) => <String, Object?>{
        'id': f.id,
        'name': f.name,
        'serving': f.serving,
        'calories': f.calories,
        'protein': f.protein,
        'grams': f.grams
      };
  Food _food(Map<String, dynamic> f) {
    final double calories = (f['calories'] as num).toDouble();
    final double protein = (f['protein'] as num).toDouble();
    final double? grams = (f['grams'] as num?)?.toDouble();
    if (!calories.isFinite ||
        calories < 0 ||
        !protein.isFinite ||
        protein < 0 ||
        (grams != null && (!grams.isFinite || grams <= 0))) {
      throw const FormatException('Invalid nutrition');
    }
    return Food(
        id: f['id'] as String,
        name: f['name'] as String,
        serving: f['serving'] as String,
        calories: calories,
        protein: protein,
        grams: grams);
  }
}
