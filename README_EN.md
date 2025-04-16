[中文版](README.md)

# File Transfer Assistant

A cross-platform file transfer application developed with Flutter, supporting fast file transfer between Windows and Android devices.

## Features

- Supports file transfer between Windows and Android platforms
- Fast transfer via LAN connection
- Quick connection establishment using QR code scanning
- Supports multiple file selection and transfer
- Displays transfer progress and status
- Simple and intuitive user interface

## Usage

### Sender (Any Device)

1. Click the "Send File" button on the main screen
2. Select one or more files to send
3. Click the "Start Sharing" button to start the service
4. The screen will display a QR code and server address
5. Wait for the receiver to scan the QR code or manually enter the address to connect

### Receiver (Any Device)

1. Click the "Receive File" button on the main screen
2. Point the camera at the QR code displayed by the sender to scan
   - Or click the icon in the upper right corner to switch to manual input mode and enter the connection address
3. After a successful connection, the available file list will be displayed on the screen
4. Click the download icon next to the file to start downloading
5. After the download is complete, the file will be saved to the device's download directory

## Notes

- Make sure both devices are connected to the same Wi-Fi network
- Windows version needs to allow access through the firewall
- Android devices need to allow storage and camera permissions
- Do not close the app during transfer

## Development & Build

### Requirements

- Flutter SDK 3.7.2 or higher
- Dart SDK 3.0.0 or higher

### Build Commands

```bash
# Get dependencies
flutter pub get

# Run debug version
flutter run

# Build Android APK
flutter build apk

# Build Windows executable
flutter build windows
```

## Technical Implementation

- Uses Shelf library to implement HTTP server
- Uses Provider for state management
- Uses qr_flutter to generate QR codes
- Uses mobile_scanner to scan QR codes
- Uses http for network requests
- Uses path_provider and file_picker for file operations

## License

MIT License

## Project Structure

```
lib/
├── main.dart                // App entry, theme and global Provider setup
├── models/
│   └── file_transfer_model.dart   // Data models and enums for transfer
├── screens/
│   ├── home_screen.dart         // Main screen, send/receive entry
│   ├── sender_screen.dart       // File sending flow screen
│   ├── receiver_screen.dart     // File receiving flow screen
│   └── file_selection_screen.dart // File selection screen
├── services/
│   └── file_transfer_service.dart // Core logic and service for file transfer
```

- `main.dart`: App entry, theme, Provider, and main screen setup.
- `models/`: Contains data structures and status enums for file transfer.
- `screens/`: Main UI screens, including home, send, receive, and file selection.
- `services/`: Business logic and network service implementation for file transfer. 