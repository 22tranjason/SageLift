import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/app/sagelift_app.dart';
import 'package:sagelift/core/storage/key_value_store.dart';

void main() {
  testWidgets('boots the SageLift foundation route', (WidgetTester tester) async {
    final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          keyValueStoreProvider.overrideWithValue(store),
        ],
        child: const SageLiftApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SageLift foundation is ready.'), findsOneWidget);
  });
}

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<T?> read<T>(String key) async => _values[key] as T?;

  @override
  Future<void> write<T>(String key, T value) async {
    _values[key] = value;
  }
}
