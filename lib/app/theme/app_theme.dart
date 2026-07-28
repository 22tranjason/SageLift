import 'package:flutter/material.dart';

/// Central Material 3 themes. Features consume ThemeData rather than hard-code colors.
abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF5A7D50);

  /// Light Material 3 theme for daylight and high-contrast environments.
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      brightness: Brightness.light,
    );
  }

  /// Dark Material 3 theme for low-light training environments.
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark),
      brightness: Brightness.dark,
    );
  }
}
