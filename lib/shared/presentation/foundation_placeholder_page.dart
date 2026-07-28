import 'package:flutter/material.dart';

/// Deliberately minimal bootstrap route; product feature UI is added feature by feature.
class FoundationPlaceholderPage extends StatelessWidget {
  /// Creates the foundation route.
  const FoundationPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text('SageLift foundation is ready.', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
