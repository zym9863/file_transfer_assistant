import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_models.dart';
import 'app_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _destinations = <_Destination>[
    _Destination('Send', Icons.near_me_outlined),
    _Destination('Receive', Icons.call_received_outlined),
    _Destination('History', Icons.history_outlined),
    _Destination('Trusted', Icons.verified_user_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final body = _SectionBody(index: state.selectedIndex);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          if (wide) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: state.selectedIndex,
                  onDestinationSelected: controller.selectSection,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: _AppMark(),
                  ),
                  destinations: [
                    for (final item in _destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                Expanded(child: body),
              ],
            );
          }
          return body;
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 860) return const SizedBox.shrink();
          return NavigationBar(
            selectedIndex: state.selectedIndex,
            onDestinationSelected: controller.selectSection,
            destinations: [
              for (final item in _destinations)
                NavigationDestination(icon: Icon(item.icon), label: item.label),
            ],
          );
        },
      ),
    );
  }
}

class _SectionBody extends ConsumerWidget {
  const _SectionBody({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final sections = <Widget>[
      const SendPanel(),
      const ReceivePanel(),
      const HistoryPanel(),
      const TrustedPanel(),
    ];
    return SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Padding(
          key: ValueKey(index),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(state: state),
              const SizedBox(height: 18),
              Expanded(child: sections[index]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final identity = state.identity;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File Transfer Assistant', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              identity == null
                  ? 'Starting local transfer services...'
                  : '${identity.name} / ${identity.platform} / ${identity.fingerprint}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        _StatusPill(
          icon: state.isBootstrapping ? Icons.sync : Icons.lan_outlined,
          label: state.statusMessage ?? 'LAN direct mode',
        ),
      ],
    );
  }
}

class SendPanel extends ConsumerWidget {
  const SendPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final selected = state.selectedDevice;
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        final children = [
          _DeviceList(state: state, controller: controller),
          _SendActions(state: state, selected: selected, controller: controller),
        ];
        if (twoColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 16),
              Expanded(child: children[1]),
            ],
          );
        }
        return ListView(children: [children[0], const SizedBox(height: 16), children[1]]);
      },
    );

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return content;
    return DropTarget(
      onDragEntered: (_) => controller.setDropActive(true),
      onDragExited: (_) => controller.setDropActive(false),
      onDragDone: (details) => controller.sendDroppedFiles(details.files),
      child: content,
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({required this.state, required this.controller});

  final AppState state;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      title: 'Nearby devices',
      icon: Icons.sensors_outlined,
      child: state.devices.isEmpty
          ? const _EmptyState(icon: Icons.wifi_tethering_off, text: 'No Windows or Android device found on this LAN yet.')
          : Column(
              children: [
                for (final device in state.devices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DeviceTile(
                      device: device,
                      selected: state.selectedDeviceId == device.id,
                      onTap: () => controller.selectDevice(device.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SendActions extends StatelessWidget {
  const _SendActions({required this.state, required this.selected, required this.controller});

  final AppState state;
  final DiscoveredDevice? selected;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final canSend = selected != null && state.identity != null;
    return _Surface(
      title: 'Transfer queue',
      icon: Icons.upload_file_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: state.isDropActive ? const Color(0xFFE9F5EF) : const Color(0xFFF5F7F1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: state.isDropActive ? const Color(0xFF2E6B57) : const Color(0xFFDDE4DA)),
            ),
            child: Column(
              children: [
                Icon(Icons.file_upload_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 10),
                Text(
                  selected == null ? 'Choose a nearby device first' : 'Ready to send to ${selected!.name}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  selected?.isTrusted == true ? 'Trusted device: PIN is not required.' : 'First transfer requires the receiver PIN.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            enabled: selected?.isTrusted != true,
            decoration: const InputDecoration(
              labelText: 'Receiver PIN',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            keyboardType: TextInputType.number,
            onChanged: controller.setConnectionPin,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: canSend ? controller.sendPickedFiles : null,
                icon: const Icon(Icons.file_present_outlined),
                label: const Text('Choose files'),
              ),
              OutlinedButton.icon(
                onPressed: canSend ? controller.sendPickedFolder : null,
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('Choose folder'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RecentTransfers(transfers: state.transfers.where((item) => item.direction == TransferDirection.sending).take(4).toList()),
        ],
      ),
    );
  }
}

class ReceivePanel extends ConsumerWidget {
  const ReceivePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final identity = state.identity;
    final qrPayload = identity == null
        ? ''
        : 'fta://pair?device=${Uri.encodeComponent(identity.id)}&name=${Uri.encodeComponent(identity.name)}&pin=${state.activePin}&port=${state.receiverPort}&fingerprint=${Uri.encodeComponent(identity.fingerprint)}';

    return ListView(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final qr = _Surface(
              title: 'Pairing code',
              icon: Icons.qr_code_2_outlined,
              child: Column(
                children: [
                  if (qrPayload.isNotEmpty)
                    QrImageView(data: qrPayload, version: QrVersions.auto, size: 210, backgroundColor: Colors.white),
                  const SizedBox(height: 12),
                  SelectableText(state.activePin, style: Theme.of(context).textTheme.headlineLarge?.copyWith(letterSpacing: 2)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.refreshPin,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('New PIN'),
                  ),
                ],
              ),
            );
            final info = _Surface(
              title: 'Receiver',
              icon: Icons.download_done_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(label: 'TCP port', value: state.receiverPort == 0 ? 'Starting' : '${state.receiverPort}'),
                  _InfoRow(label: 'Device name', value: identity?.name ?? 'Starting'),
                  _InfoRow(label: 'Fingerprint', value: identity?.fingerprint ?? 'Starting'),
                  _InfoRow(label: 'Save folder', value: state.saveDirectory ?? 'Downloads / File Transfer Assistant'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.pickSaveDirectory,
                    icon: const Icon(Icons.drive_folder_upload_outlined),
                    label: const Text('Change receive folder'),
                  ),
                ],
              ),
            );
            if (!wide) return Column(children: [qr, const SizedBox(height: 16), info]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: qr), const SizedBox(width: 16), Expanded(child: info)]);
          },
        ),
        const SizedBox(height: 16),
        _Surface(
          title: 'Incoming transfers',
          icon: Icons.call_received_outlined,
          child: _RecentTransfers(transfers: state.transfers.where((item) => item.direction == TransferDirection.receiving).toList()),
        ),
      ],
    );
  }
}

