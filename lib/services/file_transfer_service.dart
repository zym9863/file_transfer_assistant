import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/file_transfer_model.dart';

class FileTransferService extends ChangeNotifier {
  FileTransferModel _model = FileTransferModel();
  HttpServer? _server;
  final int _port = 8080;
  
  FileTransferModel get model => _model;
  
  // 获取本机IP地址
  Future<String?> getIpAddress() async {
    try {
      final info = NetworkInfo();
      return await info.getWifiIP();
    } catch (e) {
      _model = _model.copyWith(
        errorMessage: '获取IP地址失败: $e',
        status: TransferStatus.error,
      );
      notifyListeners();
      return null;
    }
  }
  
  // 启动发送模式
  Future<String?> startSendMode() async {
    try {
      _model = _model.copyWith(
        mode: TransferMode.sender,
        status: TransferStatus.connecting,
      );
      notifyListeners();
      
      final String? ip = await getIpAddress();
      if (ip == null) return null;
      
      // 创建路由
      final app = Router();
      
      // 列出可用文件
      app.get('/files', (shelf.Request request) {
        final filesList = _model.selectedFiles.map((file) => {
          'name': file.name,
          'size': file.size,
          'lastModified': file.lastModified.toIso8601String(),
        }).toList();
        
        return shelf.Response.ok(
          jsonEncode(filesList),
          headers: {'Content-Type': 'application/json'},
        );
      });
      
      // 下载文件
      app.get('/files/<fileName>', (shelf.Request request, String fileName) async {
        try {
          // 解码URL编码的文件名，确保中文和特殊字符正确处理
          String decodedFileName;
          try {
            decodedFileName = Uri.decodeComponent(fileName);
          } catch (e) {
            print('解码文件名失败: $e，使用原始文件名');
            decodedFileName = fileName;
          }
          final normalizedRequestName = _normalizeFileName(decodedFileName);
          print('服务器收到文件请求: $fileName');
          print('解码后: $decodedFileName (标准化: $normalizedRequestName)');
          
          // 使用标准化名称进行匹配
          final matches = _model.selectedFiles.where((file) {
            final normalizedFileName = _normalizeFileName(file.name);
            return normalizedFileName == normalizedRequestName;
          });
          
          final fileItem = matches.isNotEmpty ? matches.first : null;
          if (fileItem == null) {
            print('未找到文件: $normalizedRequestName');
            print('可用文件: ${_model.selectedFiles.map((f) => _normalizeFileName(f.name)).join(', ')}');
            return shelf.Response.notFound('文件不存在');
          }

          final file = File(fileItem.path);
          if (!await file.exists()) {
            return shelf.Response.notFound('文件不存在');
          }

          // 改进文件传输方式
          print('读取文件: ${fileItem.path}');
          final fileBytes = await file.readAsBytes();
          final fileSize = fileBytes.length;

          print('发送文件: ${fileItem.name}, 大小: $fileSize 字节');
          
          // 使用List<int>直接响应比使用Stream更可靠
          return shelf.Response(
            200,
            body: fileBytes,
            headers: {
              'Content-Type': 'application/octet-stream',
              'Content-Disposition': 'attachment; filename*=UTF-8\'\'${Uri.encodeComponent(normalizedRequestName)}',
              'Content-Length': '$fileSize',
              'Cache-Control': 'no-cache',
              'Access-Control-Allow-Origin': '*',
            },
          );
        } catch (e) {
          print('文件传输错误: $e');
          return shelf.Response.internalServerError(
              body: '无法获取或读取文件: $e');
        }
      });
      
      // 启动服务器
      final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(app);
        
      _server = await shelf_io.serve(handler, '0.0.0.0', _port);
      
      _model = _model.copyWith(
        serverIp: ip,
        serverPort: _port,
        serverUrl: 'http://$ip:$_port',
        status: TransferStatus.connected,
      );
      notifyListeners();
      
      return 'http://$ip:$_port';
    } catch (e) {
      _model = _model.copyWith(
        errorMessage: '启动服务器失败: $e',
        status: TransferStatus.error,
      );
      notifyListeners();
      return null;
    }
  }
  
  // 添加要发送的文件
  void addFiles(List<File> files) {
    final fileItems = files.map((file) => FileItem.fromFile(file)).toList();
    _model = _model.copyWith(
      selectedFiles: [..._model.selectedFiles, ...fileItems],
    );
    notifyListeners();
  }
  
  // 移除选中的文件
  void removeFile(int index) {
    final newList = List<FileItem>.from(_model.selectedFiles);
    newList.removeAt(index);
    _model = _model.copyWith(selectedFiles: newList);
    notifyListeners();
  }
  
  // 开始接收模式
  Future<void> startReceiveMode(String serverUrl) async {
    try {
      _model = _model.copyWith(
        mode: TransferMode.receiver,
        status: TransferStatus.connecting,
        serverUrl: serverUrl,
      );
      notifyListeners();
      
      // 验证连接
      final response = await http.get(Uri.parse('$serverUrl/files'));
      if (response.statusCode != 200) {
        throw Exception('无法连接到发送方: ${response.statusCode}');
      }
      
      _model = _model.copyWith(
        status: TransferStatus.connected,
      );
      notifyListeners();
    } catch (e) {
      _model = _model.copyWith(
        errorMessage: '连接到发送方失败: $e',
        status: TransferStatus.error,
      );
      notifyListeners();
    }
  }
  
