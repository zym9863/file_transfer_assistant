import 'package:file_transfer_assistant/src/core/app_models.dart';
import 'package:file_transfer_assistant/src/features/app_controller.dart';
import 'package:file_transfer_assistant/src/features/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home exposes primary work areas', (WidgetTester tester) async {
    final controller = AppController.test(
      AppState(
        identity: const DeviceIdentity(
          id: 'local',
          name: 'Local PC',
          platform: 'windows',
          secret: 'secret',
          fingerprint: 'AAAA-BBBB-CCCC-DDDD',
        ),
        activePin: '123456',
        receiverPort: 50000,
        isBootstrapping: false,
        devices: [
          DiscoveredDevice(
            id: 'phone',
            name: 'Phone',
            platform: 'android',
            address: '192.168.1.20',
            port: 50001,
            fingerprint: '1111-2222-3333-4444',
            lastSeen: DateTime.now(),
          ),
        ],
        selectedDeviceId: 'phone',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('File Transfer Assistant'), findsOneWidget);
    expect(find.text('Send'), findsWidgets);
    expect(find.text('Receive'), findsWidgets);
    expect(find.text('History'), findsWidgets);
    expect(find.text('Trusted'), findsWidgets);
    expect(find.text('Phone'), findsOneWidget);
  });

  testWidgets('failed transfers expose retry state', (
    WidgetTester tester,
  ) async {
    final controller = AppController.test(
      AppState(
        identity: const DeviceIdentity(
          id: 'local',
          name: 'Local PC',
          platform: 'windows',
          secret: 'secret',
          fingerprint: 'AAAA-BBBB-CCCC-DDDD',
        ),
        isBootstrapping: false,
        transfers: [
          TransferItem(
            id: 'transfer-1',
            fileName: 'report.zip',
            totalBytes: 100,
            transferredBytes: 20,
            direction: TransferDirection.sending,
            status: TransferStatus.failed,
            createdAt: DateTime.now(),
            error: 'Pairing rejected',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();

    expect(find.text('report.zip'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
  });
}
