import 'dart:io';

enum TransferStatus {
  idle,
  connecting,
  connected,
  transferring,
  completed,
  error,
}

enum TransferMode {
  sender,
  receiver,
}

class FileTransferModel {
  String? serverIp;
  int? serverPort;
  String? serverUrl;
  TransferStatus status;
  TransferMode mode;
  List<FileItem> selectedFiles;
  List<FileItem> receivedFiles;
  String? errorMessage;
  double progress;

  FileTransferModel({
    this.serverIp,
    this.serverPort,
    this.serverUrl,
    this.status = TransferStatus.idle,
    this.mode = TransferMode.sender,
    this.selectedFiles = const [],
    this.receivedFiles = const [],
    this.errorMessage,
    this.progress = 0.0,
  });

  FileTransferModel copyWith({
    String? serverIp,
    int? serverPort,
    String? serverUrl,
    TransferStatus? status,
    TransferMode? mode,
    List<FileItem>? selectedFiles,
    List<FileItem>? receivedFiles,
    String? errorMessage,
    double? progress,
  }) {
    return FileTransferModel(
      serverIp: serverIp ?? this.serverIp,
      serverPort: serverPort ?? this.serverPort,
      serverUrl: serverUrl ?? this.serverUrl,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      receivedFiles: receivedFiles ?? this.receivedFiles,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

class FileItem {
  final String name;
  final String path;
  final int size;
  final DateTime lastModified;
  double progress;

  FileItem({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
    this.progress = 0.0,
  });

  static FileItem fromFile(File file) {
    final path = file.path;
    // 处理 Windows 和 Android 不同的路径分隔符
    final name = path.contains('\\') 
        ? path.split('\\').last 
        : path.split('/').last;
        
    return FileItem(
      name: name,
      path: path,
      size: file.lengthSync(),
      lastModified: file.lastModifiedSync(),
    );
  }

  String get sizeString {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
} 