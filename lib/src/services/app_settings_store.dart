import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_models.dart';

class AppSettingsStore {
  AppSettingsStore({this.historyLimit = 100});

  static const _saveDirectoryKey = 'settings.saveDirectory.v1';
  static const _transferHistoryKey = 'transfer.history.v1';

  final int historyLimit;

  Future<String?> loadSaveDirectory() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_saveDirectoryKey);
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> saveSaveDirectory(String? directory) async {
    final preferences = await SharedPreferences.getInstance();
    if (directory == null || directory.isEmpty) {
      await preferences.remove(_saveDirectoryKey);
      return;
    }
    await preferences.setString(_saveDirectoryKey, directory);
  }

  Future<List<TransferItem>> loadTransferHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final records =
        preferences.getStringList(_transferHistoryKey) ?? const <String>[];
    final transfers =
        records
            .map((record) {
              try {
                final item = TransferItem.fromJson(
                  jsonDecode(record) as Map<String, Object?>,
                );
                return _normalizeLoadedTransfer(item);
              } catch (_) {
                return null;
              }
            })
            .whereType<TransferItem>()
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transfers.take(historyLimit).toList();
  }

  Future<void> saveTransferHistory(List<TransferItem> transfers) async {
    final preferences = await SharedPreferences.getInstance();
    final records = transfers
        .take(historyLimit)
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await preferences.setStringList(_transferHistoryKey, records);
  }

  TransferItem _normalizeLoadedTransfer(TransferItem item) {
    if (_isTerminal(item.status)) return item;
    return item.copyWith(
      status: TransferStatus.failed,
      error: item.error ?? 'Interrupted when app closed',
      speedBytesPerSecond: 0,
    );
  }

  bool _isTerminal(TransferStatus status) {
    return status == TransferStatus.complete ||
        status == TransferStatus.failed ||
        status == TransferStatus.canceled;
  }
}
