import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_theme_preference.dart';
import '../features/settings/presentation/theme_preference_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// The composition root for visual application concerns.
class SageLiftApp extends ConsumerWidget {
  /// Creates the root widget.
  const SageLiftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themePreferenceControllerProvider).when(
          data: (AppThemePreference value) => value.toThemeMode,
          error: (_, __) => ThemeMode.system,
          loading: () => ThemeMode.system,
        );
    return MaterialApp.router(
      title: 'SageLift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
