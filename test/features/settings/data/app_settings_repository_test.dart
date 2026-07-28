import 'package:flutter_test/flutter_test.dart';
import 'package:sagelift/core/storage/key_value_store.dart';
import 'package:sagelift/features/settings/data/app_settings_repository.dart';
import 'package:sagelift/features/settings/domain/app_theme_preference.dart';

void main() {
  group('AppSettingsRepository', () {
    test('defaults to the system theme when no preference has been saved', () async {
      final AppSettingsRepository repository = AppSettingsRepository(
        _InMemoryKeyValueStore(),
      );

      expect(await repository.loadThemePreference(), AppThemePreference.system);
    });

    test('round-trips a saved theme preference', () async {
      final _InMemoryKeyValueStore store = _InMemoryKeyValueStore();
      final AppSettingsRepository repository = AppSettingsRepository(store);

      await repository.saveThemePreference(AppThemePreference.dark);

      expect(await repository.loadThemePreference(), AppThemePreference.dark);
    });
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
