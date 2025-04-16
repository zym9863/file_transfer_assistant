import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/file_transfer_service.dart';
import '../models/file_transfer_model.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen> {
  bool _serverStarted = false;
  late FileTransferService _service;

  @override
  void initState() {
    super.initState();
    _service = Provider.of<FileTransferService>(context, listen: false);
  }

  @override
  void dispose() {
    _service.close();
    super.dispose();
  }

  // 选择文件
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .map((file) => File(file.path!))
          .where((file) => file.existsSync())
          .toList();

      if (files.isNotEmpty) {
        _service.addFiles(files);
      }
    }
  }

  // 启动服务器
  Future<void> _startServer() async {
    final serverUrl = await _service.startSendMode();
    if (serverUrl != null) {
      setState(() {
        _serverStarted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发送文件'),
      ),
      body: Consumer<FileTransferService>(
        builder: (context, service, child) {
          final model = service.model;
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 状态显示
                _buildStatusCard(model),
                const SizedBox(height: 16),
                
                // 选择文件按钮
                ElevatedButton.icon(
                  onPressed: _pickFiles,
                  icon: Icon(Icons.attach_file, color: Theme.of(context).colorScheme.onPrimary),
                  label: const Text('选择要发送的文件'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 已选择文件列表
                Expanded(
                  child: _buildFilesList(model),
                ),
                
                // 启动服务器按钮
                if (model.selectedFiles.isNotEmpty && !_serverStarted)
                  ElevatedButton.icon(
                    onPressed: _startServer,
                    icon: Icon(Icons.send, color: Theme.of(context).colorScheme.onSecondary),
                    label: const Text('开始分享'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Theme.of(context).colorScheme.onSecondary,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                
                // 二维码显示
                if (_serverStarted && model.serverUrl != null)
                  _buildQrCodeCard(model.serverUrl!),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // 状态卡片
  Widget _buildStatusCard(FileTransferModel model) {
    final statusText = switch (model.status) {
      TransferStatus.idle => '准备就绪',
      TransferStatus.connecting => '正在启动服务...',
      TransferStatus.connected => '服务已启动，等待接收方连接',
      TransferStatus.transferring => '正在传输文件...',
      TransferStatus.completed => '传输完成',
      TransferStatus.error => '发生错误: ${model.errorMessage}',
    };
    
    final statusColor = switch (model.status) {
      TransferStatus.idle => Colors.grey,
      TransferStatus.connecting => Colors.orange,
      TransferStatus.connected => Colors.green,
      TransferStatus.transferring => Colors.blue,
      TransferStatus.completed => Colors.green,
      TransferStatus.error => Colors.red,
    };
    
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: statusColor,
                  size: 28,
                  shadows: [
                    Shadow(
                      blurRadius: 8,
                      color: statusColor.withOpacity(0.25),
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                const SizedBox(width: 10),
                Text(
                  '状态：$statusText',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                ),
              ],
            ),
            if (model.serverIp != null) ...[
              const SizedBox(height: 12),
              Text('服务器IP：${model.serverIp}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text('端口：${model.serverPort}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]
          ],
        ),
      ),
    );
  }
  
  // 文件列表
  Widget _buildFilesList(FileTransferModel model) {
    if (model.selectedFiles.isEmpty) {
      return const Center(
        child: Text('未选择任何文件'),
      );
    }
    
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListView.builder(
        itemCount: model.selectedFiles.length,
        itemBuilder: (context, index) {
          final file = model.selectedFiles[index];
          return ListTile(
            leading: Icon(Icons.insert_drive_file, color: Theme.of(context).colorScheme.primary),
            title: Text(
              file.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            subtitle: Text(
              file.sizeString,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              onPressed: _serverStarted
                  ? null
                  : () => _service.removeFile(index),
            ),
          );
        },
      ),
    );
  }
  
  // 二维码卡片
  Widget _buildQrCodeCard(String url) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              '请用接收设备扫描二维码',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: url,
              version: QrVersions.auto,
              size: 200,
            ),
            const SizedBox(height: 8),
            SelectableText(
              url,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '提示：确保两台设备在同一个局域网中',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
