import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/app_models.dart';
import '../core/protocol.dart';

class DiscoveryService {
  final _devices = <String, DiscoveredDevice>{};
  final _controller = StreamController<List<DiscoveredDevice>>.broadcast();
  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;
  DeviceIdentity? _identity;
  int _tcpPort = 0;
  Set<String> _trustedIds = const <String>{};

  Stream<List<DiscoveredDevice>> get devices => _controller.stream;

  Future<void> start({
    required DeviceIdentity identity,
    required int tcpPort,
    required Set<String> trustedIds,
  }) async {
    await stop();
    _identity = identity;
    _tcpPort = tcpPort;
    _trustedIds = trustedIds;
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    _socket!.broadcastEnabled = true;
    _socket!.listen(_handleSocketEvent);
    _broadcast();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) => _broadcast());
    _pruneTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pruneStaleDevices());
  }

  void updateTrustedIds(Set<String> ids) {
    _trustedIds = ids;
    for (final entry in _devices.entries.toList()) {
      _devices[entry.key] = entry.value.copyWith(isTrusted: ids.contains(entry.key));
    }
    _emit();
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _pruneTimer?.cancel();
    _broadcastTimer = null;
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _devices.clear();
    _emit();
  }

  void dispose() {
    unawaited(stop());
    unawaited(_controller.close());
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    final message = DiscoveryMessage.tryDecode(utf8.decode(datagram.data, allowMalformed: true));
    if (message == null || message.deviceId == _identity?.id) return;
    _devices[message.deviceId] = message.toDevice(
      datagram.address.address,
      _trustedIds.contains(message.deviceId),
    );
    _emit();
  }

  void _broadcast() {
    final identity = _identity;
    final socket = _socket;
    if (identity == null || socket == null || _tcpPort == 0) return;
    final message = DiscoveryMessage(
      deviceId: identity.id,
      deviceName: identity.name,
      platform: identity.platform,
      port: _tcpPort,
      fingerprint: identity.fingerprint,
      timestamp: DateTime.now(),
    );
    final data = utf8.encode(message.encode());
    socket.send(data, InternetAddress('255.255.255.255'), discoveryPort);
  }

  void _pruneStaleDevices() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 12));
    _devices.removeWhere((_, device) => device.lastSeen.isBefore(cutoff));
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final values = _devices.values.toList()
      ..sort((a, b) {
        final trusted = (b.isTrusted ? 1 : 0) - (a.isTrusted ? 1 : 0);
        if (trusted != 0) return trusted;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    _controller.add(values);
  }
}
