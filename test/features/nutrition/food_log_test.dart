import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/nutrition/data/food_log_repository.dart';
import 'package:sagelift/features/nutrition/domain/food_log.dart';
import 'package:sagelift/features/nutrition/presentation/food_log_controller.dart';
import 'package:sagelift/features/nutrition/presentation/food_log_screen.dart';
import '../../support/workout_draft_fakes.dart';

void main() {
  FoodEntry entry(String id,
          {double amount = 1,
          bool weight = false,
          String day = '2026-11-14'}) =>
      FoodEntry(
          id: id,
          day: day,
          food: FoodLog.seedFoods[1],
          amount: amount,
          byWeight: weight);
  test('portions, day separation, and favourites/recent search', () {
    final FoodEntry half = entry('half', amount: 80, weight: true);
    expect(half.calories, 45.5);
    expect(half.protein, 7.6);
    final FoodLog log = FoodLog(
        entries: <FoodEntry>[half, entry('yesterday', day: '2026-11-13')]);
    expect(log.forDay('2026-11-14').length, 1);
    expect(log.search(' YOpro ').single.id, 'yopro-vanilla-160');
    expect(log.search('').first.id, 'yopro-vanilla-160');
    expect(
        log.copyWith(favourites: <String>{'upgo-choc-250'}).search('').first.id,
        'upgo-choc-250');
    expect(foodDay(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
  });
  test('round trip keeps custom meal, favourites, snapshot, and unrelated data',
      () async {
    final DraftMemoryStore store = DraftMemoryStore();
    store.values['manual.protein'] = 99;
    final FoodLogRepository repository = FoodLogRepository(store);
    const Food meal = Food(
        id: 'meal',
        name: 'Chicken rice (estimate)',
        serving: '1 lunchbox',
        grams: 450,
        calories: 600,
        protein: 40);
    await repository.save(FoodLog(
        foods: <Food>[...FoodLog.seedFoods, meal],
        entries: <FoodEntry>[entry('a')],
        favourites: <String>{'meal'}));
    final FoodLog reloaded = await FoodLogRepository(store).load();
    expect(reloaded.foods.last.name, meal.name);
    expect(reloaded.favourites, <String>{'meal'});
    expect(reloaded.entries.single.calories, 91);
    expect(store.values['manual.protein'], 99);
    store.values[FoodLogRepository.key] = 'broken';
    await expectLater(repository.load(), throwsFormatException);
  });
  test('edit replaces once; delete; save failure preserves previous values',
      () async {
    final DraftMemoryStore store = DraftMemoryStore();
    final ProviderContainer container = ProviderContainer(
        overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(foodLogProvider.future);
    final FoodLogController controller =
        container.read(foodLogProvider.notifier);
    await controller.saveEntry(entry('a'));
    await controller.saveEntry(entry('a', amount: 2));
    expect(container.read(foodLogProvider).requireValue.entries.length, 1);
    expect(container.read(foodLogProvider).requireValue.entries.single.calories,
        182);
    store.failWrites = true;
    await expectLater(controller.deleteEntry('a'), throwsStateError);
    expect(container.read(foodLogProvider).requireValue.entries.length, 1);
    store.failWrites = false;
    await controller.deleteEntry('a');
    expect((await FoodLogRepository(store).load()).entries, isEmpty);
    await expectLater(
        controller.saveEntry(entry('invalid', amount: double.nan)),
        throwsArgumentError);
  });
  test('overlapping save fails clearly instead of losing updates', () async {
    final DraftMemoryStore store = DraftMemoryStore();
    final ProviderContainer container = ProviderContainer(
        overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(foodLogProvider.future);
    store.writeGate = Completer<void>();
    final FoodLogController controller =
        container.read(foodLogProvider.notifier);
    final Future<void> first = controller.saveEntry(entry('a'));
    await expectLater(controller.saveEntry(entry('b')), throwsStateError);
    store.writeGate!.complete();
    await first;
    expect(container.read(foodLogProvider).requireValue.entries.single.id, 'a');
  });
  testWidgets(
      'mobile add, cancel edit, edit, delete cancel, delete and restart',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final DraftMemoryStore store = DraftMemoryStore();
    Future<void> open() async {
      await tester.pumpWidget(ProviderScope(
          overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: FoodLogScreen())));
      await tester.pumpAndSettle();
    }

    await open();
    await tester.scrollUntilVisible(find.text('YoPRO vanilla yoghurt'), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.text('YoPRO vanilla yoghurt'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect((await FoodLogRepository(store).load()).entries.single.amount, 2);
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('182 cal • 30.4 g protein'), findsOneWidget);
    await tester.tap(find.text('YoPRO vanilla yoghurt').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await FoodLogRepository(store).load()).entries.single.amount, 2);
    await tester.tap(find.text('YoPRO vanilla yoghurt').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '1');
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.text('91 cal • 15.2 g protein'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect((await FoodLogRepository(store).load()).entries.length, 1);
    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect((await FoodLogRepository(store).load()).entries, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('custom estimate is saved for reuse even if logging is cancelled',
      (WidgetTester tester) async {
    final DraftMemoryStore store = DraftMemoryStore();
    await tester.pumpWidget(ProviderScope(
        overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: FoodLogScreen())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create custom food or recipe'));
    await tester.tap(find.text('Create custom food or recipe'));
    await tester.pumpAndSettle();
    final List<String> values = <String>[
      'Chicken lunch (estimate)',
      '1 lunchbox',
      '600',
      '40',
      '450'
    ];
    for (int i = 0; i < values.length; i++) {
      await tester.enterText(find.byType(TextFormField).at(i), values[i]);
    }
    await tester.tap(find.text('Save food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final FoodLog log = await FoodLogRepository(store).load();
    expect(log.foods.last.name, values.first);
    expect(log.entries, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
