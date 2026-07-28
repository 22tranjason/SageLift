import '../../../core/storage/key_value_store.dart';
import '../domain/app_theme_preference.dart';

/// Persists cross-feature application preferences.
class AppSettingsRepository {
  /// Creates a repository over the application key-value store.
  AppSettingsRepository(this._store);

  static const String _themePreferenceKey = 'app.theme_preference';
  final KeyValueStore _store;

  /// Retrieves the current preference, defaulting safely for a first launch.
  Future<AppThemePreference> loadThemePreference() async {
    final String? rawValue = await _store.read<String>(_themePreferenceKey);
    for (final AppThemePreference preference in AppThemePreference.values) {
      if (preference.name == rawValue) return preference;
    }
    return AppThemePreference.system;
  }

  /// Saves the user-selected preference in a platform-neutral representation.
  Future<void> saveThemePreference(AppThemePreference preference) {
    return _store.write<String>(_themePreferenceKey, preference.name);
  }
}