class HistoryPanel extends ConsumerWidget {
  const HistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return _Surface(
      title: 'Transfer history',
      icon: Icons.history_outlined,
      child: _RecentTransfers(transfers: state.transfers),
    );
  }
}

class TrustedPanel extends ConsumerWidget {
  const TrustedPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    return _Surface(
      title: 'Trusted devices',
      icon: Icons.verified_user_outlined,
      child: state.trustedDevices.isEmpty
          ? const _EmptyState(icon: Icons.shield_outlined, text: 'Trusted devices appear here after the first PIN-approved transfer.')
          : Column(
              children: [
                for (final device in state.trustedDevices)
                  ListTile(
                    leading: const Icon(Icons.devices_other_outlined),
                    title: Text(device.name),
                    subtitle: Text('${device.platform} / ${device.fingerprint}'),
                    trailing: IconButton(
                      tooltip: 'Remove trusted device',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => controller.removeTrustedDevice(device.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentTransfers extends ConsumerWidget {
  const _RecentTransfers({required this.transfers});

  final List<TransferItem> transfers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (transfers.isEmpty) {
      return const _EmptyState(icon: Icons.inventory_2_outlined, text: 'No transfers yet.');
    }
    final controller = ref.read(appControllerProvider.notifier);
    return Column(
      children: [
        for (final item in transfers)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TransferTile(item: item, onRetry: item.status == TransferStatus.failed ? () => controller.retryTransfer(item) : null),
          ),
      ],
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.item, required this.onRetry});

  final TransferItem item;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      TransferStatus.complete => const Color(0xFF2E6B57),
      TransferStatus.failed => Theme.of(context).colorScheme.error,
      TransferStatus.canceled => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.tertiary,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE4DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.direction == TransferDirection.sending ? Icons.north_east : Icons.south_west, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
              Text(_statusLabel(item.status), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              if (onRetry != null)
                IconButton(tooltip: 'Retry', icon: const Icon(Icons.replay_outlined), onPressed: onRetry),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: item.status == TransferStatus.failed ? null : item.progress, minHeight: 6),
          const SizedBox(height: 8),
          Text('${_formatBytes(item.transferredBytes)} / ${_formatBytes(item.totalBytes)}  ${_formatSpeed(item.speedBytesPerSecond)}  ${item.deviceName ?? ''}'),
          if (item.error != null) Text(item.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.selected, required this.onTap});

  final DiscoveredDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9F5EF) : const Color(0xFFF8FAF5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF2E6B57) : const Color(0xFFDDE4DA), width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(device.platform == 'android' ? Icons.android_outlined : Icons.desktop_windows_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('${device.address}:${device.port} / ${device.fingerprint}', maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            _StatusPill(icon: device.isTrusted ? Icons.verified_outlined : Icons.pin_outlined, label: device.isTrusted ? 'Trusted' : 'PIN'),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleLarge)]),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: const Color(0xFFE9F5EF), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label, overflow: TextOverflow.ellipsis)]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 10), Text(text, textAlign: TextAlign.center)]),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.compare_arrows_outlined, color: Colors.white),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

String _statusLabel(TransferStatus status) {
  return switch (status) {
    TransferStatus.queued => 'Queued',
    TransferStatus.pairing => 'Pairing',
    TransferStatus.connecting => 'Connecting',
    TransferStatus.transferring => 'Transferring',
    TransferStatus.complete => 'Complete',
    TransferStatus.failed => 'Failed',
    TransferStatus.canceled => 'Canceled',
  };
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}

String _formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '';
  return '${_formatBytes(bytesPerSecond.round())}/s';
}

