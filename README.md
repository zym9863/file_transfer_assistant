[English Version](README_EN.md)

# 文件传输助手

一个使用Flutter开发的跨平台文件传输应用，支持Windows和Android设备之间的快速文件传输。

## 功能特点

- 支持Windows和Android平台之间的文件传输
- 通过局域网连接，传输速度快
- 使用二维码扫描快速建立连接
- 支持多文件选择和传输
- 显示传输进度和状态
- 简洁直观的用户界面

## 使用方法

### 发送方（任意设备）

1. 点击主屏幕的"发送文件"按钮
2. 选择要发送的一个或多个文件
3. 点击"开始分享"按钮启动服务
4. 屏幕上会显示二维码和服务器地址
5. 等待接收方扫描二维码或手动输入地址连接

### 接收方（任意设备）

1. 点击主屏幕的"接收文件"按钮
2. 将相机对准发送方显示的二维码进行扫描
   - 或点击右上角图标切换到手动输入模式，输入连接地址
3. 连接成功后，屏幕上会显示可用文件列表
4. 点击文件旁边的下载图标开始下载
5. 下载完成后，文件会保存到设备的下载目录

## 注意事项

- 确保两台设备连接在同一个Wi-Fi网络
- Windows版本需要允许通过防火墙访问
- Android设备需要允许存储和相机权限
- 传输过程中请勿关闭应用

## 开发与构建

### 环境要求

- Flutter SDK 3.7.2或更高版本
- Dart SDK 3.0.0或更高版本

### 构建命令

```bash
# 获取依赖
flutter pub get

# 运行调试版本
flutter run

# 构建Android APK
flutter build apk

# 构建Windows可执行文件
flutter build windows
```

## 技术实现

- 使用Shelf库实现HTTP服务器
- 使用Provider进行状态管理
- 使用qr_flutter生成二维码
- 使用mobile_scanner扫描二维码
- 使用http进行网络请求
- 使用path_provider和file_picker处理文件操作

## 许可证

MIT License

## 项目结构

```
lib/
├── main.dart                // 应用入口，主题与全局Provider配置
├── models/
│   └── file_transfer_model.dart   // 传输相关数据模型与枚举
├── screens/
│   ├── home_screen.dart         // 主界面，发送/接收入口
│   ├── sender_screen.dart       // 发送文件流程界面
│   ├── receiver_screen.dart     // 接收文件流程界面
│   └── file_selection_screen.dart // 文件选择界面
├── services/
│   └── file_transfer_service.dart // 文件传输核心逻辑与服务
```

- `main.dart`：应用入口，配置主题、Provider和主界面。
- `models/`：包含文件传输的数据结构和状态枚举。
- `screens/`：各个主要界面，包括主界面、发送、接收和文件选择。
- `services/`：文件传输的业务逻辑和网络服务实现。
