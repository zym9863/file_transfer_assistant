import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_models.dart';
import '../core/protocol.dart';

typedef TransferChanged = void Function(TransferItem item);
typedef TrustedDeviceWriter = Future<void> Function(TrustedDevice device);
typedef TrustedDevicesReader = List<TrustedDevice> Function();
typedef ActivePinReader = String Function();

class FileTransferService {
  ServerSocket? _server;
  TrustedDevicesReader? _trustedDevices;
  ActivePinReader? _activePin;
  TransferChanged? _onTransferChanged;
  TrustedDeviceWriter? _onTrustedDevice;
  String? _saveDirectory;
  DeviceIdentity? _identity;

  int get port => _server?.port ?? 0;

  Future<int> startReceiver({
    required DeviceIdentity identity,
    required TrustedDevicesReader trustedDevices,
    required ActivePinReader activePin,
    required TransferChanged onTransferChanged,
    required TrustedDeviceWriter onTrustedDevice,
    String? saveDirectory,
  }) async {
    await stopReceiver();
    _identity = identity;
    _trustedDevices = trustedDevices;
    _activePin = activePin;
    _onTransferChanged = onTransferChanged;
    _onTrustedDevice = onTrustedDevice;
    _saveDirectory = saveDirectory;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0, shared: true);
    _server!.listen(_handleIncomingSocket, onError: (_) {});
    return _server!.port;
  }

  void updateSaveDirectory(String? saveDirectory) {
    _saveDirectory = saveDirectory;
  }

  Future<void> stopReceiver() async {
    await _server?.close();
    _server = null;
  }

  Future<void> sendFile({
    required DeviceIdentity identity,
    required DiscoveredDevice device,
    required File file,
    required String relativePath,
    required List<TrustedDevice> trustedDevices,
    required String pin,
    required TransferChanged onTransferChanged,
    required TrustedDeviceWriter onTrustedDevice,
  }) async {
    final stat = await file.stat();
    var item = TransferItem(
      id: const Uuid().v4(),
      fileName: p.basename(file.path),
      filePath: file.path,
      relativePath: relativePath,
      totalBytes: stat.size,
      direction: TransferDirection.sending,
      status: TransferStatus.connecting,
      deviceName: device.name,
      createdAt: DateTime.now(),
    );
    onTransferChanged(item);

    final trusted = trustedDevices.where((entry) => entry.id == device.id && entry.fingerprint == device.fingerprint).firstOrNull;
    final secret = trusted?.trustToken ?? pin.trim();
    if (secret.isEmpty) {
      onTransferChanged(item.copyWith(status: TransferStatus.failed, error: 'PIN required for first transfer'));
      return;
    }

    try {
      final digest = await _hashFile(file);
      final proof = PairingProtocol.proof(
        secret: secret,
        senderId: identity.id,
        receiverId: device.id,
        receiverFingerprint: device.fingerprint,
      );
      final socket = await Socket.connect(device.address, device.port, timeout: const Duration(seconds: 8));
      final reader = _SocketReader(socket);
      socket.write(PairingEnvelope(
        senderId: identity.id,
        senderName: identity.name,
        senderPlatform: identity.platform,
        senderFingerprint: identity.fingerprint,
        proof: proof,
        usesTrustedToken: trusted != null,
      ).encodeLine());
      await socket.flush();
      final responseLine = await reader.readLine().timeout(const Duration(seconds: 8));
      final response = jsonDecode(responseLine ?? '{}') as Map<String, Object?>;
      if (response['ok'] != true) {
        throw FileTransferException(response['error'] as String? ?? 'Pairing rejected');
      }
      final trustToken = response['trustToken'] as String?;
      if (trustToken != null && trustToken.isNotEmpty) {
        await onTrustedDevice(TrustedDevice(
          id: device.id,
          name: device.name,
          platform: device.platform,
          fingerprint: device.fingerprint,
          trustToken: trustToken,
          lastSeen: DateTime.now(),
        ));
      }

      item = item.copyWith(status: TransferStatus.transferring);
      onTransferChanged(item);
      socket.write(TransferHeader(
        fileName: p.basename(file.path),
        relativePath: relativePath,
        totalBytes: stat.size,
        sha256Hex: digest,
        mimeType: 'application/octet-stream',
      ).encodeLine());

      final started = DateTime.now();
      var sent = 0;
      await for (final chunk in file.openRead()) {
        socket.add(chunk);
        sent += chunk.length;
        final elapsed = DateTime.now().difference(started).inMilliseconds.clamp(1, 1 << 31);
        item = item.copyWith(
          transferredBytes: sent,
          speedBytesPerSecond: sent * 1000 / elapsed,
        );
        onTransferChanged(item);
      }
      await socket.flush();
      await socket.close();
      await reader.cancel();
      onTransferChanged(item.copyWith(
        transferredBytes: stat.size,
        status: TransferStatus.complete,
        completedAt: DateTime.now(),
      ));
    } catch (error) {
      onTransferChanged(item.copyWith(status: TransferStatus.failed, error: error.toString()));
    }
  }

  Future<void> _handleIncomingSocket(Socket socket) async {
    final identity = _identity;
    if (identity == null) {
      socket.destroy();
      return;
    }
    final reader = _SocketReader(socket);
    TransferItem? item;
    IOSink? sink;
    try {
      final envelopeLine = await reader.readLine().timeout(const Duration(seconds: 8));
      final envelope = PairingEnvelope.fromJson(jsonDecode(envelopeLine ?? '{}') as Map<String, Object?>);
      final trustResult = _verifyPairing(identity, envelope);
      if (!trustResult.allowed) {
        socket.write('${jsonEncode({'ok': false, 'error': trustResult.reason})}\n');
        await socket.flush();
        await socket.close();
        await reader.cancel();
        return;
      }
      socket.write('${jsonEncode({'ok': true, 'trustToken': trustResult.trustToken})}\n');
      await socket.flush();
      if (trustResult.deviceToTrust != null) {
        await _onTrustedDevice?.call(trustResult.deviceToTrust!);
      }

      final headerLine = await reader.readLine().timeout(const Duration(seconds: 8));
      final header = TransferHeader.fromJson(jsonDecode(headerLine ?? '{}') as Map<String, Object?>);
      final directory = await _receiverDirectory();
      final relativePath = _safeRelativePath(header.relativePath.isEmpty ? header.fileName : header.relativePath);
      final output = File(p.join(directory, relativePath));
      await output.parent.create(recursive: true);
      sink = output.openWrite();
      item = TransferItem(
        id: const Uuid().v4(),
        fileName: header.fileName,
        filePath: output.path,
        relativePath: relativePath,
        totalBytes: header.totalBytes,
        direction: TransferDirection.receiving,
        status: TransferStatus.transferring,
        deviceName: envelope.senderName,
        createdAt: DateTime.now(),
      );
      _onTransferChanged?.call(item);

      final digestSink = AccumulatorSink<Digest>();
      final hashInput = sha256.startChunkedConversion(digestSink);
      final started = DateTime.now();
      var received = 0;
      while (received < header.totalBytes) {
        final wanted = (header.totalBytes - received).clamp(1, 64 * 1024).toInt();
        final chunk = await reader.readBytes(wanted);
        if (chunk == null || chunk.isEmpty) break;
        sink.add(chunk);
        hashInput.add(chunk);
        received += chunk.length;
        final elapsed = DateTime.now().difference(started).inMilliseconds.clamp(1, 1 << 31);
        item = item.copyWith(
          transferredBytes: received,
          speedBytesPerSecond: received * 1000 / elapsed,
        );
        _onTransferChanged?.call(item);
      }
      await sink.flush();
      await sink.close();
      hashInput.close();
      final receivedHash = digestSink.events.single.toString();
      if (received != header.totalBytes || receivedHash != header.sha256Hex) {
        throw FileTransferException('Checksum mismatch');
      }
      _onTransferChanged?.call(item.copyWith(
        transferredBytes: header.totalBytes,
        status: TransferStatus.complete,
        completedAt: DateTime.now(),
      ));
      await socket.close();
      await reader.cancel();
    } catch (error) {
      await sink?.close();
      if (item != null) {
        _onTransferChanged?.call(item.copyWith(status: TransferStatus.failed, error: error.toString()));
      }
      socket.destroy();
      await reader.cancel();
    }
  }

  _TrustResult _verifyPairing(DeviceIdentity identity, PairingEnvelope envelope) {
    final trusted = (_trustedDevices?.call() ?? const <TrustedDevice>[])
        .where((device) => device.id == envelope.senderId && device.fingerprint == envelope.senderFingerprint)
        .firstOrNull;
    if (trusted != null) {
      final expected = PairingProtocol.proof(
        secret: trusted.trustToken,
        senderId: envelope.senderId,
        receiverId: identity.id,
        receiverFingerprint: identity.fingerprint,
      );
      if (PairingProtocol.constantTimeEquals(expected, envelope.proof)) {
        return _TrustResult.allowed(trustToken: trusted.trustToken);
      }
      return const _TrustResult.rejected('Trusted device proof failed');
    }

    final pin = _activePin?.call().trim() ?? '';
    if (pin.isEmpty) return const _TrustResult.rejected('Pairing PIN is not active');
    final expected = PairingProtocol.proof(
      secret: pin,
      senderId: envelope.senderId,
      receiverId: identity.id,
      receiverFingerprint: identity.fingerprint,
    );
    if (!PairingProtocol.constantTimeEquals(expected, envelope.proof)) {
      return const _TrustResult.rejected('Invalid pairing PIN');
    }
    final token = PairingProtocol.trustToken(
      senderId: envelope.senderId,
      receiverId: identity.id,
      proof: envelope.proof,
    );
    return _TrustResult.allowed(
      trustToken: token,
      deviceToTrust: TrustedDevice(
        id: envelope.senderId,
        name: envelope.senderName,
        platform: envelope.senderPlatform,
        fingerprint: envelope.senderFingerprint,
        trustToken: token,
        lastSeen: DateTime.now(),
      ),
    );
  }

  Future<String> _receiverDirectory() async {
    if (_saveDirectory != null && _saveDirectory!.isNotEmpty) return _saveDirectory!;
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return p.join(downloads.path, 'File Transfer Assistant');
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'File Transfer Assistant');
  }

  Future<String> _hashFile(File file) async {
    final digestSink = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return digestSink.events.single.toString();
  }

  String _safeRelativePath(String raw) {
    final parts = raw.replaceAll('\\', '/').split('/').where((part) {
      return part.isNotEmpty && part != '.' && part != '..' && !part.contains(':');
    }).toList();
    return parts.isEmpty ? 'received-file' : p.joinAll(parts);
  }
}

