import 'package:file_transfer_assistant/src/core/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('discovery message round trips', () {
    final message = DiscoveryMessage(
      deviceId: 'device-1',
      deviceName: 'Desk',
      platform: 'windows',
      port: 51000,
      fingerprint: 'ABCD-1234-EFGH-5678',
      timestamp: DateTime.utc(2026, 6, 20),
    );

    final decoded = DiscoveryMessage.tryDecode(message.encode());

    expect(decoded, isNotNull);
    expect(decoded!.deviceId, 'device-1');
    expect(decoded.deviceName, 'Desk');
    expect(decoded.port, 51000);
  });

  test('pairing proof accepts matching secret and rejects mismatches', () {
    final proof = PairingProtocol.proof(
      secret: '123456',
      senderId: 'android',
      receiverId: 'windows',
      receiverFingerprint: 'FFFF-EEEE-DDDD-CCCC',
    );
    final same = PairingProtocol.proof(
      secret: '123456',
      senderId: 'android',
      receiverId: 'windows',
      receiverFingerprint: 'FFFF-EEEE-DDDD-CCCC',
    );
    final different = PairingProtocol.proof(
      secret: '000000',
      senderId: 'android',
      receiverId: 'windows',
      receiverFingerprint: 'FFFF-EEEE-DDDD-CCCC',
    );

    expect(PairingProtocol.constantTimeEquals(proof, same), isTrue);
    expect(PairingProtocol.constantTimeEquals(proof, different), isFalse);
  });
}
