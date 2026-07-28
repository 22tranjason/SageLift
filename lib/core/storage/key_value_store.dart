import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Small storage seam that keeps domain and feature code independent of Hive.
abstract interface class KeyValueStore {
  /// Opens or prepares the underlying store.
  Future<void> initialize();

  /// Reads a primitive value, or null when the key has not been written.
  Future<T?> read<T>(String key);

  /// Persists a primitive value for [key].
  Future<void> write<T>(String key, T value);

  /// Removes one value without affecting other application data.
  Future<void> delete(String key);
}

/// Must be overridden at application startup with the selected persistence engine.
final Provider<KeyValueStore> keyValueStoreProvider = Provider<KeyValueStore>((Ref ref) {
  throw UnimplementedError('KeyValueStore must be provided during bootstrap.');
});
