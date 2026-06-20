# File Transfer Assistant

A Flutter app for direct LAN file transfer between Windows and Android devices.

## Features

- UDP device discovery on the local network.
- TCP file streaming with per-file SHA-256 verification.
- First-transfer PIN pairing with trusted-device reuse after approval.
- Android file picking and public Downloads-style receive flow without `MANAGE_EXTERNAL_STORAGE`.
- Windows-friendly layout with file/folder picking and desktop drag-and-drop.
- Send, Receive, History, and Trusted Devices work areas.

## Run

```powershell
flutter pub get
flutter run -d windows
flutter run -d android
```

Both devices must be on the same Wi-Fi network or the same phone hotspot. On Windows, allow the first firewall prompt for private/local networks so other devices can connect to the receiver socket.

## Pairing

1. Open Receive on the target device.
2. Enter the displayed PIN on the sender for the first transfer.
3. After a successful transfer, both sides store a trusted-device token.
4. Remove a trusted device from the Trusted tab to require PIN pairing again.

## Scope

Version 1 is LAN-only. It does not use a cloud relay, public Internet traversal, or Android all-files access.
