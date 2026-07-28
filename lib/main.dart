import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/sagelift_app.dart';
import 'core/storage/hive_local_key_value_store.dart';
import 'core/storage/key_value_store.dart';

/// Starts the app after its offline storage dependency is ready.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final HiveLocalKeyValueStore localStore = HiveLocalKeyValueStore();
  await localStore.initialize();
  runApp(
    ProviderScope(
      overrides: <Override>[keyValueStoreProvider.overrideWithValue(localStore)],
      child: const SageLiftApp(),
    ),
  );
}
