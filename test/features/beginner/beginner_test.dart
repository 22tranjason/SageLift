import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/beginner/data/beginner_repository.dart';
import 'package:sagelift/features/beginner/presentation/nhi_screen.dart';

import '../../support/workout_draft_fakes.dart';

void main() {
  test(
    'Nhi completion preserves Jason keys and clears only Nhi draft',
    () async {
      final DraftMemoryStore store = DraftMemoryStore();
      await store.write<String>('jason.workout', 'untouched');
      final BeginnerRepository repo = BeginnerRepository(store);
      await repo.save(<String, dynamic>{
        'active': true,
        'rounds': 1,
        'done': <String>['0-0'],
      });
      await repo.complete(await repo.load(), 'Comfortable');
      final Map<String, dynamic> state = await repo.load();
      expect(state['active'], isNull);
      expect((state['sessions'] as List).length, 1);
      expect(await store.read<String>('jason.workout'), 'untouched');
    },
  );
  test('failed save keeps the existing Nhi draft', () async {
    final DraftMemoryStore store = DraftMemoryStore();
    final BeginnerRepository repo = BeginnerRepository(store);
    await repo.save(<String, dynamic>{
      'active': true,
      'done': <String>['0-0'],
    });
    store.failWrites = true;
    await expectLater(
      repo.complete(await repo.load(), 'Comfortable'),
      throwsStateError,
    );
    expect((await repo.load())['active'], true);
    expect((await repo.load())['sessions'], isNull);
  });
  testWidgets('Nhi starts and resumes a saved session without charts', (
    WidgetTester tester,
  ) async {
    final DraftMemoryStore store = DraftMemoryStore();
    Future<void> open() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: NhiScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    await tester.ensureVisible(find.text('Start a gentle full-body session'));
    await tester.tap(find.text('Start a gentle full-body session'));
    await tester.pumpAndSettle();
    expect(find.text('1 round'), findsOneWidget);
    expect(find.byIcon(Icons.show_chart), findsNothing);
    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect((await BeginnerRepository(store).load())['done'], <String>['0-0']);
    await tester.pumpWidget(const SizedBox());
    await open();
    expect(find.text('1 round'), findsOneWidget);

    await tester.scrollUntilVisible(
        find.text('Finish session, even if shortened'), 400);
    await tester.tap(find.text('Finish session, even if shortened'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    expect((await BeginnerRepository(store).load())['active'], true);
    await tester.tap(find.text('Finish session, even if shortened'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comfortable'));
    await tester.pumpAndSettle();
    expect(
        ((await BeginnerRepository(store).load())['sessions'] as List).length,
        1);
    expect((await BeginnerRepository(store).load())['active'], isNull);
    expect(tester.takeException(), isNull);
  });
}
