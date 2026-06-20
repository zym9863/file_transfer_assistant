import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_models.dart';
import '../core/protocol.dart';
import '../services/device_identity_store.dart';
import '../services/discovery_service.dart';
import '../services/file_transfer_service.dart';
import '../services/trusted_devices_store.dart';

final appControllerProvider = StateNotifierProvider<AppController, AppState>((ref) {
  final controller = AppController();
  ref.onDispose(controller.dispose);
  return controller;
});

class AppState {
  const AppState({
    this.identity,
    this.devices = const <DiscoveredDevice>[],
    this.trustedDevices = const <TrustedDevice>[],
    this.transfers = const <TransferItem>[],
    this.selectedIndex = 0,
    this.receiverPort = 0,
    this.activePin = '',
    this.connectionPin = '',
    this.saveDirectory,
    this.isBootstrapping = true,
    this.isDropActive = false,
    this.selectedDeviceId,
    this.statusMessage,
  });

  final DeviceIdentity? identity;
  final List<DiscoveredDevice> devices;
  final List<TrustedDevice> trustedDevices;
  final List<TransferItem> transfers;
  final int selectedIndex;
  final int receiverPort;
  final String activePin;
  final String connectionPin;
  final String? saveDirectory;
  final bool isBootstrapping;
  final bool isDropActive;
  final String? selectedDeviceId;
  final String? statusMessage;

  DiscoveredDevice? get selectedDevice {
    for (final device in devices) {
      if (device.id == selectedDeviceId) return device;
    }
    return devices.isEmpty ? null : devices.first;
  }

  AppState copyWith({
    Object? identity = _sentinel,
    List<DiscoveredDevice>? devices,
    List<TrustedDevice>? trustedDevices,
    List<TransferItem>? transfers,
    int? selectedIndex,
    int? receiverPort,
    String? activePin,
    String? connectionPin,
    Object? saveDirectory = _sentinel,
    bool? isBootstrapping,
    bool? isDropActive,
    Object? selectedDeviceId = _sentinel,
    Object? statusMessage = _sentinel,
  }) {
    return AppState(
      identity: identical(identity, _sentinel) ? this.identity : identity as DeviceIdentity?,
      devices: devices ?? this.devices,
      trustedDevices: trustedDevices ?? this.trustedDevices,
      transfers: transfers ?? this.transfers,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      receiverPort: receiverPort ?? this.receiverPort,
      activePin: activePin ?? this.activePin,
      connectionPin: connectionPin ?? this.connectionPin,
      saveDirectory: identical(saveDirectory, _sentinel) ? this.saveDirectory : saveDirectory as String?,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isDropActive: isDropActive ?? this.isDropActive,
      selectedDeviceId: identical(selectedDeviceId, _sentinel) ? this.selectedDeviceId : selectedDeviceId as String?,
      statusMessage: identical(statusMessage, _sentinel) ? this.statusMessage : statusMessage as String?,
    );
  }
}

const Object _sentinel = Object();

class AppController extends StateNotifier<AppState> {
  AppController({
    DeviceIdentityStore? identityStore,
    TrustedDevicesStore? trustedDevicesStore,
    DiscoveryService? discoveryService,
    FileTransferService? fileTransferService,
    bool autoStart = true,
  })  : _identityStore = identityStore ?? DeviceIdentityStore(),
        _trustedDevicesStore = trustedDevicesStore ?? TrustedDevicesStore(),
        _discoveryService = discoveryService ?? DiscoveryService(),
        _fileTransferService = fileTransferService ?? FileTransferService(),
        super(const AppState()) {
    if (autoStart) unawaited(_bootstrap());
  }

  AppController.test(AppState initialState)
      : _identityStore = DeviceIdentityStore(),
        _trustedDevicesStore = TrustedDevicesStore(),
        _discoveryService = DiscoveryService(),
        _fileTransferService = FileTransferService(),
        super(initialState);

  final DeviceIdentityStore _identityStore;
  final TrustedDevicesStore _trustedDevicesStore;
  final DiscoveryService _discoveryService;
  final FileTransferService _fileTransferService;
  StreamSubscription<List<DiscoveredDevice>>? _discoverySubscription;

