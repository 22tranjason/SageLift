import 'package:hive_flutter/hive_flutter.dart';

import 'key_value_store.dart';

/// Hive-backed storage for settings and lightweight offline metadata.
class HiveLocalKeyValueStore implements KeyValueStore {
  static const String _boxName = 'sagelift_settings';
  late final Box<dynamic> _box;

  /// The settings box, exposed to the local backup data service at bootstrap.
  Box<dynamic> get box => _box;

  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  @override
  Future<T?> read<T>(String key) async => _box.get(key) as T?;

  @override
  Future<void> write<T>(String key, T value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}
