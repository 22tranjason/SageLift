import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/key_value_store.dart';

/// Local landing preference, not a synced account.
final FutureProvider<String> trainingProfileProvider = FutureProvider<String>(
  (Ref ref) async =>
      await ref.watch(keyValueStoreProvider).read<String>('training.profile') ??
      'jason',
);

/// Switches landing screens without moving or deleting records.
Future<void> selectTrainingProfile(WidgetRef ref, String profile) async {
  await ref
      .read(keyValueStoreProvider)
      .write<String>('training.profile', profile);
  ref.invalidate(trainingProfileProvider);
}
