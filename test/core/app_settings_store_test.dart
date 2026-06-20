import 'package:file_transfer_assistant/src/core/app_models.dart';
import 'package:file_transfer_assistant/src/services/app_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists receive folder', () async {
    final store = AppSettingsStore();

    await store.saveSaveDirectory(r'D:\Transfers');

    expect(await store.loadSaveDirectory(), r'D:\Transfers');
  });

  test('persists transfer history newest first', () async {
    final store = AppSettingsStore(historyLimit: 10);
    final older = TransferItem(
      id: 'older',
      fileName: 'old.txt',
      totalBytes: 12,
      transferredBytes: 12,
      direction: TransferDirection.sending,
      status: TransferStatus.complete,
      createdAt: DateTime(2026, 1, 1),
      completedAt: DateTime(2026, 1, 1),
    );
    final newer = TransferItem(
      id: 'newer',
      fileName: 'new.txt',
      totalBytes: 20,
      transferredBytes: 20,
      direction: TransferDirection.receiving,
      status: TransferStatus.complete,
      createdAt: DateTime(2026, 1, 2),
      completedAt: DateTime(2026, 1, 2),
    );

    await store.saveTransferHistory([older, newer]);

    final history = await store.loadTransferHistory();
    expect(history.map((item) => item.id), ['newer', 'older']);
    expect(history.first.fileName, 'new.txt');
  });

  test('marks unfinished history entries as failed after restart', () async {
    final store = AppSettingsStore();
    final unfinished = TransferItem(
      id: 'active',
      fileName: 'movie.mp4',
      totalBytes: 100,
      transferredBytes: 40,
      direction: TransferDirection.receiving,
      status: TransferStatus.transferring,
      createdAt: DateTime(2026, 1, 1),
    );

    await store.saveTransferHistory([unfinished]);

    final history = await store.loadTransferHistory();
    expect(history.single.status, TransferStatus.failed);
    expect(history.single.error, 'Interrupted when app closed');
  });
}