class FileTransferException implements Exception {
  const FileTransferException(this.message);
  final String message;

  @override
  String toString() => message;
}

class _TrustResult {
  const _TrustResult._({
    required this.allowed,
    required this.reason,
    this.trustToken,
    this.deviceToTrust,
  });

  const _TrustResult.allowed({required String trustToken, TrustedDevice? deviceToTrust})
      : this._(allowed: true, reason: null, trustToken: trustToken, deviceToTrust: deviceToTrust);

  const _TrustResult.rejected(String reason)
      : this._(allowed: false, reason: reason);

  final bool allowed;
  final String? reason;
  final String? trustToken;
  final TrustedDevice? deviceToTrust;
}

class _SocketReader {
  _SocketReader(Socket socket) : _iterator = StreamIterator<List<int>>(socket);

  final StreamIterator<List<int>> _iterator;
  final List<int> _buffer = <int>[];

  Future<String?> readLine() async {
    while (true) {
      final newline = _buffer.indexOf(10);
      if (newline >= 0) {
        final line = _buffer.sublist(0, newline);
        _buffer.removeRange(0, newline + 1);
        return utf8.decode(line, allowMalformed: true).trimRight();
      }
      if (!await _iterator.moveNext()) return null;
      _buffer.addAll(_iterator.current);
    }
  }

  Future<List<int>?> readBytes(int maxBytes) async {
    if (_buffer.isEmpty) {
      if (!await _iterator.moveNext()) return null;
      _buffer.addAll(_iterator.current);
    }
    final count = _buffer.length < maxBytes ? _buffer.length : maxBytes;
    final bytes = _buffer.sublist(0, count);
    _buffer.removeRange(0, count);
    return bytes;
  }

  Future<void> cancel() => _iterator.cancel();
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

