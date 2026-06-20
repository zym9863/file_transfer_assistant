import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'app_models.dart';

const discoveryPort = 47471;
const protocolVersion = 1;
const _discoveryMagic = 'fta.discovery';

class DiscoveryMessage {
  const DiscoveryMessage({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.port,
    required this.fingerprint,
    required this.timestamp,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final int port;
  final String fingerprint;
  final DateTime timestamp;

  Map<String, Object?> toJson() => {
        'magic': _discoveryMagic,
        'version': protocolVersion,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'port': port,
        'fingerprint': fingerprint,
        'timestamp': timestamp.toIso8601String(),
      };

  String encode() => jsonEncode(toJson());

  static DiscoveryMessage? tryDecode(String payload) {
    try {
      final json = jsonDecode(payload) as Map<String, Object?>;
      if (json['magic'] != _discoveryMagic || json['version'] != protocolVersion) {
        return null;
      }
      return DiscoveryMessage(
        deviceId: json['deviceId'] as String,
        deviceName: json['deviceName'] as String,
        platform: json['platform'] as String,
        port: json['port'] as int,
        fingerprint: json['fingerprint'] as String,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  DiscoveredDevice toDevice(String address, bool trusted) {
    return DiscoveredDevice(
      id: deviceId,
      name: deviceName,
      platform: platform,
      address: address,
      port: port,
      fingerprint: fingerprint,
      lastSeen: timestamp,
      isTrusted: trusted,
    );
  }
}

class PairingProtocol {
  static String generatePin() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  static String proof({
    required String secret,
    required String senderId,
    required String receiverId,
    required String receiverFingerprint,
  }) {
    final key = utf8.encode(secret);
    final message = utf8.encode('$senderId:$receiverId:$receiverFingerprint');
    return Hmac(sha256, key).convert(message).toString();
  }

  static String trustToken({
    required String senderId,
    required String receiverId,
    required String proof,
  }) {
    return sha256.convert(utf8.encode('$senderId:$receiverId:$proof')).toString();
  }

  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

class TransferHeader {
  const TransferHeader({
    required this.fileName,
    required this.relativePath,
    required this.totalBytes,
    required this.sha256Hex,
    required this.mimeType,
  });

  final String fileName;
  final String relativePath;
  final int totalBytes;
  final String sha256Hex;
  final String mimeType;

  Map<String, Object?> toJson() => {
        'type': 'file',
        'fileName': fileName,
        'relativePath': relativePath,
        'totalBytes': totalBytes,
        'sha256': sha256Hex,
        'mimeType': mimeType,
      };

  String encodeLine() => '${jsonEncode(toJson())}\n';

  static TransferHeader fromJson(Map<String, Object?> json) {
    return TransferHeader(
      fileName: json['fileName'] as String,
      relativePath: (json['relativePath'] as String?) ?? (json['fileName'] as String),
      totalBytes: json['totalBytes'] as int,
      sha256Hex: json['sha256'] as String,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    );
  }
}

class PairingEnvelope {
  const PairingEnvelope({
    required this.senderId,
    required this.senderName,
    required this.senderPlatform,
    required this.senderFingerprint,
    required this.proof,
    required this.usesTrustedToken,
  });

  final String senderId;
  final String senderName;
  final String senderPlatform;
  final String senderFingerprint;
  final String proof;
  final bool usesTrustedToken;

  Map<String, Object?> toJson() => {
        'type': 'pairing',
        'version': protocolVersion,
        'senderId': senderId,
        'senderName': senderName,
        'senderPlatform': senderPlatform,
        'senderFingerprint': senderFingerprint,
        'proof': proof,
        'usesTrustedToken': usesTrustedToken,
      };

  String encodeLine() => '${jsonEncode(toJson())}\n';

  static PairingEnvelope fromJson(Map<String, Object?> json) {
    return PairingEnvelope(
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderPlatform: json['senderPlatform'] as String,
      senderFingerprint: json['senderFingerprint'] as String,
      proof: json['proof'] as String,
      usesTrustedToken: json['usesTrustedToken'] as bool? ?? false,
    );
  }
}