  Future<void> _bootstrap() async {
    try {
      final identity = await _identityStore.load();
      final trustedDevices = await _trustedDevicesStore.load();
      final activePin = PairingProtocol.generatePin();
      state = state.copyWith(
        identity: identity,
        trustedDevices: trustedDevices,
        activePin: activePin,
        isBootstrapping: false,
        statusMessage: 'Ready on ${identity.platform}',
      );
      final receiverPort = await _fileTransferService.startReceiver(
        identity: identity,
        trustedDevices: () => state.trustedDevices,
        activePin: () => state.activePin,
        onTransferChanged: _upsertTransfer,
        onTrustedDevice: _trustDevice,
        saveDirectory: state.saveDirectory,
      );
      state = state.copyWith(receiverPort: receiverPort);
      _discoverySubscription = _discoveryService.devices.listen((devices) {
        final selectedStillExists = devices.any((device) => device.id == state.selectedDeviceId);
        state = state.copyWith(
          devices: devices,
          selectedDeviceId: selectedStillExists ? state.selectedDeviceId : (devices.isEmpty ? null : devices.first.id),
        );
      });
      await _discoveryService.start(
        identity: identity,
        tcpPort: receiverPort,
        trustedIds: trustedDevices.map((device) => device.id).toSet(),
      );
    } catch (error) {
      state = state.copyWith(isBootstrapping: false, statusMessage: error.toString());
    }
  }

  void selectSection(int index) {
    state = state.copyWith(selectedIndex: index);
  }

  void selectDevice(String id) {
    state = state.copyWith(selectedDeviceId: id);
  }

  void setConnectionPin(String pin) {
    state = state.copyWith(connectionPin: pin);
  }

  void refreshPin() {
    state = state.copyWith(activePin: PairingProtocol.generatePin());
  }

  void setDropActive(bool active) {
    state = state.copyWith(isDropActive: active);
  }

  Future<void> pickSaveDirectory() async {
    final directory = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose receive folder');
    if (directory == null) return;
    _fileTransferService.updateSaveDirectory(directory);
    state = state.copyWith(saveDirectory: directory, statusMessage: 'Receive folder updated');
  }

  Future<void> sendPickedFiles() async {
    final device = state.selectedDevice;
    final identity = state.identity;
    if (device == null || identity == null) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (result == null) return;
    for (final picked in result.files) {
      final path = picked.path;
      if (path == null) continue;
      await _sendFile(identity, device, File(path), p.basename(path));
    }
  }

  Future<void> sendPickedFolder() async {
    final device = state.selectedDevice;
    final identity = state.identity;
    if (device == null || identity == null) return;
    final root = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose folder to send');
    if (root == null) return;
    final rootDirectory = Directory(root);
    await for (final entity in rootDirectory.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: root);
      await _sendFile(identity, device, entity, relative);
    }
  }

  Future<void> sendDroppedFiles(List<XFile> files) async {
    setDropActive(false);
    final device = state.selectedDevice;
    final identity = state.identity;
    if (device == null || identity == null) return;
    for (final dropped in files) {
      final file = File(dropped.path);
      if (!await file.exists()) continue;
      await _sendFile(identity, device, file, p.basename(dropped.path));
    }
  }

  Future<void> retryTransfer(TransferItem item) async {
    final device = state.selectedDevice;
    final identity = state.identity;
    final path = item.filePath;
    if (device == null || identity == null || path == null || item.direction != TransferDirection.sending) return;
    await _sendFile(identity, device, File(path), item.relativePath ?? p.basename(path));
  }

  Future<void> removeTrustedDevice(String id) async {
    await _trustedDevicesStore.remove(id);
    final devices = await _trustedDevicesStore.load();
    state = state.copyWith(trustedDevices: devices, statusMessage: 'Trusted device removed');
    _discoveryService.updateTrustedIds(devices.map((device) => device.id).toSet());
  }

  Future<void> _sendFile(DeviceIdentity identity, DiscoveredDevice device, File file, String relativePath) async {
    await _fileTransferService.sendFile(
      identity: identity,
      device: device,
      file: file,
      relativePath: relativePath,
      trustedDevices: state.trustedDevices,
      pin: state.connectionPin,
      onTransferChanged: _upsertTransfer,
      onTrustedDevice: _trustDevice,
    );
  }

  Future<void> _trustDevice(TrustedDevice device) async {
    await _trustedDevicesStore.trust(device);
    final devices = await _trustedDevicesStore.load();
    state = state.copyWith(trustedDevices: devices, statusMessage: 'Trusted ${device.name}');
    _discoveryService.updateTrustedIds(devices.map((entry) => entry.id).toSet());
  }

  void _upsertTransfer(TransferItem item) {
    final transfers = [...state.transfers];
    final index = transfers.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      transfers[index] = item;
    } else {
      transfers.insert(0, item);
    }
    state = state.copyWith(transfers: transfers);
  }

  @override
  void dispose() {
    unawaited(_discoverySubscription?.cancel());
    _discoveryService.dispose();
    unawaited(_fileTransferService.stopReceiver());
    super.dispose();
  }
}
