import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/file_transfer_service.dart';
import '../models/file_transfer_model.dart';
import 'file_selection_screen.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final _urlController = TextEditingController();
  bool _isScanning = true;
  bool _isManualInput = false;
  final MobileScannerController _scannerController = MobileScannerController();
  late FileTransferService _service;

  @override
  void initState() {
    super.initState();
    _service = Provider.of<FileTransferService>(context, listen: false);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // 处理扫描结果
  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && 
          barcode.rawValue!.startsWith('http')) {
        _scannerController.stop();
        setState(() {
          _isScanning = false;
          _urlController.text = barcode.rawValue!;
        });
        
        _connectToServer(barcode.rawValue!);
        break;
      }
    }
  }

  // 连接到服务器
  Future<void> _connectToServer(String url) async {
    await _service.startReceiveMode(url);
    
    if (_service.model.status == TransferStatus.connected) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FileSelectionScreen(),
          ),
        ).then((_) {
          // 重置扫描器
          setState(() {
            _isScanning = true;
            _scannerController.start();
          });
        });
      }
    }
  }

  // 手动输入连接
  void _toggleManualInput() {
    setState(() {
      _isManualInput = !_isManualInput;
      if (_isManualInput) {
        _scannerController.stop();
        _isScanning = false;
      } else {
        _urlController.clear();
        _scannerController.start();
        _isScanning = true;
      }
    });
  }

  // 手动连接
  void _manualConnect() {
    if (_urlController.text.isNotEmpty) {
      _connectToServer(_urlController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接收文件'),
        actions: [
          IconButton(
            icon: Icon(_isManualInput ? Icons.qr_code : Icons.edit),
            onPressed: _toggleManualInput,
            tooltip: _isManualInput ? '扫描二维码' : '手动输入',
          )
        ],
      ),
      body: Consumer<FileTransferService>(
        builder: (context, service, child) {
          return Column(
            children: [
              // 状态显示
              _buildStatusCard(service.model),
              
              // 扫描区域或手动输入
              Expanded(
                child: _isManualInput
                    ? _buildManualInputForm()
                    : _buildScannerArea(),
              ),
            ],
          );
        },
      ),
    );
  }
  
  // 二维码扫描区域
  Widget _buildScannerArea() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '将二维码对准扫描框',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '提示：确保两台设备在同一个局域网中',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
          ),
        ),
      ],
    );
  }
  
  // 手动输入表单
  Widget _buildManualInputForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: '输入连接地址',
              hintText: 'http://192.168.x.x:8080',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _manualConnect,
            icon: Icon(Icons.connect_without_contact, color: Theme.of(context).colorScheme.onSecondary),
            label: const Text('连接'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 24,
              ),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '提示：您可以从发送端复制连接地址，然后粘贴到这里',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                ),
          ),
        ],
      ),
    );
  }
  
  // 状态卡片
  Widget _buildStatusCard(FileTransferModel model) {
    final statusText = switch (model.status) {
      TransferStatus.idle => '准备扫描',
      TransferStatus.connecting => '正在连接到发送方...',
      TransferStatus.connected => '已连接',
      TransferStatus.transferring => '正在接收文件...',
      TransferStatus.completed => '接收完成',
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
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
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
      ),
    );
  }
}
