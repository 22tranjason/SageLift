import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_theme_preference.dart';

/// Dependency provider for the settings feature's data boundary.
final Provider<AppSettingsRepository> appSettingsRepositoryProvider =
    Provider<AppSettingsRepository>((Ref ref) {
  return AppSettingsRepository(ref.watch(keyValueStoreProvider));
});

/// Loads and updates the theme preference while exposing asynchronous state to the app.
final AsyncNotifierProvider<ThemePreferenceController, AppThemePreference>
    themePreferenceControllerProvider =
    AsyncNotifierProvider<ThemePreferenceController, AppThemePreference>(
  ThemePreferenceController.new,
);

/// Riverpod controller for the only foundation-level user preference.
class ThemePreferenceController extends AsyncNotifier<AppThemePreference> {
  @override
  Future<AppThemePreference> build() {
    return ref.read(appSettingsRepositoryProvider).loadThemePreference();
  }

  /// Persists [preference] before exposing it, preventing unsaved UI state.
  Future<void> setPreference(AppThemePreference preference) async {
    await ref.read(appSettingsRepositoryProvider).saveThemePreference(preference);
    state = AsyncData<AppThemePreference>(preference);
  }
}
