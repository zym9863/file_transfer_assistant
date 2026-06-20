import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_models.dart';

class TrustedDevicesStore {
  static const _trustedKey = 'trusted.devices.v1';

  Future<List<TrustedDevice>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final records = preferences.getStringList(_trustedKey) ?? const <String>[];
    return records
        .map((record) {
          try {
            return TrustedDevice.fromJson(jsonDecode(record) as Map<String, Object?>);
          } catch (_) {
            return null;
          }
        })
        .whereType<TrustedDevice>()
        .toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
  }

  Future<void> trust(TrustedDevice device) async {
    final devices = await load();
    final updated = <TrustedDevice>[
      device,
      ...devices.where((entry) => entry.id != device.id),
    ];
    await _save(updated);
  }

  Future<void> remove(String id) async {
    final devices = await load();
    await _save(devices.where((device) => device.id != id).toList());
  }

  Future<void> rename(String id, String name) async {
    final devices = await load();
    await _save([
      for (final device in devices)
        if (device.id == id) device.copyWith(name: name) else device,
    ]);
  }

  Future<void> _save(List<TrustedDevice> devices) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _trustedKey,
      devices.map((device) => jsonEncode(device.toJson())).toList(),
    );
  }
}
