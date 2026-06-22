[English](README.md) | 简体中文

# 文件传输助手

一款 Flutter 应用，用于在 Windows 和 Android 设备之间通过局域网直接传输文件。

## 功能

- 在本地网络中通过 UDP 发现设备。
- 使用 TCP 流式传输文件，并对每个文件进行 SHA-256 校验。
- 首次传输使用 PIN 配对，审批后可复用受信任设备。
- Android 支持文件选择和类似公共 Downloads 的接收流程，无需 `MANAGE_EXTERNAL_STORAGE`。
- 面向 Windows 的布局，支持文件/文件夹选择和桌面拖放。
- 提供发送、接收、历史记录和受信任设备工作区。

## 运行

```powershell
flutter pub get
flutter run -d windows
flutter run -d android
```

两台设备必须连接到同一个 Wi-Fi 网络，或连接到同一个手机热点。在 Windows 上，请允许首次出现的专用/本地网络防火墙提示，以便其他设备能够连接到接收端套接字。

## 配对

1. 在目标设备上打开接收页面。
2. 首次传输时，在发送端输入显示的 PIN。
3. 传输成功后，双方都会保存受信任设备令牌。
4. 在受信任设备标签页中移除设备后，下次将需要重新使用 PIN 配对。

## 范围

版本 1 仅支持局域网传输。它不使用云中继、公网穿透，也不请求 Android 全文件访问权限。