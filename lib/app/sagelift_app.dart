import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_theme_preference.dart';
import '../features/settings/presentation/providers/deployment_update_controller.dart';
import '../features/settings/presentation/theme_preference_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// The composition root for visual application concerns.
class SageLiftApp extends ConsumerStatefulWidget {
  /// Creates the root widget.
  const SageLiftApp({super.key});

  @override
  ConsumerState<SageLiftApp> createState() => _SageLiftAppState();
}

class _SageLiftAppState extends ConsumerState<SageLiftApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
        ref.read(deploymentUpdateControllerProvider.notifier).checkForUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(deploymentUpdateControllerProvider.notifier).checkForUpdate(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode =
        ref.watch(themePreferenceControllerProvider).when(
              data: (AppThemePreference value) => value.toThemeMode,
              error: (_, __) => ThemeMode.system,
              loading: () => ThemeMode.system,
            );
    final String? availableBuildId =
        ref.watch(deploymentUpdateControllerProvider);
    return MaterialApp.router(
      title: 'SageLift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            if (child != null) child,
            if (availableBuildId != null) const _UpdateAvailablePrompt(),
          ],
        );
      },
    );
  }
}

class _UpdateAvailablePrompt extends ConsumerStatefulWidget {
  const _UpdateAvailablePrompt();

  @override
  ConsumerState<_UpdateAvailablePrompt> createState() =>
      _UpdateAvailablePromptState();
}

class _UpdateAvailablePromptState
    extends ConsumerState<_UpdateAvailablePrompt> {
  bool _updating = false;
  bool _saveFailed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: AlertDialog(
          title: const Text('A new SageLift update is available.'),
          content: _saveFailed
              ? const Text(
                  'Your workout draft could not be saved. The app has stayed '
                  'open. Free some device storage and try again.',
                )
              : _updating
                  ? const Text('Saving workout progress…')
                  : null,
          actions: <Widget>[
            TextButton(
              onPressed: _updating
                  ? null
                  : ref
                      .read(deploymentUpdateControllerProvider.notifier)
                      .dismiss,
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: _updating
                  ? null
                  : () async {
                      setState(() {
                        _updating = true;
                        _saveFailed = false;
                      });
                      try {
                        await ref
                            .read(deploymentUpdateControllerProvider.notifier)
                            .updateNow();
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _saveFailed = true;
                            _updating = false;
                          });
                        }
                      }
                    },
              child: const Text('Update now'),
            ),
          ],
        ),
      ),
    );
  }
}
