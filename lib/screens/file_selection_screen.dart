import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_transfer_service.dart';
import '../models/file_transfer_model.dart';

class FileSelectionScreen extends StatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  State<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {
  List<Map<String, dynamic>>? _availableFiles;
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadAvailableFiles();
  }
  
  @override
  void dispose() {
    final service = Provider.of<FileTransferService>(context, listen: false);
    if (service.model.status != TransferStatus.transferring) {
      service.close();
    }
    super.dispose();
  }
  
  // 加载可用文件列表
  Future<void> _loadAvailableFiles() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final service = Provider.of<FileTransferService>(context, listen: false);
      final files = await service.getAvailableFiles();
      
      setState(() {
        _availableFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // 下载文件
  Future<void> _downloadFile(String fileName, int fileSize) async {
    final service = Provider.of<FileTransferService>(context, listen: false);
    
    // 显示下载开始的提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('开始下载文件...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    await service.downloadFile(fileName, fileSize);
    
    if (service.model.status == TransferStatus.completed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件下载完成！'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (service.model.status == TransferStatus.error && mounted) {
      // 显示详细错误信息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载失败: ${service.model.errorMessage}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择要接收的文件'),
      ),
      body: Consumer<FileTransferService>(
        builder: (context, service, child) {
          final model = service.model;
          
          // 显示传输进度
          if (model.status == TransferStatus.transferring) {
            return _buildTransferProgressView(model);
          }
          
          // 显示已完成下载
          if (model.status == TransferStatus.completed && 
              model.receivedFiles.isNotEmpty) {
            return _buildCompletedView(model);
          }
          
          // 显示错误信息
          if (model.status == TransferStatus.error || _errorMessage != null) {
            return _buildErrorView(model.errorMessage ?? _errorMessage!);
          }
          
          // 显示加载中
          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取可用文件...'),
                ],
              ),
            );
          }
          
          // 显示文件列表
          return _buildFileListView();
        },
      ),
    );
  }
  
  // 文件列表视图
  Widget _buildFileListView() {
    if (_availableFiles == null || _availableFiles!.isEmpty) {
      return const Center(
        child: Text('没有可用的文件'),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availableFiles!.length,
      itemBuilder: (context, index) {
        final file = _availableFiles![index];
        final fileName = file['name'] as String;
        final fileSize = file['size'] as int;
        final lastModified = DateTime.parse(file['lastModified'] as String);
        
        String fileSizeString = '';
        if (fileSize < 1024) {
          fileSizeString = '$fileSize B';
        } else if (fileSize < 1024 * 1024) {
          fileSizeString = '${(fileSize / 1024).toStringAsFixed(2)} KB';
        } else if (fileSize < 1024 * 1024 * 1024) {
          fileSizeString = '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
        } else {
          fileSizeString = '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: Text(fileName),
            subtitle: Text(
              '$fileSizeString • ${lastModified.toLocal().toString().split('.')[0]}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadFile(fileName, fileSize),
            ),
          ),
        );
      },
    );
  }
  
  // 传输进度视图
  Widget _buildTransferProgressView(FileTransferModel model) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.downloading,
              size: 50,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            const Text(
              '正在接收文件...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: model.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 10),
            Text(
              '${(model.progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
  
  // 下载完成视图
  Widget _buildCompletedView(FileTransferModel model) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              SizedBox(width: 8),
              Text(
                '下载完成',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('已下载的文件:'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: model.receivedFiles.length,
              itemBuilder: (context, index) {
                final file = model.receivedFiles[index];
                return ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(file.name),
                  subtitle: Text(file.sizeString),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回'),
          ),
        ],
      ),
    );
  }
  
  // 错误视图
  Widget _buildErrorView(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              '发生错误',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loadAvailableFiles,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
} 