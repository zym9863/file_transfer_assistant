import 'dart:io';

import 'package:flutter/foundation.dart';

String currentPlatformLabel() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  if (Platform.isIOS) return 'ios';
  return 'other';
}

@immutable
class DeviceIdentity {
  const DeviceIdentity({
    required this.id,
    required this.name,
    required this.platform,
    required this.secret,
    required this.fingerprint,
  });

  final String id;
  final String name;
  final String platform;
  final String secret;
  final String fingerprint;
}

@immutable
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.address,
    required this.port,
    required this.fingerprint,
    required this.lastSeen,
    this.isTrusted = false,
  });

  final String id;
  final String name;
  final String platform;
  final String address;
  final int port;
  final String fingerprint;
  final DateTime lastSeen;
  final bool isTrusted;

  DiscoveredDevice copyWith({
    String? id,
    String? name,
    String? platform,
    String? address,
    int? port,
    String? fingerprint,
    DateTime? lastSeen,
    bool? isTrusted,
  }) {
    return DiscoveredDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      address: address ?? this.address,
      port: port ?? this.port,
      fingerprint: fingerprint ?? this.fingerprint,
      lastSeen: lastSeen ?? this.lastSeen,
      isTrusted: isTrusted ?? this.isTrusted,
    );
  }
}

@immutable
class TrustedDevice {
  const TrustedDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.fingerprint,
    required this.trustToken,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final String platform;
  final String fingerprint;
  final String trustToken;
  final DateTime lastSeen;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'fingerprint': fingerprint,
        'trustToken': trustToken,
        'lastSeen': lastSeen.toIso8601String(),
      };

  factory TrustedDevice.fromJson(Map<String, Object?> json) {
    return TrustedDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      fingerprint: json['fingerprint'] as String,
      trustToken: json['trustToken'] as String,
      lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.now(),
    );
  }

  TrustedDevice copyWith({
    String? name,
    String? platform,
    String? fingerprint,
    String? trustToken,
    DateTime? lastSeen,
  }) {
    return TrustedDevice(
      id: id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      fingerprint: fingerprint ?? this.fingerprint,
      trustToken: trustToken ?? this.trustToken,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

enum TransferDirection { sending, receiving }

enum TransferStatus { queued, pairing, connecting, transferring, complete, failed, canceled }

@immutable
class TransferItem {
  const TransferItem({
    required this.id,
    required this.fileName,
    required this.totalBytes,
    required this.direction,
    required this.status,
    required this.createdAt,
    this.filePath,
    this.relativePath,
    this.transferredBytes = 0,
    this.deviceName,
    this.error,
    this.completedAt,
    this.speedBytesPerSecond = 0,
  });

  final String id;
  final String fileName;
  final String? filePath;
  final String? relativePath;
  final int totalBytes;
  final int transferredBytes;
  final TransferDirection direction;
  final TransferStatus status;
  final String? deviceName;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final double speedBytesPerSecond;

  double get progress => totalBytes <= 0 ? 0.0 : (transferredBytes / totalBytes).clamp(0, 1).toDouble();

  TransferItem copyWith({
    String? id,
    String? fileName,
    Object? filePath = _sentinel,
    Object? relativePath = _sentinel,
    int? totalBytes,
    int? transferredBytes,
    TransferDirection? direction,
    TransferStatus? status,
    Object? deviceName = _sentinel,
    Object? error = _sentinel,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
    double? speedBytesPerSecond,
  }) {
    return TransferItem(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: identical(filePath, _sentinel) ? this.filePath : filePath as String?,
      relativePath: identical(relativePath, _sentinel) ? this.relativePath : relativePath as String?,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      deviceName: identical(deviceName, _sentinel) ? this.deviceName : deviceName as String?,
      error: identical(error, _sentinel) ? this.error : error as String?,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _sentinel) ? this.completedAt : completedAt as DateTime?,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
    );
  }
}

const Object _sentinel = Object();


