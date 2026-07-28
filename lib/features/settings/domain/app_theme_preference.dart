import 'package:flutter/material.dart';

/// User-selectable strategy for choosing the application brightness.
enum AppThemePreference {
  /// Follow the operating system appearance.
  system,

  /// Always use the light Material theme.
  light,

  /// Always use the dark Material theme.
  dark;

  /// Converts the persisted preference into Flutter's framework value.
  ThemeMode get toThemeMode => switch (this) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      };
}
