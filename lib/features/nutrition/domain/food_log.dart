/// One reusable food and its labelled reference serving.
class Food {
  /// Creates a food; [grams] enables weight-based portions when known.
  const Food(
      {required this.id,
      required this.name,
      required this.serving,
      required this.calories,
      required this.protein,
      this.grams});

  /// Stable food identifier.
  final String id;

  /// Exact product or recipe name.
  final String name;

  /// Human-readable reference serving.
  final String serving;

  /// Calories per reference serving.
  final double calories;

  /// Protein grams per reference serving.
  final double protein;

  /// Reference serving weight, not liquid volume.
  final double? grams;
}

/// A snapshot so changing the catalogue never alters historical totals.
class FoodEntry {
  /// Creates a dated, measured entry.
  const FoodEntry(
      {required this.id,
      required this.day,
      required this.food,
      required this.amount,
      this.byWeight = false});

  /// Stable entry identifier.
  final String id;

  /// Local calendar day YYYY-MM-DD.
  final String day;

  /// Nutrition snapshot when logged.
  final Food food;

  /// Servings or grams depending on [byWeight].
  final double amount;

  /// Whether the amount is in grams.
  final bool byWeight;

  /// Multiplier of the reference serving.
  double get multiplier => byWeight ? amount / food.grams! : amount;

  /// Calculated calories.
  double get calories => food.calories * multiplier;

  /// Calculated protein grams.
  double get protein => food.protein * multiplier;
}

/// Local Jason-only food diary, separate from manually entered daily targets.
class FoodLog {
  /// Creates immutable diary state.
  FoodLog(
      {List<Food> foods = seedFoods,
      List<FoodEntry> entries = const <FoodEntry>[],
      Set<String> favourites = const <String>{}})
      : foods = List<Food>.unmodifiable(foods),
        entries = List<FoodEntry>.unmodifiable(entries),
        favourites = Set<String>.unmodifiable(favourites);

  /// Food catalogue.
  final List<Food> foods;

  /// Dated entry snapshots.
  final List<FoodEntry> entries;

  /// Pinned food identifiers.
  final Set<String> favourites;

  /// Latest foods first, favourites before recent, then the remaining catalogue.
  List<Food> search(String query) {
    final List<String> recent =
        entries.reversed.map((FoodEntry e) => e.food.id).toSet().toList();
    final List<Food> found = foods
        .where((Food f) =>
            f.name.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    int rank(Food f) => favourites.contains(f.id)
        ? -1
        : recent.contains(f.id)
            ? recent.indexOf(f.id)
            : recent.length;
    found.sort((Food a, Food b) {
      final int order = rank(a).compareTo(rank(b));
      return order == 0 ? a.name.compareTo(b.name) : order;
    });
    return found;
  }

  /// Entries for a local calendar day.
  List<FoodEntry> forDay(String day) =>
      entries.where((FoodEntry e) => e.day == day).toList();

  /// Copy with only selected fields changed.
  FoodLog copyWith(
          {List<Food>? foods,
          List<FoodEntry>? entries,
          Set<String>? favourites}) =>
      FoodLog(
          foods: foods ?? this.foods,
          entries: entries ?? this.entries,
          favourites: favourites ?? this.favourites);

  /// Public label values checked November 2026; package labels take precedence.
  static const List<Food> seedFoods = <Food>[
    Food(
        id: 'upgo-choc-250',
        name: 'UP&GO Protein Energize Choc Hit',
        serving: '250 mL carton',
        calories: 201,
        protein: 17.9),
    Food(
        id: 'yopro-vanilla-160',
        name: 'YoPRO vanilla yoghurt',
        serving: '160 g pot',
        grams: 160,
        calories: 91,
        protein: 15.2),
  ];
}

/// Calendar key deliberately preserves local dates instead of converting to UTC.
String foodDay(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