  // 获取可用文件列表
  Future<List<Map<String, dynamic>>?> getAvailableFiles() async {
    try {
      final response = await http.get(Uri.parse('${_model.serverUrl}/files'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      _model = _model.copyWith(
        errorMessage: '获取文件列表失败: $e',
        status: TransferStatus.error,
      );
      notifyListeners();
      return null;
    }
  }
  
  // 下载文件
  Future<bool> downloadFile(String fileName, int fileSize) async {
    try {
      // 请求存储权限
      if (!await _requestPermissions()) {
        _model = _model.copyWith(
          errorMessage: '无法获取存储权限',
          status: TransferStatus.error,
        );
        notifyListeners();
        return false;
      }
      
      _model = _model.copyWith(
        status: TransferStatus.transferring,
        progress: 0.0,
      );
      notifyListeners();
      
      // 标准化处理文件名
      final normalizedFileName = _normalizeFileName(fileName);
      // 确保使用标准化的名称作为保存的文件名
      final pureFileName = normalizedFileName;
      
      final directory = await _getDownloadDirectory();
      // 显式使用 POSIX join 构建 Android 路径
      final filePath = p.posix.join(directory.path, pureFileName); 
      final file = File(filePath);
      
      // 下载文件 - 改进实现方式
      final client = http.Client();
      
      try {
        // 使用同步HTTP请求而非流式传输
        // 重要：对文件名进行URL编码，确保中文和特殊字符能被正确处理
        // 先确保文件名是解码状态，然后再进行编码，避免重复编码
        String fileNameToEncode = fileName;
        try {
          if (fileNameToEncode.contains('%')) {
            fileNameToEncode = Uri.decodeComponent(fileNameToEncode);
          }
        } catch (e) {
          print('解码文件名失败: $e，使用原始文件名');
        }
        
        final encodedFileName = Uri.encodeComponent(fileNameToEncode);
        final uri = Uri.parse('${_model.serverUrl}/files/$encodedFileName');
        
        print('尝试下载文件: $uri');
        print('文件将保存为: $filePath');
        print('原始文件名: $fileName, 编码后: $encodedFileName');
        
        final response = await http.get(uri);
        
        if (response.statusCode != 200) {
          throw Exception('服务器返回状态码: ${response.statusCode}');
        }
        
        print('收到响应，内容长度: ${response.bodyBytes.length} 字节');
        
        // 直接写入完整数据
        await file.writeAsBytes(response.bodyBytes);
        
        // 验证文件大小
        final savedFile = File(filePath);
        final actualSize = await savedFile.length();
        
        print('已保存文件，实际大小: $actualSize 字节');
        
        // 检查文件大小是否与预期一致
        if (actualSize == 0 || (actualSize < 100 && fileSize > 1000)) {
          try {
            await savedFile.delete();
          } catch (_) {}
          throw Exception('文件传输不完整：预期 $fileSize 字节，实际 $actualSize 字节');
        }

        // 更新最终进度
        _model = _model.copyWith(progress: 1.0);
        notifyListeners();
        
        // 添加到已接收文件列表
        final fileItem = FileItem(
          name: pureFileName,
          path: filePath,
          size: actualSize,
          lastModified: DateTime.now(),
          progress: 1.0,
        );
        
        _model = _model.copyWith(
          receivedFiles: [..._model.receivedFiles, fileItem],
          status: TransferStatus.completed,
          progress: 1.0,
        );
        notifyListeners();
        
        return true;
      } catch (e) {
        // 确保在发生错误时也删除部分文件
        try {
          if (await file.exists()) {
            await file.delete(); // 删除可能不完整的文件
          }
        } catch (_) {
          // 忽略删除过程中的错误
        }
        
        _model = _model.copyWith(
          errorMessage: '下载文件失败: $e',
          status: TransferStatus.error,
        );
        notifyListeners();
        throw e; // 重新抛出原始错误
      } finally {
        client.close(); // 确保关闭客户端
      }
    } catch (e) {
      _model = _model.copyWith(
        errorMessage: '下载文件失败: $e',
        status: TransferStatus.error,
      );
      notifyListeners();
      return false;
    }
  }
  
  // 关闭服务器和连接
  void close() {
    _server?.close();
    _model = FileTransferModel();
    notifyListeners();
  }
  
  // 标准化文件名，使比较更可靠，并正确处理中文和特殊字符
  String _normalizeFileName(String fileName) {
    // 移除路径信息，只保留文件名
    String name = fileName;
    if (name.contains('/')) {
      name = name.split('/').last;
    }
    if (name.contains('\\')) {
      name = name.split('\\').last;
    }
    // 确保正确解码URL编码的字符，包括中文和特殊字符
    try {
      // 有时文件名可能已经被解码，所以我们需要检查
      if (name.contains('%')) {
        name = Uri.decodeComponent(name);
      }
    } catch (e) {
      print('解码文件名失败: $e，使用原始文件名');
      // 如果解码失败，使用原始文件名
    }
    return name;
  }
  
  // 请求存储权限（兼容 Android 11+ MANAGE_EXTERNAL_STORAGE）
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // 适配 Android 11 及以上
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) return true;
        // 可选: 被拒绝后引导至设置手动开启
        await Permission.manageExternalStorage.request();
        if (await Permission.manageExternalStorage.isPermanentlyDenied) {
          await openAppSettings();
        }
        return await Permission.manageExternalStorage.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true; // Windows默认有权限
  }
  
  // 获取下载目录
  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }
}
