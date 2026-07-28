import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/presentation/foundation_placeholder_page.dart';

/// Named routes form the public navigation contract between features.
enum AppRoute {
  /// The intentionally minimal route that verifies application bootstrap.
  foundation,
}

/// Owns navigation configuration so features never instantiate routers directly.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: AppRoute.foundation.name,
        builder: (BuildContext context, GoRouterState state) {
          return const FoundationPlaceholderPage();
        },
      ),
    ],
  );
});
