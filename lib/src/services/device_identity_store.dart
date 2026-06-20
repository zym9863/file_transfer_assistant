import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/app_models.dart';

class DeviceIdentityStore {
  DeviceIdentityStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _idKey = 'device.identity.id';
  static const _nameKey = 'device.identity.name';
  static const _secretKey = 'device.identity.secret';

  final FlutterSecureStorage _secureStorage;

  Future<DeviceIdentity> load() async {
    final preferences = await SharedPreferences.getInstance();
    var id = preferences.getString(_idKey);
    var name = preferences.getString(_nameKey);
    var secret = await _secureStorage.read(key: _secretKey);

    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await preferences.setString(_idKey, id);
    }
    if (name == null || name.isEmpty) {
      name = _defaultDeviceName();
      await preferences.setString(_nameKey, name);
    }
    if (secret == null || secret.isEmpty) {
      secret = _randomHex(32);
      await _secureStorage.write(key: _secretKey, value: secret);
    }

    final publicMaterial = sha256.convert(utf8.encode('$id:$secret:${currentPlatformLabel()}')).toString();
    final fingerprint = _fingerprint(publicMaterial);
    return DeviceIdentity(
      id: id,
      name: name,
      platform: currentPlatformLabel(),
      secret: secret,
      fingerprint: fingerprint,
    );
  }

  Future<DeviceIdentity> rename(String name) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nameKey, name.trim());
    return load();
  }

  String _defaultDeviceName() {
    final host = Platform.localHostname.trim();
    if (host.isNotEmpty) return host;
    return Platform.isAndroid ? 'Android device' : 'Windows device';
  }

  String _randomHex(int length) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  String _fingerprint(String material) {
    final groups = <String>[];
    for (var i = 0; i < 16; i += 4) {
      groups.add(material.substring(i, i + 4).toUpperCase());
    }
    return groups.join('-');
  }
}
